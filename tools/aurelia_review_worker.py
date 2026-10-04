#!/usr/bin/env python3
"""Restricted interactive worker for the authorized Aurelia visual review.

Accepts only hero IDs and fixed capture modes, never shell commands or paths.
One allowed display session can check the same drafts after visual refinements.
"""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
GODOT='/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
IDS={'leonhardt','mira','elisia','kairen','orwin','seria','astel','darius','lunea','caelum','adrien','tessa','naia','sael','odelia'}
OUT=ROOT/'checks/aurelia-anatomy-v3'
OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').touch()
env=os.environ.copy();env.update(DISPLAY=':95',VK_DRIVER_FILES='/workspace/tools/mesa/usr/share/vulkan/icd.d/lvp_icd.json',XDG_CACHE_HOME='/workspace/test-user/cache',XDG_CONFIG_HOME='/workspace/test-user/config',XDG_DATA_HOME='/workspace/test-user/art-pilot-anatomy-v3-render',AURELIA_REVIEW_OUTPUT='res://checks/aurelia-anatomy-v3/review',AURELIA_CAPTURE_OUTPUT='res://checks/aurelia-anatomy-v3/pose-sheets')
base=[GODOT,'--path',str(ROOT),'--display-driver','x11','--rendering-method','mobile','--audio-driver','Dummy','--disable-vsync']
print(json.dumps({'ready':True,'modes':['neck','neutral','stills','sheet','movie'],'scope':'15 Aurelia heroes; actual Godot viewport capture only'}),flush=True)
for line in sys.stdin:
    try:
        job=json.loads(line)
        if job=={'quit':True}:break
        if set(job)!={'heroes','mode'}:raise ValueError('Only heroes and mode accepted')
        heroes=job['heroes'];mode=job['mode']
        if not isinstance(heroes,list) or not 1<=len(heroes)<=15 or any(h not in IDS for h in heroes):raise ValueError('Unknown hero')
        if mode not in ['neck','neutral','stills','sheet','movie']:raise ValueError('Unknown fixed capture mode')
        if mode=='sheet':
            env['AURELIA_CAPTURE_IDS']=','.join(heroes)
            log=OUT/'pose-sheets.log'
            with log.open('w') as f:subprocess.run(base+['--script','tools/capture_aurelia_pose_sheets.gd'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=300,check=True)
            print(json.dumps({'complete':True,'mode':mode,'heroes':heroes}),flush=True)
            continue
        for hero in heroes:
            env['AURELIA_REVIEW_HERO']=hero
            folder=OUT/'review'/hero;folder.mkdir(parents=True,exist_ok=True)
            log=folder/(mode+'.log')
            command=base+['--script','tools/capture_aurelia_quality_review.gd']
            if mode=='neck':command+=['--','--neck']
            elif mode=='neutral':command+=['--','--neutral-only']
            elif mode=='movie':
                raw=Path('/workspace/validation/anatomy-v3/raw');raw.mkdir(parents=True,exist_ok=True)
                avi=raw/(hero+'.avi')
                command=base+['--fixed-fps','24','--write-movie',str(avi),'--script','tools/capture_aurelia_quality_review.gd','--','--movie']
            with log.open('w') as f:subprocess.run(command,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=300,check=True)
            if mode=='movie':
                subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(avi),'-vf','scale=1120:630','-c:v','libx264','-crf','22','-pix_fmt','yuv420p','-an','-movflags','+faststart',str(folder/'motion-review.mp4')],check=True,timeout=120)
            print(json.dumps({'complete':True,'hero':hero,'mode':mode,'log':str(log.relative_to(ROOT))}),flush=True)
    except Exception as error:
        print(json.dumps({'complete':False,'error':str(error)}),flush=True)
print(json.dumps({'closed':True}),flush=True)
