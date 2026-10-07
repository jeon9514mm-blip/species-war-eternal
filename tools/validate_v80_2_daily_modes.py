#!/usr/bin/env python3
"""Source contracts + safe evaluation of literal plans/reward arithmetic.
Not a Godot runtime test. Does NOT execute GDScript game behavior.
"""
from pathlib import Path
import ast
import json
import re

ROOT = Path(__file__).resolve().parents[1]

def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')

def body(source, name):
    m = re.search(r'^(?:static )?func ' + re.escape(name) + r'\([^\n]*\).*?:\n(.*?)(?=^(?:static )?func |\Z)', source, re.M | re.S)
    assert m, name
    return m.group(1)

checks = []
def check(condition, label):
    if not condition:
        raise AssertionError(label)
    checks.append(label)

# This restricted evaluator only reads the source's constant dictionaries and
# arithmetic. It is not a surrogate interpreter for the game engine.
def literal_expression(source, values):
    tree = ast.parse(source.strip(), mode='eval')
    allowed = (ast.Expression, ast.Dict, ast.Constant, ast.Name, ast.Load,
               ast.BinOp, ast.Add, ast.Mult, ast.Sub)
    for node in ast.walk(tree):
        assert isinstance(node, allowed), type(node).__name__
        if isinstance(node, ast.Name):
            assert node.id in values, node.id
    return eval(compile(tree, '<source-constant>', 'eval'), {'__builtins__': {}}, values)

rules = read('scripts/progression/DailyDungeonBattleRules.gd')
session = read('scripts/combat/ChallengeBattleSession.gd')
director = read('scripts/combat/ChallengeBattleDirector.gd')
progress = read('scripts/progression/DailyDungeonProgress.gd')
main = read('scripts/app/Main.gd')
pages = read('scripts/portrait/PortraitPages.gd')
hud = read('scripts/portrait/PortraitHud.gd')
legacy = read('scripts/ui/ContentScreens.gd')
validation = read('scripts/persistence/SaveValidation.gd')
store = read('scripts/persistence/SaveStore.gd')
save_service = read('scripts/persistence/GameSaveCoordinator.gd')
save_snapshot = body(save_service, 'snapshot')
save_load = body(save_service, 'load_idle_state')
check('_SAVE_FLOW.save_idle_state(self)' in body(main, '_save_idle_state'), 'save facade reaches shared persistence service')
check('_SAVE_FLOW.load_idle_state(self)' in body(main, '_load_idle_state'), 'load facade reaches shared persistence service')
plans = {}
for variant, objective, waves in [('gold_rush','waves',3), ('survival','survive',0), ('boss_hunt','waves',1)]:
    m = re.search(r'\t\t"' + variant + r'":\n\t\t\treturn (\{.*?\})', body(rules,'plan'), re.S)
    assert m, variant
    plan = literal_expression(m.group(1), {'variant':variant})
    plans[variant] = plan
    check(plan['variant']==variant and plan['objective']==objective and plan['required_waves']==waves and plan['limit_seconds']==60.0, variant + ' objective contract')
reward_body = body(rules,'reward')
check('run_index < 0 or run_index >= DAILY_LIMIT' in reward_body, 'out-of-quota rewards rejected')
expr = re.findall(r'return (\{.*?\})', reward_body, re.S)[-1]
rewards = [literal_expression(expr, {'completed':i+1}) for i in range(3)]
for i,reward in enumerate(rewards):
    check(reward=={'gold':950+i*250,'xp':350+i*100,'pet_xp':60}, 'run %d original arithmetic' % (i+1))
check(sum(x['gold'] for x in rewards)==3600 and sum(x['xp'] for x in rewards)==1350, 'daily reward totals unchanged')
completion=body(session,'complete_wave')
check('objective == "waves" and cleared_waves >= required_waves' in completion, 'survival cannot win by clearing one wave')
clock=body(session,'advance_clock')
check('alive_heroes > 0' in clock and '(active_wave_token >= 0 or cleared_waves > 0)' in clock, 'survival requires live party and actual encounter')
check('elapsed = minf(limit_seconds, elapsed + delta)' in clock, 'deadline clamp remains')
check('session.advance_clock(step, main._alive_hero_ids().size())' in body(director,'advance'), 'combat reports actual living count at deadline')
start=body(director,'start_daily')
check(start.index('if main._save_blocked_for_newer_version:') < start.index('main._reset_daily_dungeon_if_needed()'), 'protected save rejected before mutation')
ctx=body(director,'_context_matches')
for field in ['main._today_key()', 'main.daily_dungeon_day', 'main.daily_dungeon_runs', 'main.selected_faction', 'main.current_zone_id', 'main._deployed_hero_ids()']:
    check(field in ctx, 'context checks '+field)
check('_session_context_matches(main, session)' in body(director,'advance') and '_context_matches(main, session.entry_context)' in body(director,'_session_context_matches'), 'daily context still checked before shared combat step')
check('_context_matches(main, entry)' in body(director,'finish'), 'context checked again before payout')
sweep=body(director,'sweep_daily')
check(sweep.index('_context_matches(main, expected)') < sweep.index('_apply_reward(main, reward)'), 'stale request rejected before sweep payout')
check(sweep.index('sweep_error(main, variant)') < sweep.index('_apply_reward(main, reward)'), 'clear gate before payout')
check('record_direct_clear' not in sweep, 'sweeping cannot generate direct clears')
check('session.take_victory_receipt(session.serial)' in body(director,'finish'), 'direct win consumes receipt')
check('PROGRESS.record_direct_clear' in body(director,'finish'), 'only direct victory handler records clear')
check(body(director,'_apply_reward').count('main.daily_dungeon_runs += 1')==1, 'shared quota debit')
check('daily_dungeon_runs < 0 or main.daily_dungeon_runs >= DAILY.DAILY_LIMIT' in body(director,'_entry_error'), 'same cap for combat and sweeps')
check('typeof(raw.get(key)) == TYPE_BOOL' in body(progress,'sanitize'), 'save does not treat truthy strings as clears')
check('for faction in FACTIONS:' in progress and 'for variant in RULES.VARIANTS:' in progress and 'for tier in RULES.DAILY_LIMIT:' in progress, 'bounded clear allowlist')
check('clear_key(faction, variant, tier)' in body(progress,'can_sweep'), 'faction mode tier isolation')
check('"daily_dungeon_clears": main.daily_dungeon_clears' in save_snapshot, 'clear saved in same snapshot as wallet/quota')
check('main.daily_dungeon_clears = parsed.get("daily_dungeon_clears", {}).duplicate(true)' in save_load, 'clear restored from sanitized payload')
check('DAILY_PROGRESS.sanitize(data.get("daily_dungeon_clears", {}))' in validation, 'old schema defaults locked')
check(int(re.search(r'const VERSION\s*:=\s*(\d+)', store).group(1)) >= 34, 'v34+ preserves daily clears and prevents old build overwrite')
check('DailyDungeonModeTabs' in pages and 'DungeonSweepButton' in pages, 'portrait actions reachable')
check('main._sweep_daily_dungeon(daily_variant,sweep_context)' in pages, 'portrait action carries original quota snapshot')
check('LegacyDailyModePicker' in legacy and 'LegacyDailySweepButton' in legacy, 'legacy actions reachable')
check('DAILY_RULES.reward(runs)' in pages, 'portrait preview uses same reward schedule')
check('challenge.progress_ratio()' in hud and 'challenge.objective_description' in hud, 'HUD displays correct objective instead of fixed 3-wave text')
for name in ['start_daily','spawn_wave','wave_cleared','advance']:
    fn=body(director,name)
    check(not any(x in fn for x in ['wallet_gold +=','wallet_xp +=','_roll_equipment_drop(','_grant_hero_xp(']), name+' no mid-battle reward')
print(json.dumps({'check_type':'source-contracts and source-constant arithmetic, NOT runtime', 'checks':len(checks), 'passed':checks, 'plans':plans, 'rewards':rewards, 'godot_tests_executed':0},ensure_ascii=False,indent=2))
