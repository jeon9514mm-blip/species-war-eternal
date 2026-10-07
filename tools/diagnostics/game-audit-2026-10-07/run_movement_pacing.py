"""Measure the real player loop without frame readback or concurrent benchmarks."""
from pathlib import Path
import argparse
import os
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser()
parser.add_argument('--phase', required=True, choices=['before', 'after'])
args = parser.parse_args()
output = repo / 'checks/movement-pacing-2026-10-08' / args.phase
output.mkdir(parents=True, exist_ok=True)
binary = repo.parent / 'validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
with tempfile.TemporaryDirectory(dir=repo.parent / 'validation', prefix='pacing-', ignore_cleanup_errors=True) as temp:
    env = dict(os.environ, GAME_AUDIT_OUTPUT=str(output), APPDATA=temp, XDG_DATA_HOME=temp, XDG_CONFIG_HOME=temp, XDG_CACHE_HOME=temp)
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    result = subprocess.run([str(binary), '--path', str(repo), '--rendering-method', 'mobile', '--audio-driver', 'Dummy', '--disable-vsync', '--script', 'res://tools/diagnostics/game-audit-2026-10-07/MovementPacingProbe.gd'], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', timeout=180, startupinfo=startup)
(output / 'capture.log').write_text(result.stdout, encoding='utf-8')
# This Windows sandbox can deny the system CA store during engine startup.
# Preserve it in the log, but never confuse it with a scene/script error.
checked_output = result.stdout.replace('ERROR: Failed to read the root certificate store.', '')
if result.returncode or 'MOVEMENT_PACING_OK' not in result.stdout or any(x in checked_output for x in ['ERROR:', 'SCRIPT ERROR', 'leaked at exit']):
    print(result.stdout[-10000:])
    raise SystemExit(1)
print((output / 'performance.json').read_text(encoding='utf-8'))
