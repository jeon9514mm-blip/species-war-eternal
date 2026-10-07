#!/usr/bin/env python3
"""Read-only current architecture contracts. --historical-v82 audits the original
refactor snapshot, not later gameplay releases. Does not replace runtime tests.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import re
import sys
ROOT = Path(__file__).resolve().parents[1]
TOKENS = re.compile(r'(?P<string>"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')|(?P<comment>\#[^\n]*)|(?P<id>\b[A-Za-z_]\w*\b)|(?P<other>.)', re.S)

def functions(text: str) -> dict[str, tuple[str, str]]:
    result = {}
    for match in re.finditer(r'^(?:static )?func (\w+)\([^\n]*\)[^\n]*:\n', text, re.M):
        end = re.search(r'^(?![#\s]).+', text[match.end():], re.M)
        body = text[match.end():match.end()+end.start() if end else len(text)]
        result[match[1]] = (match[0].strip(), body)
    return result

def canonical(body: str, owner: bool = False) -> str:
    tokens = [(m.lastgroup, m[0]) for m in TOKENS.finditer(body)
              if m.lastgroup != 'comment' and not m[0].isspace()]
    out = []
    i = 0
    while i < len(tokens):
        kind, value = tokens[i]
        if kind == 'other' and value == ':' and i + 1 < len(tokens) and tokens[i+1][1] == '=':
            i += 1
            continue  # := inference vs = dynamic declarations, not expression changes
        if owner and kind == 'id' and value == 'main':
            if i + 1 < len(tokens) and tokens[i+1][1] == '.':
                i += 2
                continue  # explicit owner qualification replaces implicit member lookup
            value = 'self'
        out.append(value)
        i += 1
    return hashlib.sha256('\x1f'.join(out).encode()).hexdigest()

def verify_historical_v82(root: Path) -> dict:
    manifest = json.loads((root/'tools/v83_extraction_map.json').read_text())
    current = functions((root/'scripts/app/Main.gd').read_text())
    errors: list[str] = []
    modules = {}
    for item in manifest['methods']:
        module = item['module']
        if module not in modules:
            text = (root/manifest['service_module_paths'][module]).read_text()
            modules[module] = functions(text)
            if re.search(r'^var\s+', text, re.M):
                errors.append(f'{module}: service must not keep duplicate mutable state/host')
        method = item['method']
        body = modules[module].get(item['entrypoint'], ('', ''))[1]
        if canonical(body, owner=True) != item['base_normalized_sha256']:
            errors.append(f'{method}: extracted body drifted from characterized v82 rules')
        facade = current.get(method, ('', ''))
        if facade[0] != item['facade_signature'] or canonical(facade[1]) != item['facade_body_sha256']:
            errors.append(f'{method}: original command signature/delegation changed')
    for method, expected in manifest['untouched_functions'].items():
        actual = current.get(method)
        if actual is None or canonical(actual[0]+'\n'+actual[1]) != expected:
            errors.append(f'{method}: non-extracted function changed')
    for rel, sha in manifest['protected_file_hashes'].items():
        path = root/rel
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != sha:
            errors.append(f'{rel}: protected gameplay/save/asset file changed')
    for rel in ['scripts/portrait/PortraitHud.gd','scripts/portrait/PortraitMain.gd','scripts/ui/UiChrome.gd']:
        text = (root/rel).read_text()
        if 'res://scripts/ui/NavigationCatalog.gd' not in text:
            errors.append(f'{rel}: missing shared navigation source')
    result = {'ok': not errors, 'errors': errors, 'extracted_methods': len(manifest['methods']),
              'service_modules': len(modules), 'unchanged_main_functions': len(manifest['untouched_functions']),
              'protected_files': len(manifest['protected_file_hashes']),
              'scope': 'static token and file checks; not runtime or performance proof'}
    return result

def verify(root: Path) -> dict:
    """Current structural contracts; v82 immutability is explicitly historical."""
    manifest = json.loads((root/'tools/v83_extraction_map.json').read_text())
    main_text = (root/'scripts/app/Main.gd').read_text()
    current = functions(main_text)
    contract = manifest['current_contract']
    errors = []
    modules = {}
    for item in manifest['methods']:
        module = item['module']
        if module not in modules:
            text = (root/manifest['service_module_paths'][module]).read_text()
            modules[module] = functions(text)
            if re.search(r'^var\s+', text, re.M):
                errors.append(f'{module}: service must not own mutable game state')
        if item['entrypoint'] not in modules[module]:
            errors.append(f'{module}: missing {item["entrypoint"]}')
        facade = current.get(item['method'], ('', ''))
        expected_body = contract['facade_overrides'].get(item['method'], item)['facade_body_sha256']
        if facade[0] != item['facade_signature'] or canonical(facade[1]) != expected_body:
            errors.append(f'{item["method"]}: compatibility facade changed')
    field = (root/'scripts/hunting/HuntFieldService.gd').read_text()
    if re.search(r'^var\s+', field, re.M):
        errors.append('HuntFieldService must not duplicate host state')
    for name in ['spawn_enemy_wave','advance_roaming_hunt','advance_auto_hunt_step','finish_hunt_target']:
        if name not in functions(field) or f'_FIELD.{name}(self' not in current.get('_'+name, ('',''))[1]:
            errors.append(f'{name}: field orchestration delegation missing')
    if 'preload("res://scripts/maps/ZoneCatalog.gd").all()' not in current.get('_zone_data', ('',''))[1]:
        errors.append('zone data must use canonical catalog')
    equipment = (root/'scripts/equipment/EquipmentRules.gd').read_text()
    for name in ['MEADOW_NAME','MINE_NAME','FOREST_NAME']:
        if f'ZoneCatalog.gd").{name}' not in equipment:
            errors.append(f'equipment zone lacks canonical {name}')
    if len(main_text.splitlines()) > contract['main_line_budget']:
        errors.append('Main grew beyond the recorded shipped orchestration budget')
    for rel in ['scripts/portrait/PortraitHud.gd','scripts/portrait/PortraitMain.gd','scripts/ui/UiChrome.gd']:
        if 'res://scripts/ui/NavigationCatalog.gd' not in (root/rel).read_text():
            errors.append(f'{rel}: missing shared navigation source')
    return {'ok': not errors, 'errors': errors, 'service_modules': len(modules)+1,
            'current_contract_source_commit': contract['source_commit'],
            'current_facade_adjustments': list(contract['facade_overrides']),
            'main_line_budget': contract['main_line_budget'],
            'scope': 'current facade, state ownership, field extraction and canonical naming; runtime suite validates behavior',
            'historical_check': '--historical-v82 checks original v82 fingerprints and is expected to differ after feature changes'}

def main() -> int:
    try:
        result = verify_historical_v82(ROOT) if "--historical-v82" in sys.argv else verify(ROOT)
    except (OSError, ValueError, KeyError) as exc:
        print(json.dumps({'ok':False,'error':str(exc)}))
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['ok'] else 1
if __name__ == '__main__':
    sys.exit(main())
