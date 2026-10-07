"""Isolated real-GPU benchmark, then 8 seconds of actual game recording."""
from pathlib import Path
import argparse
import os
import subprocess
import tempfile

repo=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser();parser.add_argument('--renderer',default='mobile',choices=['mobile','forward_plus']);args=parser.parse_args()
output=repo/'checks/mobile25d-spec-2026-10-07'/('review-'+args.renderer);output.mkdir(parents=True,exist_ok=True)
binary=repo.parent/'validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
with tempfile.TemporaryDirectory(prefix='mobile25d-review-',ignore_cleanup_errors=True) as temp:
    env=dict(os.environ,GAME_AUDIT_OUTPUT=str(output),APPDATA=temp,XDG_DATA_HOME=temp,XDG_CONFIG_HOME=temp,XDG_CACHE_HOME=temp)
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    proc=subprocess.run([str(binary),'--path',str(repo),'--rendering-method',args.renderer,'--audio-driver','Dummy','--disable-vsync','--script','res://tools/diagnostics/game-audit-2026-10-07/Mobile25dBenchmark.gd'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',timeout=480,startupinfo=startup)
    (output/'capture.log').write_text(proc.stdout,encoding='utf-8')
    if proc.returncode or 'MOBILE25D_BENCHMARK_OK' not in proc.stdout or any(x in proc.stdout for x in ['ERROR:','SCRIPT ERROR','leaked at exit']):
        print(proc.stdout[-10000:]);raise SystemExit(1)
ffmpeg=repo.parent/'validation/python-deps/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
subprocess.run([str(ffmpeg),'-y','-framerate','20','-i',str(output/'frames/%04d.png'),'-c:v','libx264','-preset','medium','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(output/'hunt-motion.mp4')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
print('MOBILE25D_REVIEW_OK',args.renderer)
