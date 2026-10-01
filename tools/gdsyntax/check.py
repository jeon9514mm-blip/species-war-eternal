"""Offline grammar parsing, NOT the Godot parser, type checker or engine runtime.
Grammar/indenter transcribed from primary gdtoolkit source via browser (2026-10-01).
https://github.com/Scony/godot-gdscript-toolkit/tree/master/gdtoolkit/parser
"""
from pathlib import Path
import sys,json,time
from lark import Lark
from gdscript_indenter import GDScriptIndenter
here=Path(__file__).parent
parser=Lark.open(str(here/'gdscript.lark'), parser='lalr',start='start',postlex=GDScriptIndenter(),propagate_positions=True,maybe_placeholders=False,regex=True)
root=Path(sys.argv[1])
errors=[];files=sorted(root.rglob('*.gd'));t=time.monotonic()
for p in files:
    try:parser.parse(p.read_text(encoding='utf-8')+'\n')
    except Exception as e:errors.append({'file':str(p.relative_to(root)),'error':str(e)})
report={'checker':'gdtoolkit grammar / Lark (not Godot)','files':len(files),'syntax_ok':len(files)-len(errors),'errors':errors,'seconds':round(time.monotonic()-t,2),'godot_runtime_executed':False}
print(json.dumps(report,ensure_ascii=False,indent=2))
sys.exit(bool(errors))
