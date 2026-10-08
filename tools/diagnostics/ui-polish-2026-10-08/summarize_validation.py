"""Combine the latest checks while preserving intermediate failure evidence."""
from pathlib import Path
import hashlib
import json

REPO = Path(__file__).resolve().parents[3]
CHECKS = REPO / "checks/ui-polish-2026-10-08"
latest = {}
for report in ("gpu-integration.json", "gpu-repairs.json", "gpu-final.json", "gpu-layout-final.json"):
    data = json.loads((CHECKS / report).read_text(encoding="utf-8"))
    for row in data["results"]:
        latest[row["test"]] = {"passed": row["passed"], "report": report}
assert len(latest) == 10 and all(row["passed"] for row in latest.values())
parser = json.loads((CHECKS / "parser.json").read_text(encoding="utf-8"))
assert parser["passed"] == parser["total"]
for row in parser["results"]:
    assert hashlib.sha256((REPO / row["script"]).read_bytes()).hexdigest() == row["sha256"]
captures = []
for directory in ("battle", "heroes"):
    for path in sorted((CHECKS / directory).glob("*.png")):
        captures.append({"file": path.relative_to(CHECKS).as_posix(), "bytes": path.stat().st_size,
                         "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
assert len(captures) == 10
report = {"scope": "UI changes and GPU lifecycle regressions; not the full historical test suite",
          "latest_gpu": {"passed": len(latest), "total": len(latest), "results": latest},
          "parser": {"passed": parser["passed"], "total": parser["total"], "source_hashes_match": True},
          "native_captures": captures, "player_save_used": False,
          "new_performance_benchmark": False}
(CHECKS / "delivery-validation.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("UI_DELIVERY_VALIDATION_OK gpu=10/10 parser=%d/%d native_pngs=10" %
      (parser["passed"], parser["total"]))
