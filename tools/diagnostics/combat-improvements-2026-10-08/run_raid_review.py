"""Native raid maps and meaningful regression checks in disposable user storage."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[3]
OUTPUT = REPO / 'checks/combat-improvements-2026-10-08/raids'
BINARY = REPO.parent / 'validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
TESTS = ['RaidDedicatedArenaSmokeTest.gd', 'RaidTouchLayoutSmokeTest.gd',
         'RaidBossPaintFramingSmokeTest.gd', 'RaidDesignSmokeTest.gd',
         'FinalEnvironmentSmokeTest.gd']


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--capture-only', action='store_true')
    parser.add_argument('--tests-only', action='store_true')
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sources = ['scripts/app/Main.gd', 'scripts/art/RaidArenaBattlefield.gd',
               'scripts/maps3d/RaidEncounterArena.gd', 'shaders/RaidArenaPBR.gdshader',
               'scripts/maps3d/Battlefield3DView.gd', 'scripts/maps3d/HeroCircleFormation.gd',
               'scripts/raid/RaidBattlefield.gd', 'scripts/portrait/PortraitRaid.gd']
    hashes = {name: hashlib.sha256((REPO / name).read_bytes()).hexdigest() for name in sources}
    records = []
    with tempfile.TemporaryDirectory(dir=REPO.parent / 'validation', prefix='art-pilot-raid-validation-',
                                     ignore_cleanup_errors=True) as temporary:
        env = dict(os.environ, APPDATA=temporary, XDG_DATA_HOME=temporary,
                   XDG_CONFIG_HOME=temporary, XDG_CACHE_HOME=temporary)
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
        scripts = []
        if not args.capture_only:
            scripts += [('res://tests/regression/' + name, name[:-3], False) for name in TESTS]
        if not args.tests_only:
            scripts.append(('res://tools/diagnostics/combat-improvements-2026-10-08/CaptureRaidArenas.gd',
                            'capture', True))
        for index, (script, label, native) in enumerate(scripts):
            profile = Path(temporary) / ('run-' + str(index))
            profile.mkdir()
            env.update(APPDATA=str(profile), XDG_DATA_HOME=str(profile),
                       XDG_CONFIG_HOME=str(profile), XDG_CACHE_HOME=str(profile))
            started = time.monotonic()
            command = [str(BINARY), '--path', str(REPO), '--audio-driver', 'Dummy', '--script', script]
            command += ['--rendering-method', 'mobile'] if native else ['--headless']
            result = subprocess.run(command, env=env, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, encoding='utf-8',
                                    timeout=240, startupinfo=startup)
            text = result.stdout
            (OUTPUT / (label + '.log')).write_text(text, encoding='utf-8')
            passed = result.returncode == 0 and not any(
                marker in text for marker in ('ERROR:', 'SCRIPT ERROR', 'SHADER ERROR', 'leaked at exit'))
            if native:
                passed = passed and 'RAID_ARENA_CAPTURE_OK captures=7' in text
            else:
                passed = passed and 'failures=[]' in text
            records.append({'script': script, 'native': native, 'passed': passed,
                            'seconds': round(time.monotonic() - started, 3), 'returncode': result.returncode})
            print(('PASS ' if passed else 'FAIL ') + label, flush=True)
            if not passed:
                print(text[-15000:], flush=True)
        path = OUTPUT / ('capture-validation.json' if args.capture_only else
                         'regression-validation.json' if args.tests_only else 'validation.json')
        path.write_text(json.dumps({'player_save_used': False, 'performance_measurement': False,
                                    'results': records}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    if any(record['native'] for record in records):
        assert hashes == {name: hashlib.sha256((REPO / name).read_bytes()).hexdigest() for name in sources}
        (OUTPUT / 'source-hashes.json').write_text(json.dumps({'sources': hashes,
            'native_images': {file.name: hashlib.sha256(file.read_bytes()).hexdigest()
                              for file in sorted(OUTPUT.glob('*.png'))}}, indent=2) + '\n', encoding='utf-8')
    return int(any(not record['passed'] for record in records))


if __name__ == '__main__':
    raise SystemExit(main())
