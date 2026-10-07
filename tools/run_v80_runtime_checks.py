#!/usr/bin/env python3
"""Run REAL Godot tests in an isolated project copy; blocked != passed.
Requires a Godot 4.7.2 standard editor executable (not an export template).
Usage: python tools/run_v80_runtime_checks.py --godot /path/to/godot --output checks/runtime.json
No download, account access, deployment, APK signing, or changes to player saves.
"""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import uuid
from project_paths import test_resource

ROOT = Path(__file__).resolve().parents[1]
TESTS = {
    'V80ChallengeSessionSmokeTest.gd': 'v80_challenge_session_smoke_test_ok',
    'V80DailyBattleSmokeTest.gd': 'v80_daily_battle_smoke_test_ok',
    'V80DailyModesSmokeTest.gd': 'v80_daily_modes_unit',
    'V80DailySweepSmokeTest.gd': 'v80_daily_sweep_unit',
    'V80DailyModesBattleSmokeTest.gd': 'v80_daily_modes_battle',
    'V80TowerRulesSmokeTest.gd': 'v80_tower_rules',
    'V80TowerSettlementSmokeTest.gd': 'v80_tower_settlement',
    'V80TowerBattleSmokeTest.gd': 'v80_tower_actual_battle',
    'V80AbyssRulesSmokeTest.gd': 'v80_abyss_rules',
    'V80AbyssSettlementSmokeTest.gd': 'v80_abyss_settlement',
    'V80AbyssSaveSmokeTest.gd': 'v80_abyss_save',
    'V80AbyssBattleSmokeTest.gd': 'v80_abyss_actual_battle',
    'V80EngineRewardRegressionSmokeTest.gd': 'v80_engine_reward_regression',
}
ERROR_PATTERN = re.compile(r'(^|\n)\s*(?:SCRIPT ERROR:|SHADER ERROR:|ERROR:|Parse Error:|.*Failed to load script)', re.I)


def evaluate_output(returncode: int | None, text: str, marker: str = '') -> tuple[bool, str]:
    if returncode != 0:
        return False, 'nonzero_exit_or_not_completed'
    if ERROR_PATTERN.search(text):
        return False, 'engine_error_in_log'
    if marker and marker not in text:
        return False, 'completion_marker_missing'
    # Accept the existing list/count report styles, but inspect EVERY report.
    # A later empty failure list must not hide an earlier nonzero result.
    fields = re.findall(r'\bfailures\s*=\s*(\[[^\r\n]*\]|-?\d+)', text)
    if len(fields) != len(re.findall(r'\bfailures\s*=', text)):
        return False, 'malformed_failure_report'
    for field in fields:
        try:
            value = json.loads(field)
        except (ValueError, TypeError):
            return False, 'malformed_failure_report'
        if value != [] and value != 0:
            return False, 'test_reported_failures'
    if any(int(count) != 0 for count in re.findall(r'(?m)(?:^|,\s*)(\d+)\s+failures\b', text)):
        return False, 'test_reported_failures'
    return True, 'passed'


def isolate_project_name(text: str, name: str) -> str:
    """Unique default user:// directory even on Windows, which may ignore XDG."""
    text = re.sub(r'^config/name=.*$', 'config/name="' + name + '"', text, flags=re.M)
    # This project uses default user-dir behavior; force it in the temp copy.
    text = re.sub(r'^config/use_custom_user_dir=.*\n?', '', text, flags=re.M)
    text = re.sub(r'^config/custom_user_dir_name=.*\n?', '', text, flags=re.M)
    return text.replace('[application]', '[application]\nconfig/use_custom_user_dir=false', 1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT', ''))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--timeout', type=int, default=240)
    parser.add_argument('--expected-version', default='4.7.2')
    parser.add_argument('--test', action='append', choices=TESTS, help='Run selected registered scripts; may repeat')
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    logs = output.parent / (output.stem + '-godot-logs')
    selected = list(dict.fromkeys(args.test or TESTS))
    binary = args.godot or shutil.which('godot') or shutil.which('godot4')
    if binary:
        resolved = shutil.which(binary) or (str(Path(binary).expanduser().resolve()) if Path(binary).expanduser().is_file() else None)
        binary = resolved
    report = {'status': 'blocked', 'engine': binary, 'expected_version': args.expected_version,
              'test_scripts_requested': len(selected), 'test_scripts_executed': 0,
              'test_scripts_passed': 0, 'tests': [], 'android_tests_executed': 0,
              'rendering_or_device_performance_certified': False}

    def save() -> None:
        output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(report, ensure_ascii=False, indent=2))

    if not binary:
        report['reason'] = 'Godot executable unavailable. No engine test ran; static checks do not substitute.'
        save()
        return 2
    logs.mkdir(exist_ok=True)

    def invoke(arguments: list[str], cwd: Path, env: dict[str, str], marker: str = '') -> dict:
        started = time.monotonic()
        launched = False
        text = ''
        returncode = None
        try:
            with subprocess.Popen([str(binary), *arguments], cwd=cwd, env=env,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                  encoding='utf-8', errors='replace') as process:
                launched = True
                try:
                    text, _ = process.communicate(timeout=max(1, args.timeout))
                    returncode = process.returncode
                except subprocess.TimeoutExpired:
                    process.kill()
                    text, _ = process.communicate()
                    text += '\nRUNNER TIMEOUT: process killed before completion\n'
        except OSError as exc:
            text += str(exc)
        ok, reason = evaluate_output(returncode, text, marker)
        return {'ok': ok, 'reason': reason, 'launched': launched, 'returncode': returncode,
                'seconds': round(time.monotonic() - started, 3), 'output': text}

    with tempfile.TemporaryDirectory(prefix='species-v80-engine-') as temporary:
        temp = Path(temporary)
        env = os.environ.copy()
        for variable in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
            directory = temp / variable.lower()
            directory.mkdir()
            env[variable] = str(directory)
        env['GODOT_SILENCE_ROOT_WARNING'] = '1'
        version = invoke(['--version'], ROOT, env)
        report['version'] = version['output'].strip()
        (logs/'version.log').write_text(version['output'], encoding='utf-8')
        if not version['ok'] or not report['version'].startswith(args.expected_version + '.'):
            report['reason'] = 'Executable could not run or is not the explicitly requested engine version.'
            save()
            return 2
        project = temp / 'project'
        # Full private copy: Godot import creates .godot and UID files. Do not
        # modify the user's original sources, import cache, or live save path.
        shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns('.git', '.godot', '__pycache__', 'checks'))
        config_path = project/'project.godot'
        original_config = config_path.read_text(encoding='utf-8')
        namespace = 'SpeciesWarEngineTest-' + uuid.uuid4().hex
        config_path.write_text(isolate_project_name(original_config, namespace), encoding='utf-8')
        report['isolation'] = 'temporary full project copy, unique application name, default isolated user data, XDG overrides'
        imported = invoke(['--headless', '--path', str(project), '--import'], project, env)
        (logs/'import.log').write_text(imported.pop('output'), encoding='utf-8')
        report['import'] = imported
        if not imported['ok']:
            report.update(status='failed', reason='Resource import/script preparation failed; see import.log.')
            save()
            return 1
        for index, test in enumerate(selected):
            # No state shared across test scripts; restarting the engine with a
            # distinct project name selects a new user:// directory per case.
            config_path.write_text(isolate_project_name(original_config, namespace + '-' + str(index)), encoding='utf-8')
            result = invoke(['--headless', '--path', str(project), '--script', test_resource(project, test)], project, env, TESTS[test])
            log_path = logs/(test+'.log')
            log_path.write_text(result.pop('output'), encoding='utf-8')
            report['tests'].append({'script': test, **result, 'log': str(log_path)})
            report['test_scripts_executed'] += int(result['launched'])
            report['test_scripts_passed'] += int(result['ok'])
        report['status'] = 'passed' if report['test_scripts_passed'] == len(selected) else 'failed'
    save()
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
