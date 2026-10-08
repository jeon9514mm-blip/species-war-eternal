#!/usr/bin/env python3
"""Reproducibly author 120 original PCM cues from the registered 30-hero kit.

The element labels describe timbre only; they add no damage/resistance rules.
No downloaded, cloned, sampled or third-party audio is used.
"""
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "audio" / "ultra-skills"
RATE = 22050
SLOTS = {"passive": (.16, .38), "a1": (.28, .60), "a2": (.40, .64), "ultimate": (.72, .72)}
AUDIO_THEMES = {
    "leonhardt": "light", "mira": "ice", "elisia": "light", "kairen": "light",
    "orwin": "light", "seria": "ice", "astel": "light", "darius": "fire",
    "lunea": "ice", "caelum": "fire", "valeria": "fire", "morgas": "dark",
    "ragna": "dark", "bron": "fire", "nyx": "dark", "fenris": "ice",
    "isolde": "light", "garm": "fire", "veyra": "dark", "ulric": "dark",
    "adrien": "ice", "tessa": "fire", "naia": "light", "sael": "light",
    "odelia": "dark", "lucien": "fire", "corvin": "dark", "rokan": "ice",
    "bora": "ice", "selene": "light",
}


def audio_theme(hero):
    # Match the existing HeroSkillVfxPresenter palette; no combat-rule change.
    return AUDIO_THEMES[hero["id"]]


def tone(t, frequency):
    return math.sin(math.tau * frequency * t)


def compose(profile, slot):
    seconds, peak_limit = SLOTS[slot]
    signature = profile["signature"]
    rng = random.Random(signature + list(SLOTS).index(slot) * 113)
    base = profile["base_hz"] * {"passive": 1.5, "a1": 1, "a2": .8, "ultimate": .56}[slot]
    theme = "ice" if profile.get("hero_id") == "tessa" and slot == "a2" else profile["theme"]
    onset = {"passive": .018, "a1": .048, "a2": .086, "ultimate": .18}[slot]
    phase_offset = (signature % 101) / 101 * math.tau
    samples = []
    smooth = 0
    previous = 0
    shimmer = 1.95 + profile["ordinal"] / 73
    for index in range(round(seconds * RATE)):
        t = index / RATE
        noise = rng.uniform(-1, 1)
        smooth = .82 * smooth + .18 * noise
        high = noise - previous
        previous = noise
        # Charging -> release -> impact -> a short ring. Every slot has an
        # independently seeded attack and distinct length/frequency movement.
        charge = math.sin(math.pi * min(1, t / onset)) ** 2 if t < onset else 0
        value = charge * (.13 * smooth + .09 * tone(t, base * (1 + t * 4)))
        elapsed = max(0, t - onset)
        if t >= onset:
            env = min(1, elapsed / .003) * math.exp(-elapsed * (9 if slot == "ultimate" else 15))
            sweep = base * (1.72 - min(.90, elapsed * 2.4))
            if theme == "fire":
                value += env * (.56 * smooth + .22 * tone(elapsed, sweep) + .10 * high)
            elif theme == "ice":
                value += env * (.24 * high + .22 * tone(elapsed, base * 4.01) + .16 * tone(elapsed, base * 6.39))
            elif theme == "dark":
                value += env * (.32 * tone(elapsed, sweep) + .24 * smooth + .12 * math.sin(math.tau * base * .51 * elapsed + phase_offset))
            else:
                value += env * (.34 * tone(elapsed, base * 2) + .18 * tone(elapsed, base * shimmer) + .13 * smooth)
            # Hero-specific resonant signature and a differently timed echo.
            value += .10 * tone(elapsed, base * shimmer) * math.exp(-elapsed * 7)
            echo_time = .046 + profile["ordinal"] * .0012
            if elapsed >= echo_time:
                e = elapsed - echo_time
                value += .06 * tone(e, base * 2.72) * math.exp(-e * 18)
            if slot == "ultimate":
                value += .19 * tone(elapsed, base * .5) * math.exp(-elapsed * 8)
                value += .08 * tone(elapsed, base * 3.13) * math.exp(-elapsed * 5)
        fade = min(1, t / .002) * min(1, (seconds - t) / .018)
        samples.append(value * max(0, fade))
    mean = sum(samples) / len(samples)
    samples = [sample - mean for sample in samples]
    peak = max(map(abs, samples))
    gain = min(1, peak_limit / max(.001, peak))
    return [sample * gain for sample in samples]


def write_catalog(profiles):
    rows = ["extends RefCounted", "## Original timbre/haptic identity only. Never a combat element or RNG source.", "const HEROES := {"]
    for hero_id, profile in profiles.items():
        rows.append("\t%s: %s," % (json.dumps(hero_id), json.dumps(profile, ensure_ascii=False)))
    rows.extend(["}", "const SLOTS := {'passive':0, 'a1':1, 'a2':2, 'ultimate':3}", "const PREFIX := 'hero_skill:'", "", "static func profile(hero_id: String, slot: String) -> Dictionary:", "\tif not HEROES.has(hero_id) or not SLOTS.has(slot): return {}", "\tvar hero: Dictionary = HEROES[hero_id]", "\tvar index: int = int(SLOTS[slot])", "\tvar ordinal: int = int(hero.ordinal)", "\tvar strength := .22 + float(ordinal) * .004 + float(index) * .09", "\tvar first := [0, 12 + ordinal % 19 + index * 3, strength]", "\tvar pattern: Array = [first]", "\tif index > 0: pattern.append([55 + ordinal % 7 * 6, 10 + ordinal % 13 + index * 3, strength * .68])", "\tif index == 3: pattern.append([145 + ordinal % 5 * 9, 24 + ordinal % 17, minf(.75, strength + .1)])", "\treturn {'event':PREFIX + hero_id + ':' + slot, 'path':'res://audio/ultra-skills/' + hero_id + '__' + slot + '.wav',", "\t\t'priority':5 if slot == 'ultimate' else 2 if slot == 'passive' else 4,", "\t\t'cooldown':.7 if slot == 'ultimate' else .8 if slot == 'passive' else .24,", "\t\t'hero_id':hero_id, 'slot':slot, 'theme':'ice' if hero_id == 'tessa' and slot == 'a2' else hero.theme, 'haptic':pattern}", "", "static func event_spec(event: String) -> Array:", "\tif not event.begins_with(PREFIX): return []", "\tvar parts := event.trim_prefix(PREFIX).split(':')", "\tif parts.size() != 2: return []", "\tvar feedback := profile(parts[0], parts[1])", "\tif feedback.is_empty(): return []", "\treturn [feedback.path, 'effects', feedback.priority, feedback.cooldown]", ""])
    (ROOT / "scripts" / "presentation" / "HeroSkillFeedbackCatalog.gd").write_text("\n".join(rows), encoding="utf-8")


def main():
    catalog = json.loads((ROOT / "docs" / "hero-catalog-2026-10-08" / "hero-catalog.json").read_text("utf-8"))
    assert catalog["hero_count"] == 30 and catalog["skill_count"] == 120
    OUTPUT.mkdir(parents=True, exist_ok=True)
    profiles = {}
    tracks = {}
    for ordinal, hero in enumerate(catalog["heroes"]):
        signature = int.from_bytes(hashlib.sha256(hero["id"].encode()).digest()[:4], "big")
        profile = {"ordinal": ordinal, "signature": signature, "base_hz": round(118 + (signature % 199) * 1.21, 3), "theme": audio_theme(hero)}
        profiles[hero["id"]] = profile
        skills = {skill["slot"]: skill for skill in hero["skills"]}
        assert set(skills) == set(SLOTS)
        for slot in SLOTS:
            name = hero["id"] + "__" + slot
            samples = compose({**profile, "hero_id": hero["id"]}, slot)
            path = OUTPUT / (name + ".wav")
            with wave.open(str(path), "wb") as output:
                output.setnchannels(1)
                output.setsampwidth(2)
                output.setframerate(RATE)
                output.writeframes(b"".join(struct.pack("<h", round(max(-1, min(1, sample)) * 32767)) for sample in samples))
            tracks[name] = {"hero_id": hero["id"], "hero_name": hero["name"], "skill_id": skills[slot]["id"], "skill_name": skills[slot]["skill"], "slot": slot, "audio_theme": "ice" if hero["id"] == "tessa" and slot == "a2" else profile["theme"], "file": path.relative_to(ROOT).as_posix(), "seconds": len(samples) / RATE, "sample_rate": RATE, "channels": 1, "peak": round(max(map(abs, samples)), 6), "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    assert len(tracks) == 120 and len({track["sha256"] for track in tracks.values()}) == 120
    write_catalog(profiles)
    manifest = {"schema": 1, "origin": "120 original deterministic procedural PCM cues; no third-party audio or cloned voices.", "generator": "tools/generate_ultra_skill_audio.py", "classification": "The four element labels are audio direction only and do not add damage or resistance rules.", "hero_count": len(profiles), "unique_waveforms": len(tracks), "sample_bytes": sum(track["bytes"] for track in tracks.values()), "decoded_pcm_bytes": sum(track["bytes"] - 44 for track in tracks.values()), "tracks": tracks}
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"heroes": len(profiles), "cues": len(tracks), "unique_waveforms": len({track["sha256"] for track in tracks.values()}), "bytes": manifest["sample_bytes"]}))


if __name__ == "__main__":
    main()
