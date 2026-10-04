#!/usr/bin/env python3
"""Run repeatable production combat/economy forecasts with isolated player saves."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot') or shutil.which('godot4'))
    parser.add_argument('--days', type=int, choices=[1, 7, 30], default=30)
    parser.add_argument('--seeds', type=int, nargs='+', default=[3401])
    parser.add_argument('--jobs', type=int, choices=[1, 2], default=2)
    parser.add_argument('--output', type=Path, default=Path('checks/first-session-economy/replay'))
    args = parser.parse_args()
    if not args.godot:
        parser.error('Specify a Godot 4 executable with --godot.')
    binary = str(Path(args.godot).resolve())
    repo = Path(__file__).resolve().parents[1]
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)

    def run(case):
        faction, seed = case
        name = f'{faction}-{seed}-{args.days}'
        report_path = out / (name + '.json')
        with tempfile.TemporaryDirectory(prefix='economy-audit-') as isolated:
            env = dict(os.environ)
            for variable, leaf in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
                env[variable] = str(Path(isolated) / leaf)
            try:
                result = subprocess.run(
                    [binary, '--headless', '--path', str(repo), '--script', 'tools/LongTermEconomySimulation.gd',
                     '--', faction, str(seed), str(args.days), '--report=' + str(report_path)],
                    env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=7200)
                log = result.stdout
                passed = result.returncode == 0 and 'ERROR:' not in log and 'SCRIPT ERROR:' not in log
                report = json.loads(report_path.read_text()) if passed else {}
                errors = []
                if passed:
                    first = report['first_ten_minutes']
                    if not (0 < first['first_pack_seconds'] <= 120 and 0 < first['first_three_seconds'] <= 600 and 0 < first['first_upgrade_seconds'] <= 600):
                        errors.append('First session missed the 2-minute first pack / 10-minute formation and growth budgets.')
                    for row in report['rows']:
                        if row['gold'] < 0 or row['spent_gold'] < 0 or not all(1 <= n <= 100 for n in row['levels']):
                            errors.append('Invalid wallet or hero level.')
                        if row['day'] >= 7 and row['max_level_heroes'] == row['party']:
                            errors.append('All deployed heroes capped before the long-term forecast ended.')
                    passed = not errors
                else:
                    errors = ['Engine execution failed; see case log.']
            except (subprocess.TimeoutExpired, ValueError, OSError) as error:
                log = str(error)
                passed = False
                errors = [str(error)]
        (out / (name + '.log')).write_text(log)
        row = {'faction': faction, 'seed': seed, 'days': args.days, 'passed': passed, 'errors': errors}
        print(json.dumps(row), flush=True)
        return row

    cases = [(faction, seed) for faction in ['aurelia', 'noxfera'] for seed in args.seeds]
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        rows = list(pool.map(run, cases))
    summary = {'model': '10 active minutes plus one 8-hour offline receipt per day; no purchases or ads', 'cases': rows}
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    return 0 if all(row['passed'] for row in rows) else 1


if __name__ == '__main__':
    raise SystemExit(main())
