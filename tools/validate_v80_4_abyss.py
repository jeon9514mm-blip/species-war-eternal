#!/usr/bin/env python3
"""Source wiring and reward-arithmetic checks only; NOT a Godot interpreter."""
from pathlib import Path
import ast
import json
import re
ROOT=Path(__file__).resolve().parents[1]
def read(name):return (ROOT/name).read_text(encoding='utf-8')
def body(source,name):
    match=re.search(r'^(?:static )?func '+re.escape(name)+r'\([^\n]*\).*?:\n(.*?)(?=^(?:static )?func |\Z)',source,re.M|re.S)
    assert match,name
    return match.group(1)
checks=[]
def check(ok,label):
    if not ok:raise AssertionError(label)
    checks.append(label)
main=read('scripts/Main.gd');driver=read('scripts/ChallengeBattleDirector.gd')
session=read('scripts/ChallengeBattleSession.gd');rules=read('scripts/WeeklyAbyssBattleRules.gd')
service=read('scripts/WeeklyAbyssProgressionService.gd');pages=read('scripts/portrait/PortraitPages.gd')
legacy=read('scripts/ContentScreens.gd');validation=read('scripts/SaveValidation.gd')
check('return CHALLENGE_DRIVER.start_weekly(self, expected)' in body(main,'_run_weekly_trial'),'entry delegates to actual combat')
check('_calculate_party_power' not in body(main,'_run_weekly_trial')+rules+service+body(driver,'start_weekly'),'power never authorizes success or synthesizes score')
check('const LIMIT_SECONDS: float = 90.0' in rules and '"objective": "score"' in rules,'90-second score plan')
check('const WEEKLY_LIMIT: int = 5' in rules,'five-completion allowance')
for field in ['main._week_key()', 'main.weekly_content_key','main.weekly_trial_runs','main.weekly_trial_best','main.selected_faction','main.current_zone_id','main._deployed_hero_ids()']:
    check(field in body(service,'context_matches'),'entry context verifies '+field)
start=body(driver,'start_weekly')
check(start.index('_save_blocked_for_newer_version') < start.index('_reset_weekly_if_needed()'),'protected save checked before reset')
check('not expected.is_empty() and not ABYSS_PROGRESS.context_matches(main, expected)' in start,'stale button guarded')
check(start.index('main._build_combat_screen()') < start.index('main.challenge_session = session'),'reuse combat screen then attach session')
check('spawn_wave(main)' in start,'spawn actual initial encounter')
for forbidden in ['wallet_gold +=','wallet_gems +=','weekly_trial_runs +=','_grant_hero_xp(']:
    check(forbidden not in start,'entry never rewards '+forbidden)
spawn=body(driver,'spawn_wave')
check('ABYSS.enemy_stats' in spawn and 'session.register_score_target' in spawn,'spawn HP registered with score session')
check('"challenge_attack_rate": float(stats.get("attack_rate", 1.0))' in spawn,'weekly rate preserved separately from rage interval')
check('/ maxf(0.1, float(enemy.get("challenge_attack_rate", 1.0)))' in main,'rate increase divides interval instead of slowing attacks')
# Checks the actual source reward expression with a strict arithmetic allowlist.
reward_body=body(rules,'reward')
expr=re.findall(r'return (\{.*?\})',reward_body,re.S)[-1]
tree=ast.parse(expr,mode='eval')
allowed=(ast.Expression,ast.Dict,ast.Constant,ast.Name,ast.Load,ast.BinOp,ast.Add,ast.Mult)
for node in ast.walk(tree):check(isinstance(node,allowed),'reward AST allowed '+type(node).__name__)
reward_rows=[]
for index in range(5):
    reward=eval(compile(tree,'<GDScript source reward arithmetic>','eval'),{'__builtins__':{}},{'completed':index+1})
    check(reward=={'gold':1600+400*index,'gems':18+3*index,'hero_xp':450+100*index},'original reward arithmetic '+str(index+1))
    reward_rows.append(reward)
damage=body(main,'_damage_enemy')
check(damage.index('roaming_hunt.is_returning') < damage.index('CHALLENGE_DRIVER.record_damage'),'returning invulnerable enemies cannot score')
check(damage.index('minf(float(enemy["hp"])') < damage.index('enemy["hp"] =') < damage.index('CHALLENGE_DRIVER.record_damage'),'hook after clamped real HP application')
credit=body(session,'record_hp_loss')
for token in ['not is_running()', 'mode != "weekly"', 'token != active_wave_token', 'elapsed >= limit_seconds', 'not _score_target_hp.has(enemy_id)', 'after_hp < 0', 'after_hp >= before_hp', 'MAX_DAMAGE_SCORE - damage_score']:
    check(token in credit,'score guard '+token)
check('mini(lowest, before_hp) - after_hp' in credit and 'mini(lowest, after_hp)' in credit,'per-target low-water prevents duplicate/heal farming')
clock=body(session,'advance_clock')
check('objective == "score" and alive_heroes > 0 and _registered_score_targets > 0 and damage_score > 0' in clock,'completion requires live party and actual damage')
check('"damage_score": damage_score' in body(session,'take_victory_receipt'),'receipt includes measured score')
check('objective == "waves" and cleared_waves >= required_waves' in body(session,'complete_wave'),'weekly boss kill never ends timed run early')
settle=body(service,'finish')
for token in ['main.challenge_session != session','session.is_running()', 'int(main.challenge_serial) != session.serial', 'not context_matches(main, session.entry_context)', 'session.damage_score <= 0','session.elapsed < RULES.LIMIT_SECONDS']:
    check(token in settle,'settlement guard '+token)
check(settle.index('session.take_victory_receipt') < settle.index('main.weekly_trial_runs += 1'),'receipt consumed before payout')
check(settle.index('main.challenge_session = null') < settle.index('main._save_idle_state()') < settle.index('main._build_meta_hub_screen()'),'detach then save then return')
for token in ['daily_dungeon_runs +=', 'tower_floor =', 'wallet_xp +=', '_roll_equipment_drop(', '_grant_pet_xp(']:
    check(token not in settle,'no unrelated reward mutation '+token)
check('maxi(int(main.weekly_trial_best), score)' in settle,'lower run cannot lower best')
check(int(re.search(r'const VERSION\s*:=\s*(\d+)', read('scripts/SaveStore.gd')).group(1)) >= 34,'save schema protects new score semantics')
for field in ['weekly_trial_score_version','weekly_trial_legacy_best','weekly_trial_legacy_week']:
    check(field in body(main,'_save_idle_state') and field in validation,'new save field sanitized and persisted '+field)
check('data["weekly_trial_best"] = 0' in validation and 'data["weekly_trial_score_version"] = 1' in validation,'legacy score migration explicit and idempotent')
check('main._run_weekly_trial(weekly_context)' in pages and 'main._run_weekly_trial(weekly_context)' in legacy,'both UIs carry original snapshot')
check('if completed and not daily and not tower:main._build_meta_hub_screen()' not in pages and 'if main._run_weekly_trial():' not in legacy,'UI does not cancel battle after entry')
check('전투력 조건을 충족하면 즉시 정산' not in pages and 'WeeklyMutatorInfo' in pages,'UI describes real weekly rules not instant win')
actual=read('scripts/V80AbyssBattleSmokeTest.gd')
for token in ['record_hp_loss(', 'complete_wave(', 'advance_clock(', '["hp"] = 0', '.state = SESSION.State.WON']:
    check(token not in actual,'actual AI test does not synthesize results '+token)
check('main._advance_auto_hunt(1.0 / 30.0)' in actual and 'observed_damage' in actual,'AI integration independently observes real HP reductions')
check('"weekly_content_key": weekly_content_key' in body(main,'_save_idle_state'),'existing weekly checkpoint retained')
print(json.dumps({'type':'source contracts and limited source-expression arithmetic; NOT engine execution','checks':len(checks),
    'passed':checks,'reward_rows':reward_rows,'godot_tests_executed':0},ensure_ascii=False,indent=2))
