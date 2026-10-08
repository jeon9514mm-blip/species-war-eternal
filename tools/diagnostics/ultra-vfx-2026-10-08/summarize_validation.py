"""Summarize recorded native checks without replacing their raw evidence."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CHECKS = ROOT / "checks/ultra-vfx-2026-10-08"


def read(name):
    return json.loads((CHECKS / name).read_text(encoding="utf-8"))


latest = {}
for name in ("gpu-regressions.json", "gpu-repairs.json",
             "gpu-instancing-final.json", "gpu-final-integration.json"):
    for row in read(name)["results"]:
        latest[row["test"]] = {"passed": row["passed"], "report": name}
assert all(row["passed"] for row in latest.values())
parser = read("parser.json")
assert parser["passed"] == parser["total"]
for row in parser["results"]:
    assert hashlib.sha256((ROOT / row["script"]).read_bytes()).hexdigest() == row["sha256"]
planner = read("planner-equivalence.json")
assert planner["passed"] and planner["exact_state_match"]
forward = read("forward-environment.json")
assert forward["passed"] == forward["total"]
memory = read("review/process-memory.json")
performance = read("review/performance.json")
report = {
    "scope": "Recorded native integration checks; not the entire historical test suite",
    "parser": {"passed": parser["passed"], "total": parser["total"], "source_hashes_match": True},
    "latest_mobile": {"passed": len(latest), "total": len(latest), "results": latest},
    "forward_plus": {"passed": forward["passed"], "total": forward["total"]},
    "planner": {"checks": planner["checks"], "exact_state_match": True},
    "performance": {"report": "review/performance.json", "device": performance["device"],
                    "profiles": [{"label": row["label"], "mean_fps": row["mean_fps"],
                                  "p95_frame_ms": row["p95_frame_ms"]}
                                 for row in performance["profiles"]]},
    "memory": {"report": "review/process-memory.json", "scope": memory["scope"],
               "max_working_set_bytes": memory["max_working_set_bytes"],
               "max_private_bytes": memory["max_private_bytes"]},
    "goals": {"hunt_60fps_achieved": False, "total_process_200mb_achieved": False,
              "android_measured": False},
}
(CHECKS / "delivery-validation.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("DELIVERY_VALIDATION_OK parser=%d mobile=%d forward_plus=%d planner=%d" %
      (parser["total"], len(latest), forward["total"], planner["checks"]))
