#!/usr/bin/env python3
"""Audit (default) or enable VIBRATE in an EXISTING Godot Android export preset.
Does not create presets/package IDs/signing credentials, install SDKs or export APKs.
Usage: python tools/configure_android_haptics.py --preset Android [--enable]
"""
import argparse,configparser,json
from pathlib import Path

def configure(path: Path, preset: str, enable: bool=False) -> dict:
    if not path.is_file(): return {'ok':False,'reason':'No export_presets.cfg; configure Android export in Godot first.'}
    config=configparser.ConfigParser(interpolation=None,strict=True);config.optionxform=str
    try:config.read_string(path.read_text(encoding='utf-8'))
    except (OSError,configparser.Error) as e:return {'ok':False,'reason':str(e)}
    sections=[s for s in config.sections() if s.startswith('preset.') and not s.endswith('.options') and config.get(s,'platform',fallback='').strip('"')=='Android' and config.get(s,'name',fallback='').strip('"')==preset]
    if len(sections)!=1:return {'ok':False,'reason':'Expected exactly one Android preset with the requested name.'}
    section=sections[0]+'.options'
    if not config.has_section(section):config.add_section(section)
    active=config.get(section,'permissions/vibrate',fallback='false').strip().lower()=='true'
    if active:return {'ok':True,'changed':False,'permission':'VIBRATE enabled'}
    if not enable:return {'ok':False,'reason':'VIBRATE permission missing; use --enable to update this preset.'}
    text=path.read_text(encoding='utf-8');lines=text.splitlines(keepends=True)
    # Preserve all unknown Godot types, resource syntax and formatting verbatim.
    import re
    match=re.search(r'(?m)^\['+re.escape(section)+r'\]\s*$',text)
    if match:
        end=re.search(r'(?m)^\[',text[match.end():]);end_index=match.end()+end.start() if end else len(text)
        body=text[match.end():end_index]
        if re.search(r'(?m)^permissions/vibrate\s*=',body):body=re.sub(r'(?m)^permissions/vibrate\s*=.*$','permissions/vibrate=true',body)
        else:body='\npermissions/vibrate=true\n'+body
        changed=text[:match.end()]+body+text[end_index:]
    else:changed=text+'\n['+section+']\npermissions/vibrate=true\n'
    backup=path.with_suffix(path.suffix+'.v82.bak');backup.write_bytes(path.read_bytes())
    tmp=path.with_suffix(path.suffix+'.tmp');tmp.write_text(changed,encoding='utf-8');tmp.replace(path)
    return {'ok':True,'changed':True,'backup':str(backup),'permission':'VIBRATE enabled; device test still required'}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--preset',required=True);p.add_argument('--enable',action='store_true');p.add_argument('--file',type=Path,default=Path(__file__).resolve().parents[1]/'export_presets.cfg');a=p.parse_args()
    result=configure(a.file,a.preset,a.enable);print(json.dumps(result,ensure_ascii=False));return 0 if result['ok'] else 2
if __name__=='__main__':raise SystemExit(main())
