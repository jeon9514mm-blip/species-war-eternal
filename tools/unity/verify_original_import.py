"""Validate original migration bytes against both ends; does not edit images or saves."""
import hashlib
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
report = json.loads((repo / 'checks/unity-migration-2026-10-08/original-import.json').read_text(encoding='utf-8'))
assert (report['heroCount'], report['skillCount'], report['actorCount']) == (30, 120, 46)
for item in report['files']:
    source = (repo / item['source']).resolve()
    destination = (repo / 'Unity' / item['destination']).resolve()
    assert source.is_relative_to(repo) and destination.is_relative_to(repo / 'Unity')
    for path in (source, destination):
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256'], path
print(f"UNITY_ORIGINAL_IMPORT_BYTES_OK: {len(report['files'])} files, 30 heroes, 120 skills, 46 actors")
