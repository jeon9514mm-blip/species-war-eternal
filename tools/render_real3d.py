#!/usr/bin/env python3
"""Capture the real 10-hero hunts and three raids with isolated player saves."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--verbose',action='store_true')
    parser.add_argument('--renderer',default='mobile',choices=['mobile','forward_plus'])
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[1]
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    # Windows GPU drivers may finish writing shader cache after the engine exits.
    with tempfile.TemporaryDirectory(prefix='wholebody-capture-',ignore_cleanup_errors=True) as tmp:
        env=os.environ.copy()
        for key in ['APPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','MAP_CAPTURE_USER_DATA']:
            path=Path(tmp)/key;path.mkdir();env[key]=str(path)
        env['MAP_CAPTURE_OUTPUT']=str(output)
        startup=None
        if os.name=='nt':
            startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
        with (output.parent/'capture.log').open('w',encoding='utf-8') as log:
            command=[str(Path(args.godot).resolve()),'--path',str(root),'--rendering-method',args.renderer,'--audio-driver','Dummy','--disable-vsync','--script','res://tools/capture_real3d.gd']
            if args.verbose:command.append('--verbose')
            subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=360,check=True,startupinfo=startup)
        text=(output.parent/'capture.log').read_text(encoding='utf-8')
        if 'REAL3D_CAPTURE_OK' not in text or any(mark in text for mark in ['ERROR:','SCRIPT ERROR','SHADER ERROR','leaked at exit']):
            raise RuntimeError('Capture did not finish cleanly; inspect capture.log')
        rows=json.loads((output/'captures.json').read_text(encoding='utf-8'))
        if len(rows)!=5 or any(row['projected_paint_overlaps'] for row in rows):
            raise RuntimeError('The five real scenes must have zero body rectangle overlaps')
        for row in rows:
            scales=row['hero_scales']
            if len(scales)!=10 or max(scales)-min(scales)>1e-6:
                raise RuntimeError('All ten heroes must have the same presentation factor: '+row['capture'])
        print('REAL3D_CAPTURE_VERIFIED '+str(output))

if __name__=='__main__':main()
