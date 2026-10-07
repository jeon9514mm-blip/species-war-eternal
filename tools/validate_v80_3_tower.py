#!/usr/bin/env python3
"""Source contracts and source arithmetic, NOT GDScript execution or Godot tests."""
from pathlib import Path
import ast
import json
import re

ROOT = Path(__file__).resolve().parents[1]
checks = []

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

def body(source, name):
    match = re.search(r"^(?:static )?func " + re.escape(name) + r"\([^\n]*\).*?:\n(.*?)(?=^(?:static )?func |\Z)", source, re.M | re.S)
    assert match, name
    return match.group(1)

def check(condition, label):
    if not condition:
        raise AssertionError(label)
    checks.append(label)

def source_expression(expression, variables):
    tree = ast.parse(expression, mode="eval")
    allowed = (ast.Expression, ast.Dict, ast.Constant, ast.Name, ast.Load, ast.BinOp,
               ast.Add, ast.Sub, ast.Mult, ast.Div, ast.Mod, ast.Call, ast.IfExp)
    for node in ast.walk(tree):
        assert isinstance(node, allowed), type(node).__name__
        if isinstance(node, ast.Name):
            assert node.id in variables or node.id == "int", node.id
        if isinstance(node, ast.Call):
            assert isinstance(node.func, ast.Name) and node.func.id == "int" and len(node.args) == 1 and not node.keywords
    return eval(compile(tree, "<source-arithmetic>", "eval"), {"__builtins__": {}, "int": int}, variables)

rules = read("scripts/progression/TowerBattleRules.gd")
service = read("scripts/progression/TowerProgressionService.gd")
director = read("scripts/combat/ChallengeBattleDirector.gd")
main = read("scripts/app/Main.gd")
pages = read("scripts/portrait/PortraitPages.gd")
legacy = read("scripts/ui/ContentScreens.gd")
session = read("scripts/combat/ChallengeBattleSession.gd")
validation = read("scripts/persistence/SaveValidation.gd")
store = read("scripts/persistence/SaveStore.gd")
save_service = read('scripts/persistence/GameSaveCoordinator.gd')
save_snapshot = body(save_service, 'snapshot')
save_load = body(save_service, 'load_idle_state')
check('_SAVE_FLOW.save_idle_state(self)' in body(main, '_save_idle_state'), 'save facade reaches shared persistence service')
check('_SAVE_FLOW.load_idle_state(self)' in body(main, '_load_idle_state'), 'load facade reaches shared persistence service')
max_floor = int(re.search(r"MAX_CLEAR_FLOOR: int = (\d+)", rules)[1])
max_saved = int(re.search(r"MAX_STAGE := (\d+)", validation)[1])
check(max_floor + 1 == max_saved, "last rewarded floor has persistable next-floor sentinel")
check('floor_number >= 1 and floor_number <= MAX_CLEAR_FLOOR' in body(rules,"valid_floor"), "bounded floor validation")
check('floor_number % 5 == 0' in body(rules,"is_boss_floor"), "every fifth floor boss contract")
plan = body(rules, "plan")
check('3 if is_boss_floor(floor_number) else 2' in plan, "two ordinary waves or three boss-floor waves")
check('"mode": "tower"' in plan and '"objective": "waves"' in plan and 'LIMIT_SECONDS: float = 90.0' in rules, "tower real-wave 90-second objective")
formations_text = re.search(r"const FORMATIONS: Array = (\[.*?\n\])\n", rules, re.S)[1]
formations = ast.literal_eval(formations_text)
boss_names = ast.literal_eval(re.search(r"const BOSS_WAVE: Array\[String\] = (\[.*\])", rules)[1])
check(len(formations) == 3 and all(len(f["waves"]) == 2 for f in formations), "three deterministic floor formations")
check(all(len(wave) == 4 for f in formations for wave in f["waves"]) and len(boss_names) == 3, "bounded pack sizes four or three")
all_names = set(boss_names)
for formation in formations:
    for wave in formation["waves"]: all_names.update(wave)
species = read("scripts/hunting/FieldEcology.gd")
check(all('"' + name + '":' in species for name in all_names), "all encounter names already in species catalog")
check('if enemy_index < 0 or enemy_index >= names.size():' in body(rules,"enemy_stats"), "invalid enemy index fails closed")
check('if not valid_floor(floor_number):' in body(rules,"reward"), "invalid floor has no reward")
reward_expression = re.findall(r"return (\{.*?\})", body(rules,"reward"), re.S)[-1]
hp_expression = re.search(r"var hp: int = (.+)", body(rules,"enemy_stats"))[1]
atk_expression = re.search(r"var attack: int = (.+)", body(rules,"enemy_stats"))[1]
# Exhaustive source formula evaluation only, not execution of the game's code.
reward_samples = {}
for f in range(1, max_floor + 1):
    result = source_expression(reward_expression, {"floor_number": f})
    assert result == {"gold": 250 + 90*f, "gems": 2 + f//5}, f
    if f in [1,4,5,10,9999]: reward_samples[f] = result
check(True, "reward arithmetic matches v79 on all 9999 supported floors")
stat_samples = 0
for f in [1,2,3,4,5,10,100,9999]:
    for w in range(3 if f % 5 == 0 else 2):
        for i in range(3 if w == 2 else 4):
            variables = {"floor_number": f, "wave_index": w, "enemy_index": i, "boss": w == 2 and i == 0}
            hp = source_expression(hp_expression, variables)
            attack = source_expression(atk_expression, variables)
            assert isinstance(hp,int) and isinstance(attack,int) and hp > 0 and attack > 0
            stat_samples += 1
check(True, "source HP/attack formulas positive in sampled normal and boss packs")
entry = body(service,"entry_error")
check('_calculate_party_power' not in entry and '_calculate_party_power' not in body(main,"_challenge_tower"), "power no longer gates tower entry or victory")
for field in ['main.challenge_session', 'main._save_blocked_for_newer_version', 'main.selected_faction', 'main.deployed_heroes', 'main.tower_floor', 'main.tower_best_floor']:
    check(field in entry, "entry validates " + field)
context = body(service,"context_matches")
for field in ['main.tower_floor','main.tower_best_floor','main.selected_faction','main.current_zone_id','main._deployed_hero_ids()']:
    check(field in context, "entry snapshot checks " + field)
check('daily_dungeon' not in context and '_today_key' not in context, "tower context has no daily reset dependency")
start = body(director,"start_tower")
check('not expected.is_empty() and not TOWER_PROGRESS.context_matches(main, expected)' in start, "stale button snapshot rejected")
check(start.index('TOWER_PROGRESS.entry_error(main)') < start.index('main._sanitize_deployed_party_for_faction()'), "newer save rejected before party mutation")
check('session.begin(main.challenge_serial, plan, entry)' in start and 'main.challenge_session = session' in start and 'spawn_wave(main)' in start, "tower enters shared battle session/spawner")
for fragment in ['wallet_gold +=', 'wallet_gems +=', 'tower_floor +=', 'tower_best_floor =']:
    check(fragment not in start and fragment not in body(main,"_challenge_tower"), "no immediate entry side effect " + fragment)
spawn = body(director,"spawn_wave")
check('TOWER.enemy_count' in spawn and 'TOWER.enemy_stats' in spawn and 'DAILY.enemy_stats' in spawn, "shared spawner dispatches tower and preserves daily")
check('main._advance_roaming_hunt(step, support)' in body(director,"advance"), "existing real movement/attack engine remains in loop")
check('_session_context_matches(main, session)' in body(director,"advance"), "mode context checked during combat")
check('session.mode == "tower"' in body(director,"_session_context_matches") and '_context_matches(main, session.entry_context)' in body(director,"_session_context_matches"), "daily and tower scope remain distinct")
finish = body(director,"finish")
check(finish.index('TOWER_PROGRESS.finish(main, session)') < finish.index('DAILY.reward'), "tower settlement dispatched before daily quota/reward logic")
settle = body(service,"finish")
check('main.challenge_session != session' in settle and 'session.is_running()' in settle, "only the current terminal session can settle")
check('if session.state == SESSION.State.WON:' in settle, "only combat victory can advance floor")
check('not context_matches(main, session.entry_context)' in settle and 'int(main.challenge_serial) != session.serial' in settle, "settlement rechecks snapshot and serial")
check(settle.index('session.take_victory_receipt') < settle.index('main.tower_floor = floor_number + 1'), "receipt consumed before floor or money mutation")
check(settle.index('main.challenge_session = null') < settle.index('main._save_idle_state()') < settle.index('main._build_meta_hub_screen()'), "session detached before save and UI navigation")
for forbidden in ['daily_dungeon_runs +=','weekly_trial_runs +=','_grant_hero_xp(', '_grant_pet_xp(', '_roll_equipment_drop(']:
    check(forbidden not in settle, "no tower reward leakage " + forbidden)
check('"outcome": outcome' in settle and '"settled": awarded' in settle, "results distinguish paid victories from rejected outcomes")
check('if completed and not daily and not tower:main._build_meta_hub_screen()' not in pages and 'elif tower:main._challenge_tower(tower_context)' in pages, "portrait entry never immediately closes any challenge battle")
check('main._challenge_tower(tower_context)' in pages and 'TOWER_RULES.reward(int(main.tower_floor))' in pages, "portrait button bound to original floor and preview uses settlement formula")
check("TowerBattleObjective" in pages and "미달이어도 도전 가능" in pages, "portrait displays combat objective and advisory power")
check('main._challenge_tower(tower_context), true, UI.LAVENDER)' in legacy and 'LegacyTowerEnterButton' in legacy, "legacy entry also bound without refresh/cancellation")
check('"tower_floor": main.tower_floor' in save_snapshot and '"tower_best_floor": main.tower_best_floor' in save_snapshot, "tower record and currencies remain in original shared save")
check(int(re.search(r'const VERSION\s*:=\s*(\d+)', store).group(1)) >= 34, "v34+ keeps existing tower fields while migrating weekly scores")
check('if challenge_session != null:' in body(main,'_clear_screen') and 'challenge_session.cancel("left_screen")' in body(main,'_clear_screen'), "leaving a screen cancels the runtime session")
field_finish = body(read('scripts/hunting/HuntFieldService.gd'), 'finish_hunt_target')
check('_FIELD.finish_hunt_target(self)' in body(main, '_finish_hunt_target'), 'field completion facade reaches service')
check('if main.challenge_session != null:' in field_finish and
      field_finish.index('main.CHALLENGE_DRIVER.wave_cleared(main)') < field_finish.index('return') <
      field_finish.index('main.invasion.take_finished(') < field_finish.index('settle_corps(main,'),
      "challenge wave exits before field corps receipts and reward settlement")
actual_test = read('tests/regression/V80TowerBattleSmokeTest.gd')
for forbidden in ['complete_wave(', 'take_victory_receipt(', '["hp"] = 0', '.state = SESSION.State.WON']:
    check(forbidden not in actual_test, "actual battle test does not fake victory using " + forbidden)
check('main._advance_auto_hunt(1.0 / 30.0)' in actual_test, "integration test drives existing actual combat ticks")
print(json.dumps({"type": "source contracts and source-expression evaluation; NOT engine runtime", "checks":len(checks), "passed":checks,
    "reward_formula_floors_checked":max_floor,"stat_formula_samples":stat_samples,"reward_examples":reward_samples,
    "godot_tests_executed":0}, ensure_ascii=False, indent=2))
