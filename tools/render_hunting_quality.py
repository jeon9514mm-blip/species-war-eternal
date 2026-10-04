#!/usr/bin/env python3
"""Render the fixed meadow review scene using the workspace display renderer."""
import os
from pathlib import Path
import subprocess
import time
import sys
import json

ROOT = Path('/workspace/validation/meadow-quality-02/integration') if '--integrated' in sys.argv else Path(__file__).resolve().parents[1]
WORK = Path('/workspace/validation/hunting-quality-03')
WORK.mkdir(parents=True,exist_ok=True)
env = os.environ.copy()
env.update(DISPLAY=':96',VK_DRIVER_FILES='/workspace/tools/mesa/usr/share/vulkan/icd.d/lvp_icd.json',
    XDG_CACHE_HOME='/workspace/test-user/cache',XDG_CONFIG_HOME='/workspace/test-user/config',
    XDG_DATA_HOME='/workspace/test-user/art-pilot-hunting-quality-03-render')
display_log = (WORK/'xorg.log').open('w')
display = subprocess.Popen(['Xorg',':96','-config','/workspace/validation/xorg-dummy.conf',
    '-logfile',str(WORK/'xorg-server.log'),'-nolisten','tcp','-noreset','-ac'],stdout=display_log,stderr=subprocess.STDOUT)
try:
    for attempt in range(50):
        if Path('/tmp/.X11-unix/X96').exists(): break
        if display.poll() is not None: raise RuntimeError('Review display did not start; see xorg.log')
        time.sleep(.1)
    command=['/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64','--path',str(ROOT),
        '--display-driver','x11','--rendering-method','mobile','--audio-driver','Dummy','--disable-vsync',
        '--script','tools/capture_hunting_quality.gd']
    if '--heroes' in sys.argv or '--focus' in sys.argv:
        ids=['leonhardt','mira','elisia','kairen','orwin','seria','astel','darius','lunea','caelum','adrien','tessa','naia','sael','odelia']
        if '--focus' in sys.argv: ids=['mira','elisia']
        env['AURELIA_REVIEW_OUTPUT']='res://checks/aurelia-anatomy-v3/review'
        for hero in ids:
            env['AURELIA_REVIEW_HERO']=hero
            output_folder=ROOT/'checks/aurelia-anatomy-v3/review'/hero
            output_folder.mkdir(parents=True,exist_ok=True)
            hero_command=command[:-1]+['tools/capture_aurelia_quality_review.gd','--','--neutral-only']
            with (output_folder/'neutral.log').open('w') as output:
                subprocess.run(hero_command,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=90,check=True)
            print('HERO_CAPTURE',hero,flush=True)
        for hero in ['mira','elisia']:
            env['AURELIA_REVIEW_HERO']=hero
            with (ROOT/'checks/aurelia-anatomy-v3/review'/hero/'neck.log').open('w') as output:
                subprocess.run(command[:-1]+['tools/capture_aurelia_quality_review.gd','--','--neck'],env=env,stdout=output,stderr=subprocess.STDOUT,timeout=90,check=True)
            print('NECK_CAPTURE',hero,flush=True)
    else:
        with (ROOT/'checks/hunting-quality-03/render.log').open('w') as output:
            result=subprocess.run(command,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=300)
        print('hunting review exit',result.returncode,flush=True)
        if result.returncode: raise RuntimeError('Capture failed; see checks/hunting-quality-03/render.log')

finally:
    display.terminate()
    try: display.wait(timeout=5)
    except subprocess.TimeoutExpired: display.kill()
    display_log.close()
