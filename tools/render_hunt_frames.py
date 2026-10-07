#!/usr/bin/env python3
"""Render either enlarged complete-pose animation or actual default-scene hunting."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
from render_rune_stone import display_server, ROOT

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--display');parser.add_argument('--xorg-config',type=Path)
    parser.add_argument('--live',action='store_true',help='Actual hunting; default is labelled slow pose inspection.')
    args=parser.parse_args();args.output=args.output.resolve();args.output.mkdir(parents=True,exist_ok=True)
    captures=args.output/'captures';captures.mkdir(exist_ok=True)
    env=os.environ.copy()
    with tempfile.TemporaryDirectory(prefix='hunt-whole-frames-') as tmp:
        for name,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('APPDATA','appdata'),('MAP_CAPTURE_USER_DATA','saves'),('PILOT_MOVIE_FRAMES','frames')]:
            path=Path(tmp)/folder;path.mkdir();env[name]=str(path)
        env['MAP_CAPTURE_OUTPUT']=str(captures)
        with display_server(args,env):
            script='tools/capture_hunt_frames.gd' if args.live else 'tools/review_hunt_frames.gd'
            command=[args.godot,'--path',str(ROOT),'--rendering-method','mobile','--audio-driver','Dummy','--disable-vsync','--script',script]
            if env.get('PILOT_RENDER_VERBOSE')=='1':command+=['--verbose']
            if args.display:command+=['--display-driver','x11']
            log_path=args.output/('live-render.log' if args.live else 'pose-render.log')
            with log_path.open('w') as log:
                subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300,check=True)
            log=log_path.read_text();marker='HUNT_FRAME_CAPTURE_OK' if args.live else 'HUNT_FRAME_REVIEW_OK'
            if any(mark in log for mark in ['ERROR:','SCRIPT ERROR','SHADER ERROR']) or marker not in log:
                raise RuntimeError('Render failed: '+str(log_path))
        destination=captures/('actual-hunting.mp4' if args.live else 'whole-pose-animation.mp4')
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','30' if args.live else '24','-i',str(Path(env['PILOT_MOVIE_FRAMES'])/'frame-%04d.png'),'-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(destination)],check=True)
        print(marker+' '+str(destination))
if __name__=='__main__':main()
