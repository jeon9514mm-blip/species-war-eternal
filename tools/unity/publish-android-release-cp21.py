"""Verify exact signed APK parts, then publish that APK from GitHub Actions."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
PARTS = ROOT / 'releases/android/cp21'
OUTPUT = ROOT / 'Unity/Builds/Android/EternalUnity-0.1.21-arm64.apk'
REPOSITORY = 'jeon9514mm-blip/species-war-eternal'
BRANCH = 'jeon9514mm-blip/species-war-eternal'
TAG = 'android-v0.1.21-cp21'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def prepare(source):
    data = Path(source).read_bytes()
    PARTS.mkdir(parents=True, exist_ok=True)
    rows = []
    for i, offset in enumerate(range(0, len(data), 36_000_000), 1):
        content = data[offset:offset + 36_000_000]
        name = f'EternalUnity-0.1.21-arm64.apk.part{i:02d}'
        (PARTS / name).write_bytes(content)
        rows.append({'file': name, 'bytes': len(content), 'sha256': digest(content)})
    manifest = {'file': OUTPUT.name, 'bytes': len(data), 'sha256': digest(data), 'parts': rows,
                'release_tag': TAG, 'package': 'com.specieswar.eternal', 'version': '0.1.21',
                'signing': 'Android debug signing for sideload tests', 'device_run_verified': False}
    (PARTS / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest))

def reconstruct():
    manifest = json.loads((PARTS / 'manifest.json').read_text(encoding='utf-8'))
    assert manifest['file'] == OUTPUT.name and manifest['release_tag'] == TAG
    content = bytearray()
    for row in manifest['parts']:
        assert re.fullmatch(r'EternalUnity-0\.1\.21-arm64\.apk\.part\d{2}', row['file'])
        data = (PARTS / row['file']).read_bytes()
        assert len(data) == row['bytes'] and digest(data) == row['sha256'], 'APK part mismatch'
        content.extend(data)
    assert len(content) == manifest['bytes'] and digest(content) == manifest['sha256'], 'APK mismatch'
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(content)
    print(json.dumps({'reconstructed': True, 'bytes': len(content), 'sha256': digest(content)}))
    return manifest

def make_zip():
    manifest = json.loads((PARTS / 'manifest.json').read_text(encoding='utf-8'))
    data = OUTPUT.read_bytes()
    assert len(data) == manifest['bytes'] and digest(data) == manifest['sha256']
    archive = OUTPUT.with_suffix('.zip')
    # Fixed entry metadata makes the local and CI archive byte-identical.
    entry = zipfile.ZipInfo(OUTPUT.name, date_time=(1980, 1, 1, 0, 0, 0))
    with zipfile.ZipFile(archive, 'w') as package:
        package.writestr(entry, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=6)
    with zipfile.ZipFile(archive) as package:
        assert package.namelist() == [OUTPUT.name] and package.testzip() is None
        assert digest(package.read(OUTPUT.name)) == manifest['sha256']
    result = {'file': archive.name, 'bytes': archive.stat().st_size,
              'sha256': digest(archive.read_bytes()), 'contained_apk_sha256': manifest['sha256'],
              'zip_crc_passed': True, 'original_signed_apk_preserved': True}
    print(json.dumps(result))
    return archive, result

def publish():
    manifest = reconstruct()
    archive, zip_manifest = make_zip()
    assert os.environ.get('GITHUB_ACTIONS') == 'true', 'Publication runs in GitHub Actions only'
    assert os.environ.get('GITHUB_REPOSITORY') == REPOSITORY
    assert os.environ.get('GITHUB_REF') == 'refs/heads/' + BRANCH
    sha = os.environ['GITHUB_SHA']
    assert re.fullmatch('[0-9a-f]{40}', sha)
    token = os.environ['GITHUB_TOKEN']

    def request(url, method='GET', payload=None, binary=False, content_type='application/vnd.android.package-archive'):
        body = payload if binary else (json.dumps(payload).encode() if payload is not None else None)
        headers = {'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
                   'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'SpeciesWar-APK-CP21'}
        if body is not None:
            headers['Content-Type'] = content_type if binary else 'application/json'
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        with urllib.request.urlopen(req, timeout=240) as response:
            return json.load(response)

    api = 'https://api.github.com/repos/' + REPOSITORY
    try:
        release = request(api + '/releases/tags/' + TAG)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        release = request(api + '/releases', 'POST', {
            'tag_name': TAG, 'target_commitish': sha, 'name': '종의전쟁 Unity Android APK 0.1.21 · CP21',
            'body': 'Android 8.0+ / ARM64 테스트 APK. 기본 디버그 서명. 현재 왕립 UI·기능 이식·첨부 3D 사냥터 적용본. 사냥 AI는 수정 전 상태입니다. 서명·ZIP CRC·16KB ELF 정렬 검수 완료. 실제 Android 기기 플레이는 아직 검수하지 않았습니다.\n\nSHA-256: `' + manifest['sha256'] + '`',
            'draft': False, 'prerelease': True})
    for file, metadata, mime in [(OUTPUT, manifest, 'application/vnd.android.package-archive'),
                                 (archive, zip_manifest, 'application/zip')]:
        existing = next((a for a in release['assets'] if a['name'] == metadata['file']), None)
        if existing:
            assert existing['size'] == metadata['bytes'] and existing.get('digest') == 'sha256:' + metadata['sha256'], 'Existing release asset differs; refusing to replace it'
            asset = existing
        else:
            upload = release['upload_url'].split('{', 1)[0] + '?name=' + metadata['file']
            assert upload.startswith('https://uploads.github.com/repos/' + REPOSITORY + '/releases/')
            asset = request(upload, 'POST', file.read_bytes(), binary=True, content_type=mime)
            assert asset['size'] == metadata['bytes']
            assert asset.get('digest') == 'sha256:' + metadata['sha256'], 'Uploaded asset digest mismatch'
        print(json.dumps({'release': release['html_url'], 'download': asset['browser_download_url'], 'bytes': asset['size'], 'digest': asset.get('digest')}))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['prepare', 'reconstruct', 'zip', 'publish'])
    parser.add_argument('source', nargs='?', default=str(OUTPUT))
    args = parser.parse_args()
    if args.mode == 'prepare':
        prepare(args.source)
    elif args.mode == 'reconstruct':
        reconstruct()
    elif args.mode == 'zip':
        make_zip()
    else:
        publish()
