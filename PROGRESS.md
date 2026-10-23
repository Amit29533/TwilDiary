# Native TwilDiary progress

Updated: 24 October 2026. Branch: ios-native. Web source: b43454e.

## Current work

The user asked to move past the procedural foundation gates and build the actual app. The 10-step ROADMAP remains a parity checklist, not a claim that those steps passed. Reused the earlier native client without changing that separate repository. Existing web source and deploy workflows are untouched.

## Implemented in this batch

- Swift 6, iOS 26+, XcodeGen and the existing secure Access sign-in/session client.
- Native app shell, separate tab navigation, web vector icons, six accent themes, compact poster/public-rating badges, fixed headers, contained search focus and compact progress cards.
- Home carousel, shortcuts routed to the main tabs, weekly time/count/streak/day bars, planned picks, upcoming episodes and history.
- Library category/status/genre/disk filters, Queue, grid/list/genre sections, public TMDB/Trakt preference and restoration from Trash.
- Catalog search/discovery/review/import, manual add, cast profiles and filmography. Release paths use the real authenticated API; synthetic data is only selected by Debug --ui-testing.
- Title cast/recommendations below the episode list; compact episode window with expansion, notes/location collapsed. Existing watch/status/Undo operations preserved.
- Source inventory, isolated Playwright references at 390x844, extracted design assets and image-comparison tooling under ios/tools and ios/docs.

## CI truth

Run 40001908810 for db13a65 passed: simulator and unsigned-device builds, 10 core tests, 8 session/endpoint tests, 4 UI tests, zero build warnings. Downloaded 13 screenshot attachments and IPA; verified SHA-256, arm64, bundle ID, build 3 and iOS 26 minimum. Evidence: ios/docs/screenshots/step-3 (synthetic fixtures).

Visual inspection caught issues despite passing tests: system and custom tab bars both visible, blue system accent in custom chrome, and poster images overflowing grid bounds. The current follow-up removes the system TabView, retains lazily mounted per-tab navigation stacks, explicitly uses theme accents and constrains artwork to its viewport. Added geometry and single-tab-bar assertions. Do not offer the build-3 IPA as visually ready.

Other follow-ups: first-open Queue/Planned shortcuts, public-rating category constraints, manifest-aware poster progress, the original Stats range bar synchronized to its period menu, 90-day calendar boundary, streak heatmap, source-correct genre denominator and 70/70 web-reference manifest. Run 40005569021 for a825529 compiled simulator/device and passed 11 core + 8 endpoint/session tests; 3/5 UI tests passed. Screenshots confirm the visible single tab bar, theme color and grid fixes. Two stricter checks failed: inactive NavigationStacks expose duplicate Search accessibility nodes; cropped image hit/accessibility bounds exceed their cells. The next batch hides each stack's inner content from accessibility when inactive, constrains image frames/content shapes and gives posters explicit accessible summaries. Search queries retain a uniqueness assertion plus a stable identifier. Build number 5.

The official XcodeGen 2.46.0 archive is now SHA-256 pinned (4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806), replacing the three-minute Homebrew metadata fetch without changing tool version. Archive layout inspected on Windows; execution/generation still happens only in macOS CI.

Local backend contract probe passed 18 requests covering create, watch/idempotent retry, card receipt, Queue/favorite/notes/rating patch, stale-version rejection, revoke/restore, Trash/restore and cleanup. It is hardcoded to the isolated loopback reference server and changes only a fresh synthetic UUID. Existing fixture title versions remained unchanged; hosted requests: zero. Report: ios/docs/LOCAL-API-CONTRACTS.json.

Exact next action: push batch, inspect CI and corrected accessibility/geometry tests, download screenshots and compare before offering IPA. Do not call build 4 green; its UI checks failed.

## Remaining parity work

- Stats full backlog, averages/comparison, monthly/year chart buckets, zero-day coverage and drilldown parity remain incomplete; shared period/bar selection and current streak heatmap are implemented.
- Complete per-episode actions, watch date editing/rewatches, spoiler controls, progress slider and title transaction edge cases.
- Complete native Trakt setup/review/apply, scanner mismatch and backup/export management screens.
- Durable protected offline snapshot/outbox; current complete-snapshot reload preserves in-memory data on read failure, but is not durable offline support.
- Full multi-size/accessibility/empty/error/loading regression and real-phone haptics/scroll/gesture checks.
- Reference capture rerun completed 70/70 successfully. The full manifest now records all enumerated states; this is web reference evidence, not native parity evidence.
- Visual parity is unfinished. Windows Chromium reference font metrics differ from iOS. Each screen still requires simulator comparison and refinement.

## Boundaries / build

No deploys, hosted D1 mutations, provider-account writes or secrets. Test only fixtures/local data. Existing Cloudflare backend is authoritative. No Mac/Swift execution on Windows. All compile, XCTest and XCUITest runs happen in GitHub Actions; core Swift tests run there too. No pbxproj is handwritten.

GitHub CLI: prepend C:/Program Files/GitHub CLI to PATH. Push only ios-native. Workflow: .github/workflows/ios.yml; project: ios/project.yml. Download with gh run download RUN_ID; keep screenshot evidence and label synthetic UI fixtures honestly. Separate TwilDiary-iOS repository remains unchanged.

Additional visual check: the Year menu updated but the range-bar selection was not visibly filled in the build-4 screenshot. Extracted a binding-backed StatsRangeSelector with structural selected background and explicit selected accessibility traits; tests now assert Year selected and cleared on Home→Today. This joins the accessibility/hit-target follow-up before acceptance. Run 40009034584 is superseded by this coherent follow-up; do not use it as acceptance evidence.

Latest completed run: 40009671759 (55828e4), simulator/device/core/session checks pass, 4/5 UI tests pass, zero build warnings. Poster tap/accessibility geometry and the binding-backed Stats selected-state checks now pass. The remaining failure is duplicate hidden Search nodes from cached NavigationStacks; even inner accessibilityHidden did not remove them. The current batch restores Apple's native TabView for tab lifecycle/accessibility, explicitly hides its system tab bar inside every navigation root/destination and via appearance, and retains the web-matched custom capsule. Tests still require zero system bars, unique Search, preserved tab search state and non-overlapping posters. Build 6. Push and verify; do not offer build 5 as fully green.

Run 40012507026 for 07673eb passed: 11 core + 8 session/endpoint + 5 UI tests, zero warnings, 15 screenshots and unsigned arm64 build-6 IPA downloaded/verified (SHA-256 8bf20602033c21d5d1262b91a02217a5e1124719a58561beaa1133bef380d240). Visual inspection confirms single navigation, theme colors, clipped poster cells and active-tab accessibility. However, Stats Year still had no visible accent fill despite the selected trait passing. Do not call that visual parity accepted. The current batch draws the selected segment as a parent-level background, refreshes selector identity on selection and adds a real screenshot-pixel accent check above the selected label. Build 7. Exact next action: push, verify CI/color assertion, download/inspect screenshots, then offer IPA as an unfinished native preview.
