"""Run native Mobile renderer skill captures with an isolated disposable save."""
from pathlib import Path
import argparse
import json
import os
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser()
parser.add_argument("--output", default="checks/ultra-vfx-2026-10-08/showcase")
parser.add_argument("--timeout", type=int, default=300)
args = parser.parse_args()
output = REPO / args.output
output.mkdir(parents=True, exist_ok=True)
binary = REPO.parent / "validation" / "godot-4.7.2" / "Godot_v4.7.2-stable_win64_console.exe"
with tempfile.TemporaryDirectory(dir=REPO.parent / "validation", prefix="ultra-showcase-", ignore_cleanup_errors=True) as temp:
    env = dict(os.environ, GAME_AUDIT_OUTPUT=str(output), APPDATA=temp,
               XDG_DATA_HOME=temp, XDG_CONFIG_HOME=temp, XDG_CACHE_HOME=temp)
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    result = subprocess.run([str(binary), "--path", str(REPO), "--rendering-method", "mobile",
        "--audio-driver", "Dummy", "--disable-vsync", "--script",
        "res://tools/diagnostics/ultra-vfx-2026-10-08/NativeUltraSkillShowcase.gd"],
        env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", timeout=args.timeout, startupinfo=startup)
(output / "capture.log").write_text(result.stdout, encoding="utf-8")
if result.returncode or "NATIVE_ULTRA_SKILL_SHOWCASE_OK" not in result.stdout or any(
        marker in result.stdout for marker in ["ERROR:", "SCRIPT ERROR", "leaked at exit"]):
    print(result.stdout[-15000:])
    raise SystemExit(1)
notes = json.loads((output / "showcase-fixture.json").read_text("utf-8"))
assert notes["registered_identity_count"] == 120 and len(notes["captures"]) == 28
assert all((output / capture["file"]).is_file() for capture in notes["captures"])
print(json.dumps({"native_captures": len(notes["captures"]), "heroes": notes["hero_count"],
                  "registered_identities": notes["registered_identity_count"],
                  "actual_active_casts": notes["actual_active_cast_count"],
                  "passive_review_fixtures": notes["explicit_passive_fixture_count"],
                  "natural_passive_proc_claim": False, "performance_measurement": False}))
