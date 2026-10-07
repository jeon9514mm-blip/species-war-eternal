#!/usr/bin/env python3
"""Render actual hunting, three raid arenas and a labeled typography sample."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
from render_rune_stone import display_server, ROOT

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--display')
    parser.add_argument('--xorg-config', type=Path)
    parser.add_argument('--renderer', choices=['mobile','forward_plus','gl_compatibility'], default='mobile')
    args = parser.parse_args()
    args.output = args.output.resolve(); args.output.mkdir(parents=True, exist_ok=True)
    captures = args.output / 'captures'; captures.mkdir(exist_ok=True)
    env = os.environ.copy()
    with tempfile.TemporaryDirectory(prefix='combat-quality-render-') as directory:
        for name, sub in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('APPDATA','appdata'),('MAP_CAPTURE_USER_DATA','saves')]:
            path = Path(directory) / sub; path.mkdir(exist_ok=True); env[name] = str(path)
        env['MAP_CAPTURE_OUTPUT'] = str(captures)
        with display_server(args, env):
            command = [args.godot, '--path', str(ROOT), '--rendering-method', args.renderer, '--audio-driver','Dummy','--disable-vsync','--script','tools/capture_combat_quality.gd']
            if args.display: command += ['--display-driver','x11']
            log_path = args.output / 'render.log'
            with log_path.open('w') as log:
                subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=300, check=True)
            log = log_path.read_text()
            if any(mark in log for mark in ['ERROR:','SCRIPT ERROR','SHADER ERROR']):
                raise RuntimeError('Godot errors: '+str(log_path))
            names = ['hunt-combat','damage-style-sample','landscape-menu','equipment-v28','equipment-v28-filtered','raid-catalog-v28'] + [zone+'-raid-'+state for zone in ['gray_meadow','forgotten_mine','moonrest_forest'] for state in ['ready','warning']]
            for name in names:
                assert 'COMBAT_QUALITY_CAPTURE '+name in log, name
                assert all((captures/(name+suffix)).is_file() for suffix in ['.png','.json']), name
            print('COMBAT_QUALITY_RENDER_OK '+str(captures))
if __name__ == '__main__':
    main()
