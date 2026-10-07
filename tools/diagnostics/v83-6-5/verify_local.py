import concurrent.futures,json,os,subprocess,pathlib
root=pathlib.Path('/workspace/species-war-eternal')
out=pathlib.Path('/workspace/validation/map-art')
binary='/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
env=dict(os.environ,XDG_CACHE_HOME='/workspace/test-user/cache',XDG_CONFIG_HOME='/workspace/test-user/config')
def run_script(path,check=False):
 data=out/'isolated'/path.stem;data.mkdir(parents=True,exist_ok=True)
 command=[binary,'--headless','--path',str(root)]
 if check:command+=['--check-only']
 command+=['--script','res://'+str(path.relative_to(root))]
 p=subprocess.run(command,cwd=root,env=dict(env,XDG_DATA_HOME=str(data)),capture_output=True,text=True,timeout=180)
 s=p.stdout+p.stderr
 return {'script':str(path.relative_to(root)),'passed':p.returncode==0 and 'ERROR:' not in s and 'SCRIPT ERROR' not in s,'output':s if not check or p.returncode or 'ERROR:' in s else ''}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 syntax=list(pool.map(lambda p:run_script(p,True),sorted(root.rglob('*.gd'))))
 print('compile',sum(x['passed'] for x in syntax),'/',len(syntax),flush=True)
 names=['V8364CombatViewSmokeTest.gd','V8363IceMapSmokeTest.gd','V8363MapLoaderSmokeTest.gd','V8362LayoutSmokeTest.gd','V836RaidBattleSmokeTest.gd']
 tests=list(pool.map(lambda n:run_script(root/'scripts'/n),names))
for t in tests:print(t['script'],t['passed'],t['output'],flush=True)
report={'engine':'4.7.2.stable.official.ed1daf0bf','execution':'Headless runtime and check-only; editor importer blocked by sandbox TCP restriction; existing imported resources reused.','syntax':syntax,'tests':tests}
(out/'local-regression.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print('TOTAL',sum(t['passed'] for t in tests),'/',len(tests),flush=True)
raise SystemExit(0 if all(t['passed'] for t in syntax+tests) else 1)
