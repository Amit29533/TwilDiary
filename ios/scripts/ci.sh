#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
ARTIFACTS="$PWD/ios/.artifacts"
mkdir -p "$ARTIFACTS/logs"
PROJECT="$PWD/ios/TwilDiary.xcodeproj"
COMMON=(-project "$PROJECT" -scheme TwilDiary -clonedSourcePackagesDirPath "$PWD/ios/.spm" CODE_SIGNING_ALLOWED=NO)
SIM_ARCH=$(uname -m)

case "${1:?CI stage required}" in
  inventory)
    { sw_vers; xcodebuild -version; swift --version; } | tee "$ARTIFACTS/toolchain.txt"
    xcrun simctl list devices available -j > "$ARTIFACTS/devices.json"
    cat "$ARTIFACTS/devices.json"
    python3 - "$ARTIFACTS" <<'PY'
import json, os, pathlib, re, sys
folder = pathlib.Path(sys.argv[1])
devices = json.loads((folder / 'devices.json').read_text())['devices']
candidates = [(runtime, device) for runtime, items in devices.items() if runtime == 'com.apple.CoreSimulator.SimRuntime.iOS-26-5'
              for device in items if device['name'] == 'iPhone 17 Pro' and device.get('isAvailable', True)]
if not candidates:
    raise SystemExit('Required iPhone 17 Pro simulator is unavailable; inspect devices.json')
runtime, device = max(candidates, key=lambda item: tuple(map(int, re.findall(r'\d+', item[0]))))
record = {'runtime': runtime, 'name': device['name'], 'udid': device['udid']}
(folder / 'simulator.json').write_text(json.dumps(record, indent=2) + '\n')
layout = []
for name in ['iPhone 17e', 'iPhone 17 Pro Max']:
    match = next((item for item in devices[runtime] if item['name'] == name and item.get('isAvailable', True)), None)
    if match is None: raise SystemExit('Required layout simulator unavailable: ' + name)
    layout.append({'name': name, 'udid': match['udid']})
(folder / 'layout-simulators.json').write_text(json.dumps(layout, indent=2) + '\n')
print('Selected simulator:', json.dumps(record))
with open(os.environ['GITHUB_ENV'], 'a') as file:
    file.write('SIMULATOR_ID=' + device['udid'] + '\n')
PY
    SIM_ID=$(python3 -c 'import json; print(json.load(open("ios/.artifacts/simulator.json"))["udid"])')
    xcrun simctl boot "$SIM_ID" || true
    ;;
  build-simulator)
    xcodebuild build-for-testing "${COMMON[@]}" -destination "platform=iOS Simulator,id=$SIMULATOR_ID,arch=$SIM_ARCH" \
      -derivedDataPath "$PWD/ios/.derived/simulator" 2>&1 | tee "$ARTIFACTS/logs/simulator-build.log"
    ;;
  build-device)
    xcodebuild build "${COMMON[@]}" -destination 'generic/platform=iOS' -configuration Release \
      -derivedDataPath "$PWD/ios/.derived/device" 2>&1 | tee "$ARTIFACTS/logs/device-build.log"
    ;;
  package)
    mkdir -p "$ARTIFACTS/package/Payload"
    cp -R ios/.derived/device/Build/Products/Release-iphoneos/TwilDiary.app "$ARTIFACTS/package/Payload/"
    (cd "$ARTIFACTS/package" && ditto -c -k --keepParent Payload ../TwilDiary-unsigned.ipa)
    (cd "$ARTIFACTS" && shasum -a 256 TwilDiary-unsigned.ipa > TwilDiary-unsigned.ipa.sha256)
    ;;
  boot)
    xcrun simctl bootstatus "$SIMULATOR_ID" -b 2>&1 | tee "$ARTIFACTS/logs/simulator-boot.log"
    ;;
  test)
    xcodebuild test-without-building "${COMMON[@]}" -destination "platform=iOS Simulator,id=$SIMULATOR_ID,arch=$SIM_ARCH" \
      -parallel-testing-enabled NO -derivedDataPath "$PWD/ios/.derived/simulator" \
      -resultBundlePath "$ARTIFACTS/Tests.xcresult" 2>&1 | tee "$ARTIFACTS/logs/tests.log"
    ;;
  test-layouts)
    xcrun simctl shutdown "$SIMULATOR_ID" || true
    while IFS=$'\t' read -r layout_name layout_id; do
      xcrun simctl boot "$layout_id"
      xcrun simctl bootstatus "$layout_id" -b
      xcodebuild test-without-building "${COMMON[@]}" -destination "platform=iOS Simulator,id=$layout_id,arch=$SIM_ARCH" \
        -parallel-testing-enabled NO -only-testing:TwilDiaryUITests/LayoutScreensTests \
        -derivedDataPath "$PWD/ios/.derived/simulator" -resultBundlePath "$ARTIFACTS/Layout-$layout_name.xcresult" \
        2>&1 | tee "$ARTIFACTS/logs/layout-$layout_name-tests.log"
      xcrun simctl shutdown "$layout_id"
    done < <(python3 -c 'import json; [print(item["name"].replace(" ", "") + "\t" + item["udid"]) for item in json.load(open("ios/.artifacts/layout-simulators.json"))]')
    ;;
  screenshots)
    mkdir -p "$ARTIFACTS/screenshots"
    xcrun simctl io "$SIMULATOR_ID" screenshot "$ARTIFACTS/screenshots/final-screen.png" || true
    if [ -f "$ARTIFACTS/Tests.xcresult/Info.plist" ]; then
      xcrun xcresulttool export attachments --path "$ARTIFACTS/Tests.xcresult" --output-path "$ARTIFACTS/screenshots"
    fi
    for result in "$ARTIFACTS"/Layout-*.xcresult; do
      if [ -f "$result/Info.plist" ]; then
        folder_name=$(basename "$result" .xcresult)
        xcrun xcresulttool export attachments --path "$result" --output-path "$ARTIFACTS/screenshots/$folder_name"
      fi
    done
    ;;
  summary)
    python3 - "$ARTIFACTS" <<'PY'
import os, pathlib, re, sys
folder = pathlib.Path(sys.argv[1]); warnings = []; errors = []; tests = []
for path in sorted((folder / 'logs').glob('*.log')):
    for line in path.read_text(errors='replace').splitlines():
        if re.search(r'\b(?:error:|Test Case .* failed)', line): errors.append(f'{path.name}: {line}')
        if ('build' in path.name or path.name == 'core-tests.log') and re.search(r'\bwarning:', line, re.I): warnings.append(f'{path.name}: {line}')
        if re.search(r'Executed \d+ tests|\*\* TEST .* \*\*', line): tests.append(line)
test_log = folder / 'logs' / 'tests.log'
if not test_log.exists() or '** TEST EXECUTE SUCCEEDED **' not in test_log.read_text(errors='replace'):
    errors.append('tests.log: Unit/UI execution did not finish successfully; inspect the job timeout and xcresult before accepting this build.')
layout_config = folder / 'layout-simulators.json'
if layout_config.exists():
    import json
    for device in json.loads(layout_config.read_text()):
        path = folder / 'logs' / ('layout-' + device['name'].replace(' ', '') + '-tests.log')
        if not path.exists() or '** TEST EXECUTE SUCCEEDED **' not in path.read_text(errors='replace'):
            errors.append('Layout regression incomplete/failed: ' + device['name'])
summary = '\n'.join(['## iOS build diagnostics', f'Build warnings: {len(warnings)}', f'Errors/failures: {len(errors)}',
                     *errors[:20], *warnings[:20], *tests[-12:]]) + '\n'
print(summary)
if os.environ.get('GITHUB_STEP_SUMMARY'):
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as output: output.write(summary)
if warnings or errors: raise SystemExit(1)
PY
    ;;
  *) echo 'Unknown CI stage' >&2; exit 2 ;;
esac
