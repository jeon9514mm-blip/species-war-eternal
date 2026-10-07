import argparse,json,os,subprocess,tempfile
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
repo=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser();parser.add_argument('--output',default='checks/game-audit-2026-10-07/final-changed-source-parser.json');args=parser.parse_args()
binary=repo.parent/'validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
paths=set()
for git_args in [('diff','--name-only'),('diff','--cached','--name-only'),('ls-files','--others','--exclude-standard')]:
    paths.update(subprocess.check_output(['git',*git_args],cwd=repo,text=True).splitlines())
paths={p for p in paths if p.endswith('.gd') and (repo/p).is_file()};paths.add('scripts/ui/LandingScreens.gd')
with tempfile.TemporaryDirectory(prefix='art-pilot-final-parser-',ignore_cleanup_errors=True) as temp:
    env=dict(os.environ,APPDATA=temp,XDG_DATA_HOME=temp,XDG_CONFIG_HOME=temp,XDG_CACHE_HOME=temp)
    def check(path):
        p=subprocess.run([str(binary),'--headless','--path',str(repo),'--check-only','--script','res://'+path],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=60)
        return {'script':path,'passed':p.returncode==0 and 'ERROR:' not in p.stdout,'exit':p.returncode,'output':p.stdout if p.returncode or 'ERROR:' in p.stdout else ''}
    with ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(check,sorted(paths)))
    for index,row in enumerate(results):
        if not row['passed'] and 'ERROR:' not in row['output']:results[index]=dict(check(row['script']),retry_original=row)
report={'scope':'Every modified/new GDScript plus LandingScreens.gd. Unmodified scripts are outside this parser run.','passed':sum(r['passed'] for r in results),'total':len(results),'results':results}
output=repo/args.output;output.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('FINAL_CHANGED_PARSER',report['passed'],report['total']);raise SystemExit(0 if report['passed']==report['total'] else 1)
