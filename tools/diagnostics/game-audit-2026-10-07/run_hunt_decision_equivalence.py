"""Read old decision scripts from Git and compare them with live code headlessly."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline', default='70b2e7e98eeb736171fef11240b5d85fb2fc65b5')
parser.add_argument('--output', default='checks/stutter-fix-2026-10-08/decision-equivalence.json')
parser.add_argument('--verbose', action='store_true')
args = parser.parse_args()
output = REPO / args.output
output.parent.mkdir(parents=True, exist_ok=True)
binary = REPO.parent / 'validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
with tempfile.TemporaryDirectory(prefix='hunt-decision-art-pilot-', ignore_cleanup_errors=True) as tmp:
    root = Path(tmp)
    for relative in ['scripts/hunting/HuntingTargetDirector.gd', 'scripts/heroes/HeroKitRuntime.gd']:
        source = subprocess.check_output(['git', 'show', args.baseline + ':' + relative], cwd=REPO).decode('utf-8')
        source = source.replace('class_name HeroKitRuntime\n', '')
        (root / Path(relative).name).write_text(source, encoding='utf-8')
    env = dict(os.environ, APPDATA=tmp, XDG_DATA_HOME=tmp, XDG_CONFIG_HOME=tmp, XDG_CACHE_HOME=tmp, HUNT_DECISION_BASELINE=root.as_posix())
    command = [str(binary), '--headless', '--path', str(REPO), '--script', 'res://tools/diagnostics/game-audit-2026-10-07/HuntDecisionEquivalenceProbe.gd']
    if args.verbose:
        command.append('--verbose')
    proc = subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', timeout=180)
    (output.parent / 'decision-equivalence.log').write_text(proc.stdout, encoding='utf-8')
    if proc.returncode or any(token in proc.stdout for token in ['SCRIPT ERROR', 'ERROR:', 'leaked at exit']):
        print(proc.stdout[-15000:])
        raise SystemExit(1)
    line = next(line for line in proc.stdout.splitlines() if line.startswith('HUNT_DECISION_EQUIVALENCE '))
    report = json.loads(line.removeprefix('HUNT_DECISION_EQUIVALENCE '))
    report['baseline_commit'] = args.baseline
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False))
