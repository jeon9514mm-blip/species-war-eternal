"""Real Mobile timing review; use a disposable save and serialize GPU runs."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser()
parser.add_argument('--phase', required=True, choices=['before', 'after'])
args = parser.parse_args()
output = repo / 'checks/hunt-raid-improvements-2026-10-08' / args.phase
output.mkdir(parents=True, exist_ok=True)
sources = ['scripts/app/Main.gd', 'scripts/combat/BattleFormation.gd',
           'scripts/persistence/BackgroundHunt.gd', 'scripts/hunting/HuntBodyCollision.gd',
           'scripts/hunting/HuntPositionPlanner.gd', 'scripts/hunting/PartyMovementDirector.gd',
           'scripts/hunting/HuntProductivity.gd', 'scripts/maps3d/Battlefield3DView.gd',
           'scripts/maps3d/HeroCircleFormation.gd', 'scripts/art/RaidArenaBattlefield.gd',
           'scripts/presentation/PresentationRuntime.gd', 'scripts/maps3d/RaidEncounterArena.gd',
           'scripts/raid/RaidBattlefield.gd', 'scripts/maps3d/RaidFinalAtmosphere.gd',
           'scripts/portrait/RaidSelectionIndicator.gd', 'shaders/RaidArenaPBR.gdshader']
sources = [name for name in sources if (repo / name).is_file()]
source_hashes = {name: hashlib.sha256((repo / name).read_bytes()).hexdigest() for name in sources}
binary = repo.parent / 'validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
with tempfile.TemporaryDirectory(dir=repo.parent / 'validation', prefix='hunt-raid-review-',
                                 ignore_cleanup_errors=True) as temp:
    env = dict(os.environ, GAME_AUDIT_OUTPUT=str(output), APPDATA=temp,
               XDG_DATA_HOME=temp, XDG_CONFIG_HOME=temp, XDG_CACHE_HOME=temp)
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    result = subprocess.run([str(binary), '--path', str(repo), '--rendering-method', 'mobile',
                             '--audio-driver', 'Dummy', '--disable-vsync', '--script',
                             'res://tools/diagnostics/game-audit-2026-10-07/MovementPacingProbe.gd'],
                            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding='utf-8', timeout=180, startupinfo=startup)
(output / 'capture.log').write_text(result.stdout, encoding='utf-8')
(output / 'source-hashes.json').write_text(json.dumps(dict(phase=args.phase, sources=source_hashes,
    player_save_used=False, concurrent_gpu_runs=False, live_production_timing=True), indent=2)+'\n', encoding='utf-8')
checked = result.stdout.replace('ERROR: Failed to read the root certificate store.', '')
if result.returncode or 'MOVEMENT_PACING_OK' not in result.stdout or any(
        x in checked for x in ['ERROR:', 'SCRIPT ERROR', 'leaked at exit']):
    print(result.stdout[-12000:])
    raise SystemExit(1)
print((output / 'performance.json').read_text(encoding='utf-8'))
