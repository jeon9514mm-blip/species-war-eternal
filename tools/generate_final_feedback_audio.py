#!/usr/bin/env python3
"""Author four small original mono PCM cues, offline and reproducibly."""
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / "audio" / "final-feedback"


def tone(t, frequency):
    return math.sin(2 * math.pi * frequency * t)


def compose(name, seconds):
    rng = random.Random(20261008 + sum(map(ord, name)))
    result = []
    low_noise = 0.0
    for index in range(round(seconds * RATE)):
        t = index / RATE
        fade = min(1.0, t / .002) * min(1.0, (seconds - t) / .008)
        noise = rng.uniform(-1, 1)
        low_noise = .76 * low_noise + .24 * noise
        if name == "Hit":
            value = .58 * low_noise * math.exp(-t * 30) + .30 * tone(t, 150 - 220 * t) * math.exp(-t * 38)
            value += .12 * noise * math.exp(-t * 75)
        elif name == "Crit":
            value = .45 * low_noise * math.exp(-t * 20) + .34 * tone(t, 110 - 90 * t) * math.exp(-t * 23)
            value += .16 * (tone(t, 1800) + .45 * tone(t, 2830)) * math.exp(-t * 42)
        elif name == "Gold":
            value = 0.0
            for onset, frequency in [(0, 880), (.075, 1108.7), (.15, 1318.5)]:
                if t >= onset:
                    elapsed = t - onset
                    value += .24 * min(1, elapsed / .003) * math.exp(-elapsed * 12) * (tone(elapsed, frequency) + .18 * tone(elapsed, frequency * 2.76))
        else:
            value = .40 * tone(t, 340 + 1050 * t) * math.exp(-t * 11)
            value += .20 * low_noise * math.exp(-((t - .09) / .065) ** 2)
            value += .16 * tone(t, 680 + 2100 * t) * math.exp(-t * 16)
        result.append(value * fade)
    peak = max(map(abs, result))
    # Fixed headroom; random runtime variation only attenuates volume.
    return [v * min(1.0, .72 / max(.001, peak)) for v in result]


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    tracks = {}
    for name, seconds in [("Hit", .16), ("Crit", .24), ("Gold", .45), ("Skill", .34)]:
        data = compose(name, seconds)
        path = ROOT / (name + ".wav")
        with wave.open(str(path), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(b"".join(struct.pack("<h", round(v * 32767)) for v in data))
        tracks[name] = {"file": path.relative_to(ROOT.parents[1]).as_posix(), "seconds": len(data) / RATE,
                        "sample_rate": RATE, "channels": 1, "peak": max(map(abs, data)),
                        "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    (ROOT / "manifest.json").write_text(json.dumps({"origin": "Original offline authored procedural PCM SFX; no third-party audio.",
        "generator": "tools/generate_final_feedback_audio.py", "tracks": tracks}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"tracks": len(tracks), "bytes": sum(v["bytes"] for v in tracks.values())}))


if __name__ == "__main__":
    main()
