"""Deterministic Blender authoring for the Ultra floor's packed PBR maps.

Run Blender --background --factory-startup --python tools/build_ultra_floor.py.
No actor meshes, atlas pixels, catalog entries or gameplay data are changed.
The 4K micro map is a quality alternative; Mobile binds the 1024 version.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/mobile25d/floor"
OUT.mkdir(parents=True, exist_ok=True)


def save(name, rgb, alpha, filename):
    h, w = alpha.shape
    image = bpy.data.images.new(name, width=w, height=h, alpha=True)
    image.colorspace_settings.name = "Non-Color"
    rgba = np.empty((h, w, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(rgb, 0, 1)
    rgba[..., 3] = np.clip(alpha, 0, 1)
    image.pixels.foreach_set(np.ascontiguousarray(rgba[::-1]).ravel())
    image.filepath_raw = str(OUT / filename)
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def normal_from_height(height, strength):
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    normal = np.stack([-gx, -gy, np.ones_like(gx)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1)[..., None]
    return normal * .5 + .5


size = 1024
y, x = np.mgrid[:size, :size]
u = (x / size).astype(np.float32)
v = (y / size).astype(np.float32)
rng = np.random.default_rng(20261008)
noise = rng.random((size, size), dtype=np.float32)
nearest = np.full((size, size), 10, dtype=np.float32)
second = nearest.copy()
for a in range(3):
    for b in range(3):
        sx = (a + .5 + rng.uniform(-.22, .22)) / 3
        sy = (b + .5 + rng.uniform(-.22, .22)) / 3
        dx = np.mod(u - sx + .5, 1) - .5
        dy = np.mod(v - sy + .5, 1) - .5
        distance = np.sqrt(dx * dx + dy * dy)
        second = np.minimum(second, np.maximum(nearest, distance))
        nearest = np.minimum(nearest, distance)
edge = (second - nearest) * size * .55
crack = np.clip(1 - edge / 8, 0, 1)
wear_broad = np.clip(1 - edge / 19, 0, 1) - crack
wear_fine = np.clip(1 - edge / 11, 0, 1) - crack
coarse = (np.sin(u * math.tau * 11 + np.cos(v * math.tau * 7)) + np.sin(v * math.tau * 13)) * .5
height = .53 + coarse * .025 + (noise - .5) * .012 - crack * .32
height += wear_broad * .04 + wear_fine * .025
stone = np.stack([.32 + coarse * .012, .345 + coarse * .014, .332 + coarse * .01], axis=-1)
stone += (noise - .5)[..., None] * .022
detail_path = ROOT / "assets/mobile25d/source/stone_detail.png"
if detail_path.exists():
    # Retain the approved artist mineral paint under the new PBR masks.
    image = bpy.data.images.load(str(detail_path), check_existing=False)
    image.colorspace_settings.name = "Non-Color"
    image.scale(size, size)
    pixels = np.empty(size * size * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    detail = pixels.reshape(size, size, 4)[::-1, :, :3].copy()
    bpy.data.images.remove(image)
    stone = (detail * .86 + stone * .14) * .78
    height += (detail.mean(axis=-1) - .5) * .025
stone *= 1 - crack[..., None] * .40
stone += (wear_broad * .10 + wear_fine * .06)[..., None] * .8
cracks = crack > .2
locations = np.flatnonzero(cracks)
order = locations[np.argsort(noise.ravel()[locations])]
patina = np.zeros_like(cracks)
patina.ravel()[order[:round(len(order) * .25)]] = True
patina_strength = .35 + (noise[patina] > .12) * .12
stone[patina] = stone[patina] * (1 - patina_strength[:, None]) + np.array([107, 138, 122]) / 255 * patina_strength[:, None]
# A broad crack band provides all 18% coverage without moss in slab centers.
moss_band = edge < 36
locations = np.flatnonzero(moss_band)
score = noise * .25 + np.sin(u * math.tau * 7) * .20 + np.cos(v * math.tau * 11) * .15 + crack * .65
order = locations[np.argsort(score.ravel()[locations])[::-1]]
moss = np.zeros_like(cracks)
moss.ravel()[order[:round(size * size * .18)]] = True
moss_strength = .38 + np.clip(score[moss], 0, 1) * .20
stone[moss] = stone[moss] * (1 - moss_strength[:, None]) + np.array([168, 184, 158]) / 255 * moss_strength[:, None]
dust = (.5 + .5 * np.sin(u * math.tau * 3) * np.cos(v * math.tau * 5)) * .15 * (1 - crack)
stone = stone * (1 - dust[..., None]) + np.array([216, 213, 204]) / 255 * dust[..., None] * .45
wet_field = np.sin(u * math.tau * 2 + np.cos(v * math.tau * 3)) * .5 + np.sin(v * math.tau * 2) * .5
wetness = np.clip((wet_field - .56) * 2.4, 0, 1) * (1 - moss.astype(np.float32) * .7)
height -= wetness * .018
ao = 1 - crack * .7
cavity = np.clip(crack + wear_fine * .16, 0, 1)
curvature = np.clip(wear_broad * 2.3 + wear_fine * 2.0, 0, 1)
save("Ultra stone albedo AO", stone, ao, "stone_1024_albedo_ao.png")
save("Ultra stone normal", normal_from_height(height, 7), np.ones_like(ao), "stone_1024_normal.png")
save("Ultra stone AO authoring", np.stack([ao, ao, ao], axis=-1), np.ones_like(ao), "stone_1024_ao.png")
save("Ultra stone packed HeightCavityCurvatureWetness", np.stack([height, cavity, curvature], axis=-1), wetness, "stone_1024_surface.png")


def micro_map(resolution):
    # Seamless integer harmonics produce mineral pores at two detail scales.
    # Same continuous field is independently sampled at 1024 and 4096.
    yy, xx = np.mgrid[:resolution, :resolution].astype(np.float32) / resolution
    field = np.sin(xx * math.tau * 121 + np.sin(yy * math.tau * 73) * 1.8) * .006
    field += np.cos(yy * math.tau * 173 + np.sin(xx * math.tau * 53)) * .004
    field += np.sin((xx + yy) * math.tau * 233) * .002
    save(f"Ultra {resolution} mineral micro normal", normal_from_height(field, resolution / 1024 * 3), np.ones_like(field), f"stone_{resolution}_micro_normal.png")


micro_map(1024)
micro_map(4096)
metadata = {
    "schema": 2, "texture_size": [1024, 1024], "roughness": .58, "metallic": .32,
    "patina_fraction_in_cracks": float(patina.sum() / cracks.sum()),
    "moss_fraction": float(moss.mean()), "moss_outside_crack_band": int((moss & ~moss_band).sum()),
    "moss_color": "#A8B89E", "patina_color": "#6B8A7A", "edge_wear": .8,
    "edge_wear_stages": 2, "moss_stages": 2, "patina_stages": 2,
    "crack_dark": .4, "dust": .15, "ao_strength": .7, "moss_glow": .25,
    "height_scale": .08, "packed_surface_channels": "R=height G=cavity B=curvature A=wetness",
    "runtime_ao_channel": "albedo alpha", "runtime_textures": 4,
    "runtime_bc7_bc5_bytes_with_mipmaps": 5592405,
    "micro_normal_mobile": "stone_1024_micro_normal.png",
    "micro_normal_quality_alternative": "stone_4096_micro_normal.png",
    "micro_normal_quality_extra_bc5_bytes_with_mipmaps": 20971520,
    "wet_fraction": float((wetness > .1).mean()),
    "parallax_steps_mobile": 4, "parallax_steps_forward_plus": 8,
    "footprint_pool": 50, "ao_separate_image": "authoring reference; runtime AO in albedo alpha",
}
metadata["image_sha256"] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(OUT.glob("stone_*.png"))}
(OUT / "material.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
print("ULTRA_FLOOR_BUILD_OK", json.dumps({k: metadata[k] for k in ["moss_fraction", "patina_fraction_in_cracks", "moss_outside_crack_band", "wet_fraction"]}), flush=True)
