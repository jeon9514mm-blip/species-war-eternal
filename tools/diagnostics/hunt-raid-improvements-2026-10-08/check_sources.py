"""Parse every changed/new script and tie results to the reviewed source bytes."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[3]
output = repo / 'checks/hunt-raid-improvements-2026-10-08/parser.json'
names = set(subprocess.check_output(['git', 'diff', '--name-only', '--', '*.gd'], cwd=repo).decode().splitlines())
names.update(subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '--', '*.gd'], cwd=repo).decode().splitlines())
# Keep the saved review scope when reproducing this check from a clean clone.
if output.is_file():
    names.update(row['script'] for row in json.loads(output.read_text(encoding='utf-8'))['results'])
binary = repo.parent / 'validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
rows = []
with tempfile.TemporaryDirectory(dir=repo.parent / 'validation', prefix='hunt-raid-parser-', ignore_cleanup_errors=True) as temporary:
    env = dict(os.environ, APPDATA=temporary, XDG_DATA_HOME=temporary,
               XDG_CONFIG_HOME=temporary, XDG_CACHE_HOME=temporary)
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    for name in sorted(names):
        result = subprocess.run([str(binary), '--headless', '--path', str(repo), '--check-only',
                                 '--script', 'res://' + name], env=env, capture_output=True,
                                text=True, encoding='utf-8', timeout=90, startupinfo=startup)
        text = result.stdout + result.stderr
        passed = result.returncode == 0 and not any(marker in text for marker in ['SCRIPT ERROR', 'ERROR:'])
        rows.append(dict(script=name, passed=passed, sha256=hashlib.sha256((repo/name).read_bytes()).hexdigest(),
                         output='' if passed else text))
        print(('PASS ' if passed else 'FAIL ') + name, flush=True)
report = dict(scope='Every new and changed GDScript at final review', passed=sum(row['passed'] for row in rows),
              total=len(rows), results=rows)
output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
assert report['passed'] == report['total'], json.dumps([row for row in rows if not row['passed']], ensure_ascii=False)
