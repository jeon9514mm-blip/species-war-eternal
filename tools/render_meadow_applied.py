#!/usr/bin/env python3
"""Run actual Godot screenshots; requires a local X11 socket."""
import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[1]
work = root / 'checks/rune-stone-applied'
if os.environ.get('MAP_CAPTURE_RENDERER') == 'forward_plus': work = work / 'forward-plus'
work.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(DISPLAY=':96', VK_DRIVER_FILES='/workspace/tools/mesa/usr/share/vulkan/icd.d/lvp_icd.json',
           XDG_CACHE_HOME='/workspace/test-user/cache', XDG_CONFIG_HOME='/workspace/test-user/config',
           XDG_DATA_HOME='/workspace/test-user/art-pilot-map-ultra-render-'+str(time.time_ns()))
with (work / 'xorg.log').open('w') as xlog:
    display = subprocess.Popen(['Xorg', ':96', '-config', '/workspace/validation/xorg-dummy.conf',
                                '-logfile', str(work / 'xorg-server.log'), '-nolisten', 'tcp', '-noreset', '-ac'],
                               stdout=xlog, stderr=subprocess.STDOUT)
    try:
        for attempt in range(50):
            if Path('/tmp/.X11-unix/X96').exists(): break
            if display.poll() is not None: raise RuntimeError('Display failed; see xorg.log')
            time.sleep(.1)
        command = ['/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64', '--path', str(root),
                   '--display-driver', 'x11', '--rendering-method', env.get('MAP_CAPTURE_RENDERER','mobile'), '--audio-driver', 'Dummy',
                   '--disable-vsync', '--script', 'tools/capture_meadow_applied.gd']
        if env.get('MAP_CAPTURE_VERBOSE') == '1': command.append('--verbose')
        label = env.get('MAP_CAPTURE_ZONE','all') + '-' + env.get('MAP_CAPTURE_RENDERER','mobile')
        with (work / ('render-' + label + '.log')).open('w') as output:
            subprocess.run(command, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=480, check=True)
        log=(work / ('render-' + label + '.log')).read_text()
        if 'ERROR:' in log or 'SHADER ERROR' in log or 'SCRIPT ERROR' in log: raise RuntimeError('Godot capture reported errors: '+str(work / ('render-' + label + '.log')))
        print('RUNE_STONE_RENDER_OK', flush=True)
    finally:
        display.terminate()
        try: display.wait(timeout=5)
        except subprocess.TimeoutExpired: display.kill()
