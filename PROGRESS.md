# Native TwilDiary progress

Updated: 23 October 2026. Branch: ios-native. Web source: b43454e.

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

Latest completed run: 39995573162, commit c184642. Simulator and device compilation, unit/UI tests, screenshot export and all artifact uploads passed. Overall failure came from two UIRequiresFullScreen deprecation warnings. That plist key is removed in the current batch. Actual pinned toolchain: macOS 26, Xcode 26.6, iPhone 17 Pro / iOS 26.5 / arm64.

The new actual-app batch has not compiled yet. Exact next action: commit/push, inspect compiler/test diagnostics, fix and rerun, download the actual-app screenshots and unsigned IPA, inspect them and share screenshots. Do not call the actual app green based on the earlier hello-world run.

## Remaining parity work

- Stats old rolling bar/collision synchronization, full streak/backlog and chart drilldown coverage.
- Complete per-episode actions, watch date editing/rewatches, spoiler controls, progress slider and title transaction edge cases.
- Complete native Trakt setup/review/apply, scanner mismatch and backup/export management screens.
- Durable protected offline snapshot/outbox; current complete-snapshot reload preserves in-memory data on read failure, but is not durable offline support.
- Full multi-size/accessibility/empty/error/loading regression and real-phone haptics/scroll/gesture checks.
- Reference capture: initial run 69/70; corrected loading and duplicate history-state cases reran successfully, but full manifest must be regenerated before declaring all-state coverage.
- Visual parity is unfinished. Windows Chromium reference font metrics differ from iOS. Each screen still requires simulator comparison and refinement.

## Boundaries / build

No deploys, hosted D1 mutations, provider-account writes or secrets. Test only fixtures/local data. Existing Cloudflare backend is authoritative. No Mac/Swift execution on Windows. All compile, XCTest and XCUITest runs happen in GitHub Actions; core Swift tests run there too. No pbxproj is handwritten.

GitHub CLI: prepend C:/Program Files/GitHub CLI to PATH. Push only ios-native. Workflow: .github/workflows/ios.yml; project: ios/project.yml. Download with gh run download RUN_ID; keep screenshot evidence and label synthetic UI fixtures honestly. Separate TwilDiary-iOS repository remains unchanged.
