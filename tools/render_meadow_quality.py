#!/usr/bin/env python3
"""Render the fixed meadow review scene using the workspace display renderer."""
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
WORK = Path('/workspace/validation/meadow-quality-02')
WORK.mkdir(parents=True,exist_ok=True)
env = os.environ.copy()
env.update(DISPLAY=':96',VK_DRIVER_FILES='/workspace/tools/mesa/usr/share/vulkan/icd.d/lvp_icd.json',
    XDG_CACHE_HOME='/workspace/test-user/cache',XDG_CONFIG_HOME='/workspace/test-user/config',
    XDG_DATA_HOME='/workspace/test-user/art-pilot-meadow-quality-02-render')
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
        '--script','tools/capture_meadow_quality.gd']
    with (ROOT/'checks/meadow-quality-02/render.log').open('w') as output:
        result=subprocess.run(command,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=180)
    print('meadow review exit',result.returncode,flush=True)
    if result.returncode: raise RuntimeError('Capture failed; see checks/meadow-quality-02/render.log')
finally:
    display.terminate()
    try: display.wait(timeout=5)
    except subprocess.TimeoutExpired: display.kill()
    display_log.close()
