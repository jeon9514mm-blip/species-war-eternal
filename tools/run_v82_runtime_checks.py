#!/usr/bin/env python3
"""Real v82 engine verification in an isolated disposable project.

Example: python3 tools/run_v82_runtime_checks.py --godot /path/to/godot --output /tmp/v82-results.json
No source ZIPs, player saves, account access or network/deployment operations.
A missing engine is BLOCKED, not PASSED. Every subprocess is bounded and logged.
"""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import uuid

from run_v80_runtime_checks import TESTS as V80_TESTS, evaluate_output, isolate_project_name

ROOT = Path(__file__).resolve().parents[1]
DEVELOPMENT_STEP = "v82-1"
TESTS = {
    **V80_TESTS,
    "V74BossRaidBehaviorSmokeTest.gd": "V74BossRaidBehaviorSmokeTest:",
    "V78ConvenienceUiSmokeTest.gd": "v78_convenience_ui",
    "V79ConvenienceFlowSmokeTest.gd": "v79_convenience_flow",
    "V81GoalRulesSmokeTest.gd": "v81_goal_rules",
    "V81GoalSaveSmokeTest.gd": "v81_goal_save",
    "V81GoalClaimSmokeTest.gd": "v81_goal_claim",
    "V81GoalBattleSmokeTest.gd": "v81_goal_battle",
    "V81GoalUiSmokeTest.gd": "v81_goal_ui",
    "V82SettingsSmokeTest.gd": "v82_settings",
    "V82AudioSmokeTest.gd": "v82_audio",
    "V82PresentationUiSmokeTest.gd": "v82_presentation_ui",
    "V82PerformanceSmokeTest.gd": "v82_performance",
    "V82LifecycleSmokeTest.gd": "v82_lifecycle",
    "V51FxLifecycleSmokeTest.gd": "v51_fx_lifecycle",
    "V31HeroFxSmokeTest.gd": "v31_hero_fx",
    "V57QualityPassSmokeTest.gd": "V57 QUALITY PASS",
}


def source_hashes(root: Path) -> dict[str, str]:
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(root.rglob("*")) if p.is_file()
            and p.suffix in (".gd", ".tscn") and ".godot" not in p.parts}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", ""))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--expected-version", default="4.7.2")
    parser.add_argument("--test", choices=TESTS, action="append")
    parser.add_argument("--import-cache", type=Path, help="Optional .godot cache from same engine; engine still reimports/verifies resources")
    parser.add_argument("--skip-compile", action="store_true", help="Explicitly record compilation as not requested")
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    logs = output.parent / (output.stem + "-logs")
    logs.mkdir(exist_ok=True)
    selected = list(dict.fromkeys(args.test or TESTS))
    engine = shutil.which(args.godot) if args.godot else (shutil.which("godot") or shutil.which("godot4"))
    if not engine and args.godot and Path(args.godot).expanduser().is_file():
        engine = str(Path(args.godot).expanduser().resolve())
    workers = max(1, min(3, args.workers)) if os.name == "posix" else 1
    report = {
        "development_step": DEVELOPMENT_STEP, "status": "running", "engine": engine,
        "started_at_utc": datetime.now(timezone.utc).isoformat(),
        "compile_requested": not args.skip_compile, "compile": [], "tests": [],
        "test_scripts_requested": len(selected), "test_scripts_executed": 0,
        "test_scripts_passed": 0, "workers": workers,
        "android_tests_executed": 0, "gpu_rendering_tested": False,
        "limitations": ["Focused suite, not all historical tests", "Headless, not Android or GPU certification",
                        "Levelled three-hero combat fixtures, not all 10-hero combinations",
                        "Generated audio is not a human listening or Android sound-device test",
                        "Haptic sink tests do not vibrate physical hardware",
                        "IO fault injection tests are separate from actual filesystem roundtrip tests"],
        "source_code_sha256": source_hashes(ROOT),
    }

    def save() -> None:
        temporary = output.with_suffix(output.suffix + ".tmp")
        temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        temporary.replace(output)

    def env_for(directory: Path) -> dict[str, str]:
        env = os.environ.copy()
        for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            path = directory / key.lower()
            path.mkdir(parents=True, exist_ok=True)
            env[key] = str(path)
        env["GODOT_SILENCE_ROOT_WARNING"] = "1"
        return env

    def invoke(argv: list[str], cwd: Path, env: dict[str, str], log_name: str, marker: str = "") -> dict:
        started = time.monotonic()
        launched = False
        code = None
        text = ""
        timed_out = False
        try:
            process = subprocess.Popen([engine, *argv], cwd=cwd, env=env, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
            launched = True
            try:
                text, _ = process.communicate(timeout=max(1, args.timeout))
                code = process.returncode
            except subprocess.TimeoutExpired:
                timed_out = True
                process.kill()
                text, _ = process.communicate()
                code = process.returncode
                text += "\nRUNNER TIMEOUT: process killed\n"
        except OSError as exc:
            text = str(exc)
        ok, reason = evaluate_output(code, text, marker)
        if timed_out:
            ok, reason = False, "timeout"
        log = logs / log_name
        log.write_text(text, encoding="utf-8")
        counts = re.findall(r"\bchecks\s*=\s*(\d+)|\b(\d+)\s+checks\b", text)
        checks = int(next((a or b for a, b in reversed(counts)), "0"))
        return {"ok": ok, "reason": reason, "launched": launched, "returncode": code,
                "seconds": round(time.monotonic() - started, 3), "log": str(log),
                "check_count": checks, "warning_lines": [line for line in text.splitlines() if "WARNING:" in line]}

    if not engine:
        report.update(status="blocked", reason="No executable: zero engine tests ran.")
        save()
        return 2
    save()
    with tempfile.TemporaryDirectory(prefix="species-" + DEVELOPMENT_STEP + "-engine-") as directory:
        temp = Path(directory)
        env = env_for(temp / "import-data")
        version_result = invoke(["--version"], ROOT, env, "version.log")
        version = (logs / "version.log").read_text(encoding="utf-8").strip()
        report["version"] = version
        report["version_check"] = version_result
        if not version_result["ok"] or not version.startswith(args.expected_version + "."):
            report.update(status="blocked", reason="Engine failed or its version did not match.")
            save()
            return 2
        project = temp / "project"
        shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns(".git", ".godot", "__pycache__", "checks"))
        if args.import_cache and args.import_cache.is_dir():
            shutil.copytree(args.import_cache, project / ".godot")
            report["import_cache_used"] = str(args.import_cache)
        config = project / "project.godot"
        original_config = config.read_text(encoding="utf-8")
        namespace = "SpeciesWar" + DEVELOPMENT_STEP + "Test-" + uuid.uuid4().hex
        config.write_text(isolate_project_name(original_config, namespace), encoding="utf-8")
        report["isolation"] = "Disposable full project; unique project name; per-process XDG user/save directories. Windows uses sequential unique project names."
        report["import"] = invoke(["--headless", "--path", str(project), "--import", "--quit"], project, env, "import.log")
        save()
        if not report["import"]["ok"]:
            report.update(status="failed", reason="Import failed; no test result fabricated.")
            save()
            return 1
        if not args.skip_compile:
            scripts = sorted(p.relative_to(project).as_posix() for p in project.rglob("*.gd") if ".godot" not in p.parts)
            report["compile_scripts_requested"] = len(scripts)
            def compile_one(path: str) -> dict:
                result = invoke(["--headless", "--path", str(project), "--check-only", "--script", "res://" + path],
                                project, env_for(temp / "compile-data"), "compile-" + path.replace("/", "_") + ".log")
                return {"script": path, **result}
            with ThreadPoolExecutor(max_workers=workers) as pool:
                for future in as_completed([pool.submit(compile_one, p) for p in scripts]):
                    report["compile"].append(future.result())
                    save()
            report["compile"].sort(key=lambda item: item["script"])
            report["compile_scripts_passed"] = sum(item["ok"] for item in report["compile"])
            save()
        def run_one(index: int, test: str) -> dict:
            # XDG isolates POSIX processes. On Windows no test runs concurrently;
            # mutate only the temporary project's name for a unique user:// path.
            if os.name != "posix":
                config.write_text(isolate_project_name(original_config, namespace + "-" + str(index)), encoding="utf-8")
            result = invoke(["--headless", "--path", str(project), "--script", "res://scripts/" + test],
                            project, env_for(temp / ("case-" + str(index))), test + ".log", TESTS[test])
            return {"script": test, **result}
        with ThreadPoolExecutor(max_workers=workers) as pool:
            for future in as_completed([pool.submit(run_one, i, t) for i, t in enumerate(selected)]):
                result = future.result()
                report["tests"].append(result)
                report["test_scripts_executed"] += int(result["launched"])
                report["test_scripts_passed"] += int(result["ok"])
                save()
        report["tests"].sort(key=lambda item: selected.index(item["script"]))
        report["status"] = "passed" if all(item["ok"] for item in report["tests"] + report["compile"]) else "failed"
        report["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
        save()
    print(json.dumps({key: report.get(key) for key in ("status", "version", "compile_scripts_passed", "compile_scripts_requested", "test_scripts_passed", "test_scripts_executed")}, ensure_ascii=False))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
