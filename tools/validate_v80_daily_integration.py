#!/usr/bin/env python3
"""Source-structure regression guards. Does NOT compile or execute GDScript."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / 'scripts/app/Main.gd').read_text()
director = (ROOT / 'scripts/combat/ChallengeBattleDirector.gd').read_text()
session = (ROOT / 'scripts/combat/ChallengeBattleSession.gd').read_text()
pages = (ROOT / 'scripts/portrait/PortraitPages.gd').read_text()
legacy = (ROOT / 'scripts/ui/ContentScreens.gd').read_text()
field_service = (ROOT / 'scripts/hunting/HuntFieldService.gd').read_text()
checks = []

def body(source, name):
    match = re.search(r'^(?:static )?func ' + re.escape(name) + r'\([^\n]*\).*?:\n(.*?)(?=^(?:static )?func |\Z)', source, re.M | re.S)
    assert match, name
    return match.group(1)

def check(condition, name):
    assert condition, name
    checks.append(name)

entry = body(main, '_run_daily_dungeon')
check('CHALLENGE_DRIVER.start_daily(self, variant)' in entry and 'wallet_gold' not in entry, 'daily entry delegates instead of paying')
for source, method, guard, needle in [
        (main, '_ensure_roaming_wave', 'if challenge_session != null:', 'CHALLENGE_DRIVER.ensure_wave(self)'),
        (field_service, 'advance_auto_hunt_step', 'if main.challenge_session != null:', 'main.CHALLENGE_DRIVER.advance(main, step)'),
        (field_service, 'finish_hunt_target', 'if main.challenge_session != null:', 'main.CHALLENGE_DRIVER.wave_cleared(main)')]:
    block = body(source, method)
    check(block.index(guard) < block.index(needle) < block.index('\t\treturn'), method + ' intercept precedes normal field path')
for method in ['advance_auto_hunt_step', 'finish_hunt_target']:
    check('_FIELD.' + method + '(self' in body(main, '_' + method), method + ' facade reaches guarded field service')
check('challenge_session.defeat()' in body(main, '_begin_hunt_recovery'), 'dungeon defeat does not auto-revive')
check('challenge_session.cancel("left_screen")' in body(main, '_clear_screen'), 'scene exit cancels session')
check('if daily:main._run_daily_dungeon(daily_variant)' in pages and 'if completed and not daily and not tower:main._build_meta_hub_screen()' not in pages, 'portrait callback keeps all challenge battles open')
check('main._run_daily_dungeon(daily_variant), true)' in legacy, 'legacy callback keeps daily battle open')
check('can_enter=not main.deployed_heroes.is_empty()' in pages, 'daily power is recommendation not automatic win')
for name in ['start_daily', 'spawn_wave', 'wave_cleared', 'advance']:
    block = body(director, name)
    check(not any(key in block for key in ['wallet_gold +=', 'wallet_xp +=', '_roll_equipment_drop(', '_grant_hero_xp(']), name + ' cannot directly grant loot')
receipt = body(session, 'take_victory_receipt')
check('state != State.WON' in receipt and 'expected_serial != serial' in receipt, 'receipt requires win and matching serial')
check(receipt.index('state = State.SETTLED') < receipt.index('return {"serial"'), 'receipt consumed before returned')
completion = body(session, 'complete_wave')
check('alive_enemies != 0 or alive_heroes <= 0' in completion, 'wave clear requires zero enemies and live party')
check('_credited_tokens.has(token)' in completion, 'wave credit is idempotent')
check('str(main.daily_dungeon_day) == str(expected.get("day", ""))' in body(director,'_context_matches') and '_context_matches(main, entry)' in body(director,'finish'), 'reward bound to entry day')
check('int(main.daily_dungeon_runs) == int(expected.get("run_index", -1))' in body(director,'_context_matches') and '_context_matches(main, entry)' in body(director,'finish'), 'reward bound to entry allowance')
fields = set(re.findall(r'^(?:var|const)\s+(\w+)',main,re.M))
methods = set(re.findall(r'^func\s+(\w+)',main,re.M))
# Object.has_method is a native Godot method used by optional goal hooks.
native = {'set_meta','get_meta','has_meta','has_method','free','set_physics_process'}
for rel in ['scripts/combat/ChallengeBattleDirector.gd','tests/regression/V80DailyBattleSmokeTest.gd']:
    refs = set(re.findall(r'\bmain\.(\w+)', (ROOT / rel).read_text()))
    check(not refs-fields-methods-native, rel+' host members exist')
print('V80 SOURCE-STRUCTURE CHECKS OK | checks=%d | GDScript runtime NOT executed' % len(checks))
