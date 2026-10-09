"""Render-only UI review fixture. NOT Unity execution or an integration test.

Reads the repository's original portrait atlas bytes; CSS clips the same first
attack frame as HuntingMigrationReview.InspectionPortrait. Never repaints art.
Hunt actor positions and all mutable gameplay numbers are illustrative.
"""
import base64
import concurrent.futures
import json
import subprocess
import struct
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RES = ROOT / 'Unity/Assets/Game/Resources/Eternal'


def blob(path):
    p = ROOT / path
    return p.read_bytes() if p.exists() else subprocess.check_output(
        ['git', 'show', 'HEAD:' + path], cwd=ROOT)


def uri(data, mime='image/png'):
    return 'data:' + mime + ';base64,' + base64.b64encode(data).decode()


catalog = json.loads(blob('docs/hero-catalog-2026-10-08/hero-catalog.json'))
heroes = [h for h in catalog['heroes'] if h['faction'] == 'aurelia']


def actor(hero_id):
    style = RES / 'HeroStyles' / hero_id
    original = RES / 'Actors' / hero_id
    if (style / 'frames.json').exists():
        frames = (style / 'frames.json').read_bytes()
        image = (style / 'poses.png').read_bytes()
        source = str((style / 'poses.png').relative_to(ROOT))
    elif (original / 'frames.json').exists() and (original / 'poses.png').exists():
        frames = (original / 'frames.json').read_bytes()
        image = (original / 'poses.png').read_bytes()
        source = str((original / 'poses.png').relative_to(ROOT))
    else:
        source = 'assets/mobile25d/' + hero_id + '/poses_1024.png'
        frames = blob('assets/mobile25d/' + hero_id + '/frames.json')
        image = blob(source)
    return hero_id, {'uri': uri(image), 'region': json.loads(frames)['attack']['frames'][0]['region'], 'source': source, 'size': list(struct.unpack('>II', image[16:24]))}


with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    actors = dict(pool.map(actor, [h['id'] for h in heroes] + ['fallen_werewolf', 'fallen_ogre', 'fallen_lich']))
images = {name: uri((RES / path).read_bytes()) for name, path in {
    'meadow': 'Environment/Hunt/meadow-hunt-v1.png',
    'camp': 'UI/expedition-key-art.png',
    'world': 'Environment/sky-court.png',
    'raid': 'Environment/lunar-sanctum.png',
}.items()}
font = uri((RES / 'Fonts/EternalKR-Regular.ttf').read_bytes(), 'font/ttf')
template = (HERE / 'review-template.html').read_text()
payload = json.dumps({'heroes': heroes, 'actors': actors, 'images': images}, ensure_ascii=False)
(HERE / 'review-preview.html').write_text(template.replace('__FONT__', font).replace('__DATA__', payload))
(HERE / 'preview-provenance.json').write_text(json.dumps({
    'type': 'source-aligned-html-review-preview',
    'not_unity_execution_capture': True,
    'screen': [1600, 900], 'disclosure_banner': [1600, 56],
    'illustrative_only': ['gameplay numbers', 'static actor positions', 'flat environment artwork'],
    'source_files': ['HuntingMigrationReview.cs', 'HuntingHudLayout.cs', 'HuntingHeroShowcase.cs', 'HuntingInspectionChrome.cs', 'HuntingLegacyMenu.cs'],
    'actors': {k: {'source': v['source'], 'region': v['region']} for k, v in actors.items()},
}, ensure_ascii=False, indent=2))
print('Wrote', HERE / 'review-preview.html')
