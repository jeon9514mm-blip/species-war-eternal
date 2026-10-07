#!/usr/bin/env python3
"""Lightweight project checks that do not require the Godot executable."""
from __future__ import annotations

import re
import sys
from pathlib import Path
from project_paths import regression_tests, source_scripts

ROOT = Path(__file__).resolve().parents[1]


def bracket_errors(path: Path, text: str) -> list[str]:
    errors: list[str] = []
    stack: list[tuple[str, int]] = []
    pairs = {')': '(', ']': '[', '}': '{'}
    quote: str | None = None
    escaped = False
    line = 1
    index = 0
    while index < len(text):
        ch = text[index]
        if quote is not None:
            if escaped:
                escaped = False
            elif ch == '\\':
                escaped = True
            elif ch == quote:
                quote = None
            if ch == '\n':
                line += 1
            index += 1
            continue
        if ch in ('"', "'"):
            quote = ch
            index += 1
            continue
        if ch == '#':
            newline = text.find('\n', index)
            if newline == -1:
                break
            index = newline
            continue
        if ch == '\n':
            line += 1
        if ch in '([{':
            stack.append((ch, line))
        elif ch in ')]}':
            if not stack or stack[-1][0] != pairs[ch]:
                errors.append(f'{path.relative_to(ROOT)}:{line}: bracket mismatch')
                return errors
            stack.pop()
        index += 1
    if stack:
        opener, opener_line = stack[-1]
        errors.append(f'{path.relative_to(ROOT)}:{opener_line}: unclosed {opener}')
    return errors


def extends_scene_tree(path: Path, seen: set[Path] | None = None) -> bool:
    """Resolve local test inheritance without accepting other base classes or cycles."""
    path = path.resolve()
    seen = set() if seen is None else seen
    if path in seen or not path.is_relative_to(ROOT) or not path.is_file():
        return False
    seen.add(path)
    text = path.read_text(encoding='utf-8')
    if re.search(r'^extends\s+SceneTree\s*$', text, re.MULTILINE):
        return True
    parent = re.search(r'''^extends\s+(["'])res://([^"'\n]+)\1\s*$''', text, re.MULTILINE)
    return bool(parent) and extends_scene_tree(ROOT / parent.group(2), seen)


def local_private_calls(text: str) -> set[str]:
    """Only unqualified/self calls belong to Main, not SERVICE._method().

    External method existence is validated by the real Godot compile pass.
    Keep checking missing local and explicit-self calls rather than ignoring
    every underscore method after modularization.
    """
    unqualified = set(re.findall(r'(?<![A-Za-z0-9_.])(_[A-Za-z0-9_]+)\s*\(', text))
    self_calls = set(re.findall(r'\bself\.(_[A-Za-z0-9_]+)\s*\(', text))
    return unqualified | self_calls


def main() -> int:
    errors: list[str] = []
    gd_files = source_scripts(ROOT)
    for path in gd_files:
        text = path.read_text(encoding='utf-8')
        funcs = re.findall(r'^func\s+([A-Za-z0-9_]+)\s*\(', text, re.MULTILINE)
        duplicates = sorted({name for name in funcs if funcs.count(name) > 1})
        if duplicates:
            errors.append(f'{path.relative_to(ROOT)}: duplicate functions {duplicates}')
        for lineno, line in enumerate(text.splitlines(), 1):
            if line.startswith('\\t'):
                errors.append(f'{path.relative_to(ROOT)}:{lineno}: literal \\t used as indentation')
        errors.extend(bracket_errors(path, text))

    resource_pattern = re.compile(r'''(["'])res://([^"'\n]+)\1''')
    for path in (ROOT / 'scripts').glob('*.gd'):
        errors.append(f'{path.relative_to(ROOT)}: runtime scripts belong in a domain directory')
    for path in [*gd_files, *ROOT.rglob('*.tscn'), *ROOT.rglob('*.tres')]:
        text = path.read_text(encoding='utf-8', errors='ignore')
        for _quote, rel in resource_pattern.findall(text):
            rel = rel.split('::', 1)[0]
            if path.is_relative_to(ROOT / 'scripts') and rel.startswith('tests/'):
                errors.append(f'{path.relative_to(ROOT)}: runtime resource depends on test code: {rel}')
            # Format/template resource paths are resolved at runtime, not literal files.
            if '%' in rel or '{' in rel or '}' in rel:
                continue
            # Capture tools create these report destinations at runtime; they
            # are not packaged resources or a prerequisite to launching Godot.
            if rel.startswith('checks/'):
                continue
            # A directory/prefix literal is assembled with its filename at
            # runtime. The resulting resources are checked by the engine.
            if not Path(rel).suffix:
                continue
            if not (ROOT / rel).exists():
                errors.append(f'{path.relative_to(ROOT)}: missing res://{rel}')

    tests = regression_tests(ROOT)
    if not tests:
        errors.append('tests/regression: no executable regression scripts found')
    for path in tests:
        if not extends_scene_tree(path):
            errors.append(f'{path.relative_to(ROOT)}: smoke test must extend SceneTree')

    readme = (ROOT / 'README.md').read_text(encoding='utf-8')
    for rel in re.findall(r'\[[^\]]+\]\(([^)]+)\)', readme):
        if '://' in rel or rel.startswith('#'):
            continue
        if not (ROOT / rel).exists():
            errors.append(f'README.md: missing linked file {rel}')

    main_script = (ROOT / 'scripts/app/Main.gd').read_text(encoding='utf-8')
    definitions = set(re.findall(r'^func\s+(_[A-Za-z0-9_]+)\s*\(', main_script, re.MULTILINE))
    calls = local_private_calls(main_script)
    for name in sorted(calls - definitions):
        errors.append(f'scripts/app/Main.gd: private function call has no definition: {name}')

    if errors:
        print(f'STATIC VALIDATION FAILED ({len(errors)} issue(s))')
        for error in errors:
            print(' -', error)
        return 1

    smoke_count = len(tests)
    print(f'STATIC VALIDATION OK | gd={len(gd_files)} smoke={smoke_count} resources=ok links=ok')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
