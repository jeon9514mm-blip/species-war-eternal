#!/usr/bin/env python3
"""Record real Godot cutout poses and motion; requires an allowed X11 display.

The PNGs are Godot viewport captures, never synthetic image composites.
--prepare validates the sixteen-pose scenes headlessly without claiming renders.
"""
import argparse
import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IDS = ['mira', 'elisia', 'kairen', 'orwin', 'seria', 'astel', 'darius',
       'lunea', 'caelum', 'adrien', 'tessa', 'naia', 'sael', 'odelia']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')
    parser.add_argument('--heroes', default=','.join(IDS))
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--stills-only', action='store_true')
    args = parser.parse_args()
    heroes = args.heroes.split(',')
    if not heroes or any(hero not in IDS for hero in heroes): parser.error('Unknown expansion hero')
    out = ROOT / 'checks/aurelia-roster-parts'
    out.mkdir(parents=True, exist_ok=True)
    (out / '.gdignore').touch()
    env = os.environ.copy()
    env.update(XDG_CACHE_HOME='/workspace/test-user/cache',
               XDG_CONFIG_HOME='/workspace/test-user/config',
               XDG_DATA_HOME='/workspace/test-user/art-pilot-roster-render',
               AURELIA_CAPTURE_IDS=','.join(heroes),
               AURELIA_CAPTURE_OUTPUT='res://checks/aurelia-roster-parts/pose-sheets')
    common = [args.godot, '--path', str(ROOT)]
    if args.prepare:
        env['AURELIA_CAPTURE_PREPARE'] = '1'
        with (out / 'prepare.log').open('w') as log:
            subprocess.run(common + ['--headless', '--script', 'tools/capture_aurelia_pose_sheets.gd'], env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
        return
    env.pop('AURELIA_CAPTURE_PREPARE', None)
    env.setdefault('DISPLAY', ':95')
    env.setdefault('VK_DRIVER_FILES', '/workspace/tools/mesa/usr/share/vulkan/icd.d/lvp_icd.json')
    display = common + ['--display-driver', 'x11', '--rendering-method', 'mobile', '--audio-driver', 'Dummy', '--disable-vsync']
    result = {'renderer': 'actual_Godot_4.7.2_viewports', 'logical_size': [1280, 720],
              'reviewed': False, 'heroes': [], 'motion_recording_fps': 24,
              'scope': 'Source-timed cutout prototypes; recording rate is not measured device FPS.'}
    raw = Path('/workspace/validation/aurelia-roster-parts/raw')
    raw.mkdir(parents=True, exist_ok=True)
    for hero in heroes:
        env['AURELIA_REVIEW_HERO'] = hero
        folder = out / 'review' / hero
        folder.mkdir(parents=True, exist_ok=True)
        with (folder / 'capture.log').open('w') as log:
            subprocess.run(display + ['--script', 'tools/capture_aurelia_quality_review.gd'], env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
        assert (folder / 'neutral.png').is_file() and (folder / 'attack_1-48.png').is_file()
        print(hero, 'actual stills captured', flush=True)
        if not args.stills_only:
            avi = raw / (hero + '.avi')
            with (folder / 'movie.log').open('w') as log:
                subprocess.run(display + ['--fixed-fps', '24', '--write-movie', str(avi), '--script', 'tools/capture_aurelia_quality_review.gd', '--', '--movie'], env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
            # Standard footage transcoding; never substitutes for the rig render.
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(avi), '-vf', 'scale=1120:630', '-c:v', 'libx264', '-crf', '22', '-pix_fmt', 'yuv420p', '-an', '-movflags', '+faststart', str(folder / 'motion-review.mp4')], check=True)
            print(hero, 'actual motion recorded', flush=True)
        result['heroes'].append({'hero_id': hero, 'stills': True, 'movie': not args.stills_only})
        (out / 'render-summary.json').write_text(json.dumps(result, indent=2) + '\n')
    with (out / 'pose-sheets.log').open('w') as log:
        subprocess.run(display + ['--script', 'tools/capture_aurelia_pose_sheets.gd'], env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    summary = json.loads((out / 'pose-sheets/capture-summary.json').read_text())
    assert summary['heroes'] == len(heroes) and not summary['prepare_only'] and not summary['failures']
    print('actual16-pose sheets captured:', len(heroes), flush=True)


if __name__ == '__main__':
    main()
