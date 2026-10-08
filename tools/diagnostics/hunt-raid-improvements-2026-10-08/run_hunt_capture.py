"""Actual native Mobile images and crowd observations, with disposable saves."""
from pathlib import Path
import subprocess,os,tempfile,json,hashlib,datetime
root=Path(__file__).resolve().parents[3]
binary=root.parent/'validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
output=root/'checks/hunt-raid-improvements-2026-10-08/spacing-native-final'
output.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(dir=root.parent/'validation',prefix='hunt-native-',ignore_cleanup_errors=True) as tmp:
    env=dict(os.environ,APPDATA=tmp,XDG_DATA_HOME=tmp,XDG_CONFIG_HOME=tmp,XDG_CACHE_HOME=tmp,GAME_AUDIT_OUTPUT=str(output))
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    p=subprocess.run([str(binary),'--path',str(root),'--rendering-method','mobile','--audio-driver','Dummy','--script','res://tools/diagnostics/hunt-raid-improvements-2026-10-08/CaptureHuntFormations.gd'],env=env,capture_output=True,text=True,encoding='utf-8',timeout=180,startupinfo=startup)
    text=p.stdout+p.stderr
    (output/'capture.log').write_text(text,encoding='utf-8')
    passed=p.returncode==0 and 'HUNT_FORMATION_CAPTURE_OK' in text and not any(x in text for x in ['SCRIPT ERROR','ERROR:','leaked at exit'])
    (output/'capture-manifest.json').write_text(json.dumps({'captured_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'passed':passed,'rendering_method':'mobile','files':{str(file.relative_to(output)):hashlib.sha256(file.read_bytes()).hexdigest() for file in sorted(output.iterdir()) if file.is_file() and file.name!='capture-manifest.json'},'sources':{path:hashlib.sha256((root/path).read_bytes()).hexdigest() for path in ['scripts/hunting/HuntBodyCollision.gd','scripts/hunting/HuntPositionPlanner.gd','scripts/hunting/PartyMovementDirector.gd','scripts/combat/BattleFormation.gd','scripts/maps3d/HeroCircleFormation.gd','scripts/maps3d/Battlefield3DView.gd']}},ensure_ascii=False,indent=2),encoding='utf-8')
    print('HUNT_FORMATION_CAPTURE_OK native_pngs=8' if passed else text[-10000:])
    raise SystemExit(0 if passed else 1)
