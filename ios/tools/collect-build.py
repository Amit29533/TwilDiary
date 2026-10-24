"""Verify downloaded passed CI artifacts before preparing reviewable screenshot evidence.

Download into INPUT/{results,screenshots,ipa}, and save gh run view JSON as INPUT/run.json.
This verifies automated evidence, never claims visual or physical-device acceptance.
"""
import argparse
import hashlib
import json
import plistlib
import re
import shutil
import struct
import zipfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('input', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--build', required=True)
args = parser.parse_args()
run = json.loads((args.input / 'run.json').read_text(encoding='utf-8'))
if run.get('status') != 'completed' or run.get('conclusion') != 'success':
    raise SystemExit('Refusing accepted evidence: the full GitHub Actions run did not pass.')
logs = args.input / 'results' / 'logs'
text = (logs / 'tests.log').read_text(encoding='utf-8', errors='replace')
if '** TEST EXECUTE SUCCEEDED **' not in text or re.search(r"Test Case .* failed", text):
    raise SystemExit('Native unit/UI tests did not complete successfully.')
core = (logs / 'core-tests.log').read_text(encoding='utf-8', errors='replace')
core_count = re.search(r'Test run with (\d+) tests .* passed', core)
if not core_count:
    raise SystemExit('Core tests have no complete passing summary.')
for name in ['simulator-build.log', 'device-build.log', 'core-tests.log']:
    value = (logs / name).read_text(encoding='utf-8', errors='replace')
    if re.search(r'\bwarning:', value, re.I):
        raise SystemExit('Build warnings are present in ' + name)
    if name != 'core-tests.log' and '** BUILD SUCCEEDED **' not in value and '** TEST BUILD SUCCEEDED **' not in value:
        raise SystemExit('Compilation did not complete: ' + name)
passed = re.findall(r"Test Case '-\[(\S+) ([^]]+)\]' passed", text)
unit = len({(suite, name) for suite, name in passed if suite.startswith('TwilDiaryTests.')})
ui = len({(suite, name) for suite, name in passed if suite.startswith('TwilDiaryUITests.')})
if not unit or not ui:
    raise SystemExit('Missing individually passed unit/UI test evidence.')
ipa = args.input / 'ipa' / 'TwilDiary-unsigned.ipa'
digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
expected = (ipa.with_suffix('.ipa.sha256')).read_text(encoding='utf-8').split()[0]
if digest != expected:
    raise SystemExit('IPA checksum mismatch.')
with zipfile.ZipFile(ipa) as archive:
    info = plistlib.loads(archive.read('Payload/TwilDiary.app/Info.plist'))
    if str(info['CFBundleVersion']) != args.build:
        raise SystemExit('Unexpected IPA build number.')
    binary = archive.read('Payload/TwilDiary.app/' + info['CFBundleExecutable'])
    magic, cpu = struct.unpack('<II', binary[:8])
    if magic != 0xFEEDFACF or cpu != 0x0100000C:
        raise SystemExit('IPA is not a physical iPhone arm64 Mach-O application.')
    if any('/_CodeSignature/' in name for name in archive.namelist()):
        raise SystemExit('Unexpected signed payload; unsigned artifact was required.')
verification = {'run': run['databaseId'], 'commit': run['headSha'], 'build': int(args.build), 'bytes': ipa.stat().st_size,
                'sha256': digest, 'architecture': 'arm64', 'minimumIOS': info['MinimumOSVersion'], 'unsigned': True}
args.output.mkdir(parents=True, exist_ok=True)
manifest = []
for record in json.loads((args.input / 'screenshots' / 'manifest.json').read_text(encoding='utf-8')):
    for item in record['attachments']:
        name = item['exportedFileName']
        if not name.lower().endswith('.png') or item.get('isAssociatedWithFailure'):
            continue
        label = re.sub(r'_\d+_[0-9A-F-]+\.png$', '', item['suggestedHumanReadableName'], flags=re.I)
        slug = re.sub(r'[^a-z0-9]+', '-', label.lower()).strip('-') + '.png'
        if any(row['file'] == slug for row in manifest):
            raise SystemExit('Duplicate screenshot label: ' + slug)
        shutil.copy2(args.input / 'screenshots' / name, args.output / slug)
        manifest.append({'file': slug, 'name': label, 'test': record['testIdentifier'], 'device': item['deviceName'], 'fixture': True})
if not manifest:
    raise SystemExit('No retained named screenshots were exported.')
report = {'run': run['databaseId'], 'commit': run['headSha'], 'build': int(args.build), 'status': 'success',
          'tests': {'core': int(core_count[1]), 'native_unit': unit, 'ui': ui}, 'warnings': 0,
          'reviewScope': 'Automated evidence verified. Visual comparison and real-device behavior require separate review.', 'screenshots': manifest}
(args.output / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
(args.output / 'ipa-verification.json').write_text(json.dumps(verification, indent=2) + '\n', encoding='utf-8')
(args.output / 'README.md').write_text(f"Passed build {args.build}, run {run['databaseId']}, source {run['headSha']}.\n\nAutomated checks: {report['tests']}; zero build warnings. {len(manifest)} named synthetic simulator screenshots retained. IPA checksum/build/arm64/unsigned payload verified. Visual parity and physical-device behavior are not established by this script.\n", encoding='utf-8')
print(json.dumps({'tests': report['tests'], 'screenshots': len(manifest), 'ipa': verification}, indent=2))
