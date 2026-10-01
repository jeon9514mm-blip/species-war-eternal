#!/usr/bin/env python3
"""Small source-level guard for Godot 4.7 migration-sensitive APIs used by this project."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    "ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT": "RichTextLabel enum renamed in Godot 4.7",
    "tap_back_pos": "AudioEffectSpectrumAnalyzer.tap_back_pos removed in Godot 4.7",
    "accessibility_live": "Control accessibility enum type changed in Godot 4.7",
}
failures = []
for path in ROOT.rglob("*.gd"):
    text = path.read_text(encoding="utf-8")
    for needle, reason in PATTERNS.items():
        if needle in text:
            failures.append(f"{path.relative_to(ROOT)}: {needle} ({reason})")
if failures:
    print("GODOT 4.7 COMPAT SCAN FAILED")
    for item in failures:
        print(" -", item)
    sys.exit(1)
print("GODOT 4.7 COMPAT SCAN OK")
