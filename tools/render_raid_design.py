#!/usr/bin/env python3
"""Capture the actual Godot raid view with a local software display."""
import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[1]
work = root / 'checks/raid-quality-01'
work.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(DISPLAY=':96', VK_DRIVER_FILES='/workspace/tools/mesa/usr/share/vulkan/icd.d/lvp_icd.json',
           XDG_CACHE_HOME='/workspace/test-user/cache', XDG_CONFIG_HOME='/workspace/test-user/config',
           XDG_DATA_HOME='/workspace/test-user/art-pilot-raid-design-render')
with (work / 'xorg.log').open('w') as xlog:
    display = subprocess.Popen(['Xorg', ':96', '-config', '/workspace/validation/xorg-dummy.conf',
                                '-logfile', str(work / 'xorg-server.log'), '-nolisten', 'tcp', '-noreset', '-ac'],
                               stdout=xlog, stderr=subprocess.STDOUT)
    try:
        for attempt in range(50):
            if Path('/tmp/.X11-unix/X96').exists():
                break
            if display.poll() is not None:
                raise RuntimeError('Display could not start; see xorg.log')
            time.sleep(.1)
        command = ['/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64', '--path', str(root),
                   '--display-driver', 'x11', '--rendering-method', 'mobile', '--audio-driver', 'Dummy',
                   '--disable-vsync', '--script', 'tools/capture_raid_design.gd']
        with (work / 'render.log').open('w') as output:
            subprocess.run(command, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=240, check=True)
        print('RAID_DESIGN_RENDER_OK', flush=True)
    finally:
        display.terminate()
        try:
            display.wait(timeout=5)
        except subprocess.TimeoutExpired:
            display.kill()
