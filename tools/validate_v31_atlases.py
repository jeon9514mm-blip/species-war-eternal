#!/usr/bin/env python3
"""Read-only alpha coverage audit for the v31 original sprite PNGs (Pillow)."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default='docs/v31-atlas-integrity.json')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    manifest = json.loads((project / 'assets/sprites/heroes-v31/manifest.json').read_text())
    roster = json.loads((project / 'docs/hero-roster-v29.json').read_text())['heroes']
    canonical = {hero['id'] for hero in roster}
    failures = []
    reports = []
    checked_heroes = []
    for sheet in manifest['sheets']:
        key = sheet['key']
        path = project / sheet['path'].removeprefix('res://')
        regions = sheet.get('regions', [])
        pivots = sheet.get('pivots', [])
        threshold = sheet.get('alpha_threshold', 10)
        heroes = sheet['hero_ids']
        checked_heroes.extend(heroes)
        if len(heroes) != 5 or len(regions) != 20 or len(pivots) != 20:
            failures.append(f'{key}: expected five heroes and twenty declared regions/pivots')
            continue
        with Image.open(path) as image:
            if image.mode != 'RGBA':
                failures.append(f'{key}: source must contain genuine RGBA transparency')
                continue
            width, height = image.size
            alpha = image.getchannel('A')
            visible = alpha.point(lambda value: 255 if value > threshold else 0)
            coverage = Image.new('L', image.size, 0)
            overlapping_pixels = 0
            unique = set()
            frame_reports = []
            for index, (x, y, w, h) in enumerate(regions):
                label = f'{key}/{heroes[index // 4]}/{index % 4}'
                if min(x, y) < 0 or min(w, h) <= 0 or x + w > width or y + h > height:
                    failures.append(f'{label}: source region outside the PNG')
                    continue
                box = (x, y, x + w, y + h)
                active = visible.crop(box)
                pixels = active.histogram()[255]
                if pixels < 100:
                    failures.append(f'{label}: pose does not contain substantive visible artwork')
                overlap = ImageChops.multiply(active, coverage.crop(box)).histogram()[255]
                overlapping_pixels += overlap
                if overlap:
                    failures.append(f'{label}: {overlap} visible pixels are included by another pose')
                coverage.paste(255, box)
                pose_hash = hashlib.sha256(image.crop(box).tobytes()).hexdigest()
                if pose_hash in unique:
                    failures.append(f'{label}: duplicates another pose image')
                unique.add(pose_hash)
                px, py = pivots[index]
                if not (x <= px <= x + w and y <= py <= y + h):
                    failures.append(f'{label}: authored foot pivot outside its pose rectangle')
                frame_reports.append({'hero': heroes[index // 4], 'pose': index % 4,
                                      'visible_pixels': pixels, 'region': regions[index],
                                      'pivot': pivots[index], 'sha256': pose_hash})
            missing = ImageChops.subtract(visible, coverage).histogram()[255]
            total_visible = visible.histogram()[255]
            if missing:
                failures.append(f'{key}: {missing} visible pixels are omitted by all pose regions')
            if alpha.histogram()[0] == 0:
                failures.append(f'{key}: no fully transparent background pixels')
            actual_hash = hashlib.sha256(path.read_bytes()).hexdigest()
            expected_hash = sheet.get('sha256', sheet.get('source_sha256'))
            if expected_hash and actual_hash != expected_hash:
                failures.append(f'{key}: PNG differs from its provenance checksum')
            origin = Path(sheet.get('source_generated', ''))
            origin_verified = origin.is_file()
            if origin_verified and hashlib.sha256(origin.read_bytes()).hexdigest() != actual_hash:
                failures.append(f'{key}: PNG differs from the original generated image')
            reports.append({'sheet': key, 'size': [width, height], 'alpha_threshold': threshold,
                            'source_sha256': actual_hash, 'regions': len(frame_reports),
                            'source_origin_verified': origin_verified,
                            'visible_pixels': total_visible, 'omitted_visible_pixels': missing,
                            'overlapping_visible_pixels': overlapping_pixels,
                            'coverage_percent': round(100 * (total_visible - missing) / max(1, total_visible), 6),
                            'frames': frame_reports})
    if len(reports) != 6 or len(checked_heroes) != 30 or set(checked_heroes) != canonical:
        failures.append('six sheets must cover exactly the thirty canonical hero IDs')
    result = {'passed': not failures, 'inspection': 'read_only_source_alpha_and_region_geometry',
              'rendered_screenshot': False, 'failures': failures, 'sheets': reports}
    output = Path(args.output)
    if not output.is_absolute():
        output = project / output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'v31_atlas_integrity sheets={len(reports)} heroes={len(checked_heroes)} failures={len(failures)}')
    for failure in failures:
        print('FAIL ' + failure)
    return 0 if not failures else 1


if __name__ == '__main__':
    raise SystemExit(main())
