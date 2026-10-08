"""Actual-GPU final spec measurement followed by documented art fixtures."""
from pathlib import Path
import argparse
import os
import subprocess
import tempfile

repo=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser();parser.add_argument('--captures-only',action='store_true');parser.add_argument('--raid-only',action='store_true');parser.add_argument('--output',default='checks/final-polish-2026-10-08/review-final');args=parser.parse_args()
output=repo/args.output
output.mkdir(parents=True,exist_ok=True)
binary=repo.parent/'validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
with tempfile.TemporaryDirectory(dir=repo.parent/'validation',prefix='final-polish-',ignore_cleanup_errors=True) as temp:
    env=dict(os.environ,GAME_AUDIT_OUTPUT=str(output),APPDATA=temp,XDG_DATA_HOME=temp,XDG_CONFIG_HOME=temp,XDG_CACHE_HOME=temp)
    if args.captures_only:env['FINAL_CAPTURES_ONLY']='1'
    if args.raid_only:env['FINAL_RAID_ONLY']='1'
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    p=subprocess.run([str(binary),'--path',str(repo),'--rendering-method','mobile','--audio-driver','Dummy','--disable-vsync','--script','res://tools/diagnostics/game-audit-2026-10-07/FinalPolishReview.gd'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',timeout=240,startupinfo=startup)
(output/'capture.log').write_text(p.stdout,encoding='utf-8')
if p.returncode or 'FINAL_POLISH_REVIEW_OK' not in p.stdout or any(x in p.stdout for x in ['ERROR:','SCRIPT ERROR','leaked at exit']):
    print(p.stdout[-12000:]);raise SystemExit(1)
print('FINAL_POLISH_CAPTURES_OK' if args.captures_only else (output/'performance.json').read_text(encoding='utf-8'))
