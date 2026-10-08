#!/usr/bin/env python3
"""Validate authored PCM coverage, safety headroom and deterministic output."""
import hashlib
import json
from pathlib import Path
import runpy
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "audio" / "ultra-skills"


def digest_files():
    return {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in OUTPUT.iterdir() if path.suffix in [".wav", ".json"]}


def main():
    before = digest_files()
    runpy.run_path(str(ROOT / "tools" / "generate_ultra_skill_audio.py"), run_name="__main__")
    after = digest_files()
    assert before == after, "Regeneration changed authored waveform bytes or manifest"
    manifest = json.loads((OUTPUT / "manifest.json").read_text("utf-8"))
    catalog = json.loads((ROOT / "docs" / "hero-catalog-2026-10-08" / "hero-catalog.json").read_text("utf-8"))
    expected = {(hero["id"], skill["slot"], skill["id"]) for hero in catalog["heroes"] for skill in hero["skills"]}
    actual = {(track["hero_id"], track["slot"], track["skill_id"]) for track in manifest["tracks"].values()}
    assert actual == expected and len(actual) == 120
    hashes = set()
    max_peak = 0
    max_dc = 0
    for track in manifest["tracks"].values():
        path = ROOT / track["file"]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest == track["sha256"]
        hashes.add(digest)
        with wave.open(str(path), "rb") as input:
            assert input.getnchannels() == 1 and input.getsampwidth() == 2 and input.getframerate() == 22050
            frames = input.readframes(input.getnframes())
        samples = struct.unpack("<" + "h" * (len(frames) // 2), frames)
        peak = max(map(abs, samples)) / 32767
        dc = abs(sum(samples) / len(samples) / 32767)
        assert peak <= .721 and dc <= .00001
        assert abs(samples[0]) <= 150 and abs(samples[-1]) <= 150
        max_peak = max(max_peak, peak)
        max_dc = max(max_dc, dc)
    assert len(hashes) == 120
    result = {"schema": 1, "heroes": 30, "registered_skills": 120, "exact_registered_ids": True,
              "unique_waveforms": len(hashes), "byte_identical_regeneration": True,
              "mono_pcm_22050hz": True, "sample_bytes": manifest["sample_bytes"],
              "decoded_pcm_bytes": manifest["decoded_pcm_bytes"], "max_peak": max_peak,
              "max_dc_offset": max_dc, "physical_haptics_verified": False,
              "perceptual_listening_approval": False}
    path = ROOT / "checks" / "ultra-vfx-2026-10-08" / "audio-source-validation.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
