"""Run the real raid-coordinate pacing probe with an isolated save directory."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser()
parser.add_argument("--label", default="before")
parser.add_argument("--health", action="store_true", help="Inspect hunt health-bar ownership and actual runtime colors")
parser.add_argument("--portrait-health", action="store_true", help="Use the actual native capture's PortraitMain and combat fixture")
parser.add_argument("--gpu", action="store_true", help="Run this probe on the real Mobile GPU renderer")
args = parser.parse_args()
if not args.label.replace("-", "").isalnum():
    raise SystemExit("Use an alphanumeric label with hyphens")
output = repo / "checks/gameplay-field-2026-10-08" / (("hunt-native-health-" if args.portrait_health else "hunt-health-" if args.health else "raid-movement-pacing-") + args.label + ".json")
script = "HuntNativeHealthProbe.gd" if args.portrait_health else "HuntHealthBarProbe.gd" if args.health else "RaidMovementPacingProbe.gd"
marker = "HUNT_NATIVE_HEALTH_PROBE " if args.portrait_health else "HUNT_HEALTH_PROBE " if args.health else "RAID_MOVEMENT_PACING "
binary = repo.parent / "validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
with tempfile.TemporaryDirectory(dir=repo.parent / "validation", prefix="raid-pacing-", ignore_cleanup_errors=True) as temporary:
    env = dict(os.environ, APPDATA=temporary, XDG_DATA_HOME=temporary,
               XDG_CONFIG_HOME=temporary, XDG_CACHE_HOME=temporary,
               RAID_PACING_OUTPUT=str(output), HUNT_HEALTH_OUTPUT=str(output))
    backend = ["--rendering-method", "mobile", "--resolution", "1120x630"] if args.gpu else ["--headless"]
    result = subprocess.run([str(binary), *backend, "--path", str(repo), "--script",
                             "res://tools/diagnostics/gameplay-field-2026-10-08/" + script],
                            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", timeout=180)
output.with_suffix(".log").write_text(result.stdout, encoding="utf-8")
if result.returncode or marker not in result.stdout or any(
    error in result.stdout for error in ("ERROR:", "SCRIPT ERROR", "leaked at exit")
):
    print(result.stdout[-12000:])
    raise SystemExit(1)
data = json.loads(output.read_text(encoding="utf-8"))
print(json.dumps(data, ensure_ascii=False, indent=2) if not args.portrait_health else str(output))
