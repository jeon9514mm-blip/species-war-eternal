"""Isolated20Hz CPU evidence or exact planner proof. Does not measureFPS."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser()
parser.add_argument("--label", default="before-instancing")
parser.add_argument("--equivalence", action="store_true")
args = parser.parse_args()
if not args.label.replace("-", "").isalnum():
    raise SystemExit("Use an alphanumeric label with hyphens")
output = repo / "checks/ultra-vfx-2026-10-08" / ("planner-equivalence.json" if args.equivalence else "cpu-budget-" + args.label + ".json")
script = "res://tests/regression/UltraPlannerEquivalenceSmokeTest.gd" if args.equivalence else "res://tools/diagnostics/ultra-vfx-2026-10-08/HuntCpuBudgetProbe.gd"
marker = "ULTRA_PLANNER_EQUIVALENCE_OK" if args.equivalence else "ULTRA_HUNT_CPU_BUDGET_OK"
binary = repo.parent / "validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
with tempfile.TemporaryDirectory(dir=repo.parent / "validation", prefix="ultra-cpu-", ignore_cleanup_errors=True) as temporary:
    env = dict(os.environ, APPDATA=temporary, XDG_DATA_HOME=temporary,
               XDG_CONFIG_HOME=temporary, XDG_CACHE_HOME=temporary,
               ULTRA_CPU_OUTPUT=str(output))
    result = subprocess.run([str(binary), "--headless", "--path", str(repo), "--script", script],
                            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", timeout=180)
output.with_suffix(".log").write_text(result.stdout, encoding="utf-8")
if result.returncode or marker not in result.stdout or any(
    error in result.stdout for error in ("ERROR:", "SCRIPT ERROR", "leaked at exit")
):
    print(result.stdout[-12000:])
    raise SystemExit(1)
print(json.dumps(json.loads(output.read_text(encoding="utf-8")), ensure_ascii=False, indent=2))
