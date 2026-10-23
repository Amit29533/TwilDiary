# Native TwilDiary progress

Updated: 23 October 2026 (Asia/Kolkata). Branch: `ios-native`.

## Current step

Step 1: Foundation and CI. Environment gate passed; minimal pipeline proof is next. Step 0 source audit is being recorded alongside the pipeline proof, before product Swift implementation. No product screen is accepted yet.

## Verified state

- Git 2.53.0, Node 24.21.0 and authenticated GitHub CLI (Amit29533, HTTPS, workflow permission).
- `TwilDiary` Actions enabled with all actions allowed. No previous `ios-native` run.
- Web baseline `b43454e`; no existing web files changed. Separate native repo remains clean at `5d9cc2e`.
- Separate preview CI run `39988206745` actually completed successfully: simulator/device builds, 7 core + 7 session + 2 UI tests. This does not establish parity or the new `/ios` pipeline.
- Read primary runner-image documentation: macOS 26 includes Xcode 26.6 at `/Applications/Xcode_26.6.app`. The first new run will print actual versions/devices before pinning the simulator runtime.
- Existing native code requires iOS 26 and has partial functionality; reuse only after iOS 17 availability and parity review. Do not replace the audited web UI with its approximations.

## In progress / exact next action

The iOS 17-compatible verification app, restricted endpoint unit test, launch/interaction XCUITest, XcodeGen project and artifact-producing workflow are written and self-reviewed. Push this coherent `step 1:` commit, watch with GitHub CLI, fix all diagnostics, download/verify screenshot and unsigned IPA artifacts. While CI runs, finish the route/API/component/schema/test audit and prepare isolated web references. AppIntents SDK is explicitly linked for all bundles so Xcode's metadata extraction can inspect the framework without its missing-dependency warning; no third-party Swift dependency is added.

## Last CI

First branch run: `39993797967` for `80aca05`. Simulator/device compilation, unit/UI tests, screenshot export and IPA succeeded; whole run failed because upload-artifact excluded the hidden `.artifacts` parent for the multi-path logs/results upload. `gh run download` retrieved IPA and both screenshots. Fix: include hidden files only for the explicit artifact allowlist. Actual toolchain: Xcode 26.6, iPhone 17 Pro, iOS 26.5; pin runtime and arm64 destination to remove Xcode's duplicate-destination warning. Prior separate-repo run: `39988206745`, success.

## Decisions / boundaries

- All new app/project/tooling lives in `/ios`; workflow `.github/workflows/ios.yml`; never hand-write `.pbxproj`.
- SwiftUI, Swift 6 strict concurrency, Observation, iOS 26+, iPhone-only, portrait first. The user subsequently confirmed their phone runs iOS 27 and waived older-iOS support; use iOS 26 Liquid Glass directly. The original iOS 17 proof compiled, but the target is now 26. CI-only Swift compilation/simulators.
- Native project is now in the requested web repo branch; preserve the earlier separate native repo unchanged.
- Existing Cloudflare backend is authoritative. No deployment, hosted D1 access/migration, provider-account mutation or Access-policy change is authorized. Any proposed backend addition requires explicit deployment approval.
- Local fixture/reference tooling must isolate all API writes and never export owner credentials/data.
- `gh.exe` is installed at `C:/Program Files/GitHub CLI/gh.exe`; this running process needs that directory prepended to PATH for each CLI invocation.

## Discrepancies / known issues

- README and older docs describe separate preview/diary implementations, older navigation, deferred features and historical test counts. Current `/preview` routes/controller and schema win; the audit will list exact discrepancies.
- Browser tool last reported disabled; user explicitly requested Playwright, so isolated Playwright reference tooling may run through the terminal. No native Swift execution is attempted on Windows.
- Prior physical sign-in failure was D1 quota exhaustion; source already contains database-independent `/api/session`. This branch may consume that existing endpoint without deploying anything.
- Source inventory generation read and hashed 336 source/doc/migration/test files: 18 screens, 44 API handlers, 1,600 relevant CSS declarations and 349 test cases. Detailed semantic audit and state references remain in progress.
- Disposable reference workspace is `%TEMP%/twildiary-ios-reference-b43454e`, port 5193, fresh local D1 only; sample fixture has 6 titles/66 episodes/28 events/3 mappings. No owner configuration was copied. Browser fixtures block external traffic and use fictional provider responses.
- Windows Git Bash is not at the assumed `C:/Program Files/Git/bin/bash.exe`; no local bash syntax-check result is claimed. Actual CI executed all script stages successfully; only upload failed.

## BLOCKED

None for the foundation. Later native system-browser auth may need an additive callback endpoint/configuration; design/test locally and document any explicit approval needed. Real-device haptics/scroll/gesture evaluation belongs in `ios/docs/DEVICE-CHECKS.md`.

## Build/test/resume

At every resume: read ROADMAP/PROGRESS, `git status`, `git log -20`, `gh run list --branch ios-native --limit 10`, inspect latest real CI/artifacts. Continue the first unchecked gate; do not trust prose alone.

Windows: `git --version`, `node -v`, `gh auth status`. Mac tools run only in Actions. Intended CI: XcodeGen → simulator build-for-testing → test-without-building/xcresult → device Release build → unsigned IPA → artifact download and visual review. Detailed commands are added with the workflow.
