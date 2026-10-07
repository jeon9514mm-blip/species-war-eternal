#!/usr/bin/env python3
"""Run Godot regressions with isolated player saves (Linux and Windows)."""
from concurrent.futures import ThreadPoolExecutor, as_completed
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
from project_paths import resource_path, select_tests, source_scripts
from run_v80_runtime_checks import evaluate_output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot') or shutil.which('godot4'))
    parser.add_argument('--output', help='Optional JSON results path')
    parser.add_argument('--jobs', type=int, default=1, choices=range(1, 5), help='Concurrent tests with independent save directories (1-4)')
    parser.add_argument('--tests', nargs='+', help='Optional explicit script filenames for a targeted regression suite')
    parser.add_argument('--list', action='store_true', help='List discovered tests without requiring Godot')
    parser.add_argument('--skip-syntax', action='store_true', help='Explicitly skip the full parser pass after a separate syntax check')
    parser.add_argument('--gpu', action='store_true', help='Run selected regressions on the real Mobile GPU renderer instead of the headless dummy backend')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    try:
        scripts = select_tests(project, args.tests)
    except ValueError as error:
        parser.error(str(error))
    if args.list:
        print('\n'.join(script.relative_to(project).as_posix() for script in scripts))
        return 0
    if not args.godot:
        parser.error('Specify the Godot 4.7.2 executable with --godot PATH')
    if sys.platform not in ('linux', 'win32'):
        parser.error('This save-isolating runner currently supports Linux and Windows.')
    binary = str(Path(args.godot).resolve())
    results = []
    # GPU drivers may write shader cache briefly after Godot exits on Windows.
    with tempfile.TemporaryDirectory(prefix='pixel-rpg-tests-', ignore_cleanup_errors=True) as tmp:
        # The editor also writes preferences and font/import caches. Keep all
        # three XDG locations writable and isolated from the developer profile.
        locations = {name: str(Path(tmp) / folder) for name, folder in (
            ('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'),
            ('XDG_CACHE_HOME', 'cache'))}
        for location in locations.values():
            Path(location).mkdir()
        env = dict(os.environ, **locations, APPDATA=locations['XDG_DATA_HOME'])
        imported = subprocess.run([binary, '--headless', '--path', str(project), '--editor', '--import', '--quit'],
                                  env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
        if imported.returncode or 'SCRIPT ERROR' in imported.stdout or 'ERROR:' in imported.stdout:
            print(imported.stdout)
            return 1
        # Editor import does not compile every unreferenced/dynamically loaded script.
        # Ask the real GDScript parser to check all scripts, including UI tools.
        def check_script(script):
            relative = script.relative_to(project).as_posix()
            try:
                proc = subprocess.run(
                    [binary, '--headless', '--path', str(project), '--check-only',
                     '--script', 'res://' + relative], env=env,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60)
                output = proc.stdout
                passed = proc.returncode == 0 and 'SCRIPT ERROR' not in output and 'ERROR:' not in output
            except subprocess.TimeoutExpired as error:
                output = error.stdout or ''
                if isinstance(output, bytes):
                    output = output.decode('utf-8', errors='replace')
                output += '\nParser check timed out after 60 seconds.'
                passed = False
            return {'script': relative, 'passed': passed, 'output': output if not passed else ''}
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            syntax = list(pool.map(check_script, [] if args.skip_syntax else source_scripts(project)))
        syntax_report = {'requested': not args.skip_syntax, 'passed': sum(item['passed'] for item in syntax),
                         'total': len(syntax), 'results': syntax}
        print('Full parser pass skipped (explicit --skip-syntax)' if args.skip_syntax else
              '%d/%d scripts compile' % (syntax_report['passed'], syntax_report['total']), flush=True)
        if syntax_report['passed'] != syntax_report['total']:
            for item in syntax:
                if not item['passed']:
                    print(item['script'] + '\n' + item['output'], flush=True)
            if args.output:
                Path(args.output).write_text(json.dumps({'stage': 'syntax', 'syntax': syntax_report},
                                                       ensure_ascii=False, indent=2), encoding='utf-8')
            return 1
        def run_one(script):
            # RaidDesign's production-path canaries require an explicitly named
            # disposable home; retain its guard instead of disabling the test.
            test_dir = Path(tmp) / ('art-pilot-raid-validation' if script.stem == 'RaidDesignSmokeTest' else script.stem)
            test_dir.mkdir()
            test_env = dict(env, XDG_DATA_HOME=str(test_dir), APPDATA=str(test_dir))
            started = time.monotonic()
            # Two full 180-second simulated 10-hero runs include live UI and save updates.
            # The pattern audit runs twelve natural battles, including six full
            # 90-second weekly rotations; keep their complete simulation steps.
            timeout_seconds = 600 if script.stem in {"V26CombatSoakSmokeTest", "V27BalanceMatrixSmokeTest", "V27BossLifecycleSmokeTest", "V835PatternBattleSmokeTest"} else 180
            command = [binary] + (['--rendering-method', 'mobile', '--audio-driver', 'Dummy'] if args.gpu else ['--headless']) + ['--path', str(project), '--script', resource_path(project, script)]
            startup = None
            if args.gpu and sys.platform == 'win32':
                startup = subprocess.STARTUPINFO()
                startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startup.wShowWindow = 0
            measurement_path = test_dir / 'balance-results.json'
            if script.stem in {'V27BalanceMatrixSmokeTest', 'V29RosterKitSmokeTest', 'V31HeroArtSmokeTest', 'PortraitRegressionSmokeTest'}:
                command += ['--', '--report=' + str(measurement_path)]
            try:
                proc = subprocess.run(command,
                                      env=test_env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout_seconds, startupinfo=startup)
                output = proc.stdout
                ok, _reason = evaluate_output(proc.returncode, output)
            except subprocess.TimeoutExpired as error:
                partial = error.stdout or ""
                if isinstance(partial, bytes):
                    partial = partial.decode("utf-8", errors="replace")
                output = partial + "\n" + 'Test timed out after %d seconds.' % timeout_seconds
                ok = False
            result = {'test': script.name, 'passed': ok, 'seconds': round(time.monotonic() - started, 2), 'output': output}
            if measurement_path.exists():
                try:
                    result['measurement'] = json.loads(measurement_path.read_text(encoding='utf-8'))
                except (OSError, ValueError) as error:
                    result['passed'] = ok = False
                    result['output'] += '\nInvalid test report: ' + str(error)
            print(('PASS' if ok else 'FAIL') + ' ' + script.name, flush=True)
            if not ok:
                # Preserve full evidence in --output without flooding the
                # terminal when one runtime error repeats each simulation tick.
                excerpt = result['output']
                if len(excerpt) > 12000:
                    excerpt = excerpt[:6000] + '\n[repeated output omitted; see JSON report]\n' + excerpt[-6000:]
                print(excerpt, flush=True)
            return result
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            futures = [pool.submit(run_one, script) for script in scripts]
            for future in as_completed(futures):
                results.append(future.result())
        results.sort(key=lambda x: x['test'])
        engine_version = subprocess.check_output([binary, '--version'], text=True, env=env).strip()
    report = {'engine': engine_version,
              'renderer': 'gpu_mobile' if args.gpu else 'headless_dummy',
              'syntax': syntax_report,
              'passed': sum(x['passed'] for x in results), 'total': len(results), 'results': results}
    if args.output:
        Path(args.output).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print('%d/%d tests passed' % (report['passed'], report['total']))
    return 0 if report['passed'] == report['total'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
