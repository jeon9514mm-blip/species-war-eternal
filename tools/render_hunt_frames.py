#!/usr/bin/env python3
"""Render either enlarged complete-pose animation or actual default-scene hunting."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from render_rune_stone import display_server, ROOT

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--ffmpeg',default=os.environ.get('FFMPEG_BIN') or shutil.which('ffmpeg'),help='FFmpeg executable; also accepts FFMPEG_BIN.')
    parser.add_argument('--display');parser.add_argument('--xorg-config',type=Path)
    parser.add_argument('--live',action='store_true',help='Actual hunting; default is labelled slow pose inspection.')
    parser.add_argument('--duel',action='store_true',help='Labelled two-actor combat inspection with controlled starting positions and cooldowns.')
    args=parser.parse_args()
    if args.live and args.duel:parser.error('Choose either --live or --duel.')
    if not args.ffmpeg:parser.error('Specify --ffmpeg or install FFmpeg on PATH.')
    args.output=args.output.resolve();args.output.mkdir(parents=True,exist_ok=True)
    captures=args.output/'captures';captures.mkdir(exist_ok=True)
    env=os.environ.copy()
    with tempfile.TemporaryDirectory(prefix='hunt-whole-frames-') as tmp:
        for name,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('APPDATA','appdata'),('MAP_CAPTURE_USER_DATA','saves'),('PILOT_MOVIE_FRAMES','frames')]:
            path=Path(tmp)/folder;path.mkdir();env[name]=str(path)
        env['MAP_CAPTURE_OUTPUT']=str(captures)
        with display_server(args,env):
            script='tools/capture_hunt_duel.gd' if args.duel else ('tools/capture_hunt_frames.gd' if args.live else 'tools/review_hunt_frames.gd')
            command=[args.godot,'--path',str(ROOT),'--rendering-method','mobile','--audio-driver','Dummy','--disable-vsync','--script',script]
            if env.get('PILOT_RENDER_VERBOSE')=='1':command+=['--verbose']
            if args.display:command+=['--display-driver','x11']
            log_path=args.output/('duel-render.log' if args.duel else ('live-render.log' if args.live else 'pose-render.log'))
            startupinfo=None
            if os.name=='nt':
                startupinfo=subprocess.STARTUPINFO()
                startupinfo.dwFlags|=subprocess.STARTF_USESHOWWINDOW
                startupinfo.wShowWindow=0
            with log_path.open('w',encoding='utf-8') as log:
                subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300,check=True,startupinfo=startupinfo)
            log=log_path.read_text(encoding='utf-8',errors='replace');marker='HUNT_FRAME_DUEL_OK' if args.duel else ('HUNT_FRAME_CAPTURE_OK' if args.live else 'HUNT_FRAME_REVIEW_OK')
            if any(mark in log for mark in ['ERROR:','SCRIPT ERROR','SHADER ERROR']) or marker not in log:
                raise RuntimeError('Render failed: '+str(log_path))
        destination=captures/('combat-duel-inspection.mp4' if args.duel else ('actual-hunting.mp4' if args.live else 'whole-pose-animation.mp4'))
        subprocess.run([args.ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate','30' if args.live or args.duel else '24','-i',str(Path(env['PILOT_MOVIE_FRAMES'])/'frame-%04d.png'),'-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(destination)],check=True)
        print(marker+' '+str(destination))
if __name__=='__main__':main()
