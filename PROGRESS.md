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

Other follow-ups: first-open Queue/Planned shortcuts, public-rating category constraints, manifest-aware poster progress, the original Stats range bar synchronized to its period menu, 90-day calendar boundary, streak heatmap, source-correct genre denominator and 70/70 web-reference manifest. Build number 4. Exact next action: push follow-up, inspect CI diagnostics, download and visually inspect corrected screenshots before offering IPA.

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
