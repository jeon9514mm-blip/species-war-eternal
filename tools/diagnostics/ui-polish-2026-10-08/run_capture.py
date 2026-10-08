"""Capture real native menus without using the player's save or a visible helper window."""
from pathlib import Path
import os
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[3]
OUTPUT = REPO / "checks/ui-polish-2026-10-08/battle"
OUTPUT.mkdir(parents=True, exist_ok=True)
BINARY = REPO.parent / "validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
with tempfile.TemporaryDirectory(dir=REPO.parent / "validation", prefix="ui-review-",
                                 ignore_cleanup_errors=True) as temp:
    env = dict(os.environ, APPDATA=temp, XDG_DATA_HOME=temp,
               XDG_CONFIG_HOME=temp, XDG_CACHE_HOME=temp)
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    result = subprocess.run([str(BINARY), "--path", str(REPO), "--rendering-method", "mobile",
                             "--audio-driver", "Dummy", "--script",
                             "res://tools/diagnostics/ui-polish-2026-10-08/CaptureBattleUi.gd"],
                            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", timeout=180, startupinfo=startup)
(OUTPUT / "capture.log").write_text(result.stdout, encoding="utf-8")
if result.returncode or "BATTLE_UI_CAPTURE_OK" not in result.stdout or any(
        marker in result.stdout for marker in ("ERROR:", "SCRIPT ERROR", "leaked at exit")):
    print(result.stdout[-12000:])
    raise SystemExit(1)
print("BATTLE_UI_CAPTURE_OK native_pngs=6")
