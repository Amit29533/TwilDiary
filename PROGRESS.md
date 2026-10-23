# Native TwilDiary progress

Updated: 24 October 2026. Active source: **Amit29533/TwilDiary → ios-native → ios/**. Web source of truth: main baseline b43454e. The separate TwilDiary-iOS repository remains unchanged. No PR has been created or merged; GitHub's Compare & pull request banner is only a suggestion.

## Current request and exact next action

Build 8, source a15b103, run **40020975007**, passed: 13 core + 8 endpoint/session + 5 UI tests, zero warnings. Downloaded/verified 16 screenshots and the unsigned arm64 IPA. Visually reviewed the contact sheet, episode pieces, continuous movie track and Stats selection. Full layout parity remains unfinished (see the committed web/native title comparison). The passed-build title screenshot has been shared in chat; IPA is copied to D:/Downloads/TwilDiary-native-build8.ipa with SHA-256 sidecar.

Build 9, source af0c8cd, run **40024110462**, is queued. It adds encrypted cached snapshots, late-response/session guards, reviewed editor/watch checks, selected-season response guards and a no-reflow Undo overlay. Exact next action: inspect this run, fix any compile/test errors, download/review its artifacts, then resume the first unfinished parity item. No full step is claimed complete.

The track uses the source SVG's 12-unit slots, 9-unit rounded pieces, 3-unit gaps, a 12pt drawing in a 44pt row, accent watched fill, 36.08% accent for Up next and #ffffff20 unwatched fill. Episode identities preserve holes in watch history and unloaded manifest slots. Movies retain continuous progress. Two core tests cover holes, ordering, unloaded/empty slots and stale-next precedence. The UI test checks all 16 pieces/gaps, eight filled episodes, and the separate continuous movie track. Interactive range editing remains an explicitly tracked parity gap.

## CI truth

| Run | Source | Outcome and evidence |
| --- | --- | --- |
| 40001908810 | db13a65 | 10 core + 8 endpoint/session + 4 UI tests passed, zero warnings; visual review found duplicate bars and grid overflow. Historical evidence in ios/docs/screenshots/step-3 is marked not accepted. |
| 40005569021 | a825529 | Builds/core/session passed; 3/5 UI passed. Visual bar/grid corrections present; hit bounds and inactive accessibility failed. |
| 40009671759 | 55828e4 | Builds/core/session passed; 4/5 UI passed. Remaining failure: hidden cached stacks exposed duplicate Search controls. |
| 40012507026 | 07673eb | 11 core + 8 endpoint/session + 5 UI tests passed; zero warnings; single native tab lifecycle/custom bar and poster hit geometry verified. Stats selected accessibility trait passed but visual fill was missing. |
| 40014507822 | d952cb9 | Builds/core/session passed; 4/5 UI passed, zero warnings. Stats fill now visibly correct in downloaded screenshot/video. Color assertion accidentally sampled label glyphs; corrected to the empty left interior in build 8. |
| 40017058735 | fe17ea6 | Builds/core/session passed; 4/5 UI passed. Episode pieces rendered correctly, but gap sampling used accessibility ink bounds as padded bounds. |
| 40020975007 | a15b103 | 13 core + 8 endpoint/session + 5 UI tests passed; zero warnings. Actual rendered episode runs/gaps, movie continuity and Stats fill verified. |
| 40024110462 | af0c8cd | Queued: build 9 reliability/cache tests and no-reflow Undo. |

Build-8 artifacts are downloaded under .local/ios-app-build-40020975007; accepted scoped screenshot evidence is in ios/docs/screenshots/step-8. Its arm64 IPA SHA-256 is 82b1de7adcdd32127cfac3321e7153e9f6297ff9ac42928ad2b4bfac5e2ab96b. This is an unfinished native preview, not a release/parity acceptance claim.

## Work present (not full parity acceptance)

- Swift 6, iOS 26+, XcodeGen; real Access sign-in, database-independent session validation, restricted URLSession transport and Keychain credentials.
- Native TabView lifecycle with independent NavigationStacks; system bar hidden; custom capsule, fixed headers, source Lucide assets, six themes, contained search focus and cropped poster hit bounds.
- Home carousel, Explore/Queue/Disk shortcuts, weekly totals/streak/day bars, planned pick, upcoming episodes and history. Home → Stats opens Today without adding new range buttons.
- Library category/status/genre/disk filters, public TMDB/Trakt ratings preference, grid/list/genre sections, Queue and versioned Trash restore.
- Authenticated catalog search/discovery/review/import, manual add, cast profiles and typed movie/TV filmography.
- Title status/watch actions, remaining time, season selection beside Episodes, episode window/expansion, cast/recommendations and collapsed notes/location sections.
- Stats shared period/menu selection, 90-day boundary, basic daily charts, streak heatmap, backlog counts and watched-title genre denominator.
- Complete-snapshot paginated reload preserves in-memory data on read failure; uncertain mutations retain operation identities and server version/Undo receipts.

Debug --ui-testing uses isolated synthetic data and read-only mutation stand-ins. Release builds cannot select that mode. Browsing UI tests do not establish write-flow coverage. The local contract probe passed 18 requests on the isolated loopback backend, including watch/idempotency, patch/conflict, revoke/restore and Trash/restore; it cleaned only its fresh synthetic UUID and left pre-existing fixture versions unchanged. Hosted requests: zero. Report: ios/docs/LOCAL-API-CONTRACTS.json.

## References and comparison

- Primary Playwright references: ios/docs/reference/chromium-win32 — 70/70 enumerated states captured at 390×844.
- Secondary: ios/docs/reference/chromium-win32-402x778 — matches iPhone 17 Pro content after documented 62pt top/34pt bottom OS insets. Added the show reference for the episode-track comparison.
- Native screenshots are synthetic simulator evidence, not live owner data. Windows Chromium font metrics differ from iOS; screenshot capture alone is not a parity pass.
- Source inventory, tokens/icons and comparison scripts are under ios/docs and ios/tools. Roadmap remains the 10-step parity checklist; the user subsequently asked to prioritize actual app work over procedural gates. No entire step is claimed complete without evidence.

## Remaining parity work / known issues

- Title individual episode toggles, spoiler reveal, watch date editing/rewatches, interactive range editing, layout refinement and complete transaction UI regression.
- Stats averages/comparison, hourly/monthly/zero-day buckets, longest/active streak details and full backlog/runtime drilldowns.
- Glance waiting/sort, complete Explore shelves/filters, scanner mismatch review and native Trakt setup/scan/review/apply.
- Full More/settings, backups/import/export and TMDB credential/status management views.
- Protected durable offline snapshot/outbox; reload generation guards; reviewed editor versions and expected-previous safety on minus. Undo toast currently uses a safe-area inset and needs the web's overlay/no-reflow behavior verified.
- Multi-size, accessibility/empty/error/loading/rapid-tap regression; real-device haptics, scrolling, animation timing and LiveContainer login. See DEVICE-CHECKS.md.

No credential is currently required for this fixture-backed work. Provider redirect registration or real-device behavior may require user input later; never fake successful sync or writes.

## Build and safety boundaries

No Mac/Swift execution locally. All compilation, XCTest, core tests and simulator work happen on GitHub Actions. Never hand-write pbxproj. Workflow: .github/workflows/ios.yml. XcodeGen source: ios/project.yml. Pinned macos-26 / Xcode 26.6 / iPhone 17 Pro iOS 26.5. Official XcodeGen 2.46.0 archive is SHA-256 pinned. Builds enforce zero compiler warnings and upload logs, xcresult, screenshots and an unsigned arm64 IPA.

GitHub CLI: prepend C:/Program Files/GitHub CLI to PATH. Run gh run view RUN --log-failed on failure; gh run download RUN for artifacts. Commit messages: step N: description. Push only ios-native. No web source/deploy workflow changes, main pushes, force pushes, hosted D1 mutations/deploys, provider-account writes or committed secrets. Test fixtures or the isolated LOCAL_DIARY=1 loopback backend only. The existing Cloudflare backend remains authoritative.

## Build-8 review follow-up

Run 40017058735 compiled simulator/device and passed 13 core + 8 endpoint/session tests, zero warnings; 4/5 UI tests passed. Stats now passes its pixel assertion. The only failure was the episode test deriving slot positions from accessibility ink bounds, which omit the SVG's outer margins: a late gap sample landed inside an unwatched piece (47). Downloaded video frame confirms exactly 16 correctly separated pieces, eight filled, one next and seven unfilled. The revised UI test counts real foreground runs and internal gaps from a screenshot scanline rather than assuming padded geometry; it still requires all 16 pieces, eight full accents and the next tint. Title attachment is captured before asserting. App rendering and build number 8 are unchanged. Commit/push this test-only correction and await a fully green run before publishing.

## Unattended continuation — build 9 prepared

The user requested continued work through the full parity checklist. The active repository/branch remains TwilDiary/ios-native. Latest remote run is 40020975007 at a15b103 (build 8); wait for its result before pushing build 9 so its screenshot evidence is preserved.

Prepared next coherent batch: AES-GCM owner-scoped protected complete workspace cache with device-only Keychain key, backup exclusion/atomic file writes and sign-out deletion; generation guards for late authentication, sign-out and out-of-order complete reloads; exact reviewed previous-watch guard; retained notes/rating versions; stale selected-season responses discarded; Undo moved from changing safe-area content height to an overlay. Added seven native tests for cache round-trip/tampering/wrong key/owner/token rotation, cached failure preservation, sign-out during authentication/loading and out-of-order refresh. Mutations remain confirmed online only; no durable offline write/outbox claim. This batch is not compiled yet and must pass macOS CI. Build number 9. No hosted data changed.

## CI capacity recovery

Run 40024110462 never acquired a runner and executed zero steps. GitHub's annotation: “The job was not acquired by Runner of type hosted even after multiple attempts,” plus macOS arm64 capacity notices. This is not a compiler/test result. Confirmed official runner-images docs list macos-26-intel with Xcode 26.6 and iPhone 17 Pro/iOS 26.5. Switch to that pinned image; use uname -m for simulator compilation/testing and architecture-specific SPM cache keys; physical Release IPA stays arm64. Defer simulator boot until the test stage to avoid spending runner CPU on an idle simulator during compilation. Exact next action: push CI recovery for the already committed build-9 code and inspect actual compiler/tests. Subsequent title interactions/models are currently uncommitted and are not part of this build-9 verification.

## Build 9 Intel result / build 10 prepared

Run 40026403236 (d71e49a) compiled simulator and physical iPhone builds with zero warnings and passed all 13 core + 15 native unit tests, including every protected-cache and session-race case. Three UI tests passed before the 15-minute step timeout interrupted the fourth. The delay included simulator boot and test-runner startup: boot readiness took ~3 minutes and the unit host started ~9 minutes after entering the old combined boot/test step. This is not a green complete UI run. Logs downloaded under .local/ios-app-build-40026403236/results; no final xcresult screenshots were exported after the interruption.

Build-10 batch is prepared: restore early simulator warm-up, give boot readiness its own timeout, allow the expanded actual test suite 25 minutes, capture a final diagnostic simulator screenshot even when xcresult is incomplete, and fail the summary if TEST EXECUTE SUCCEEDED is missing. Intel image remains pinned to Xcode 26.6/iPhone 17 Pro/iOS 26.5; device IPA is arm64.

New native work, awaiting compile/tests: interactive season progress using aired-episode plans and retry identities/partial Undo; episode watched/unwatched controls, spoiler reveal/lazy detail pages, native watch date, movie rewatches/history, retained editor versions and a more faithful hero/synopsis layout. Added complete export schema/location fields and native JSON file export. More now follows the actual web groups with spoilers, history, theme/region readouts, TMDB check, About and bundled Lucide license. Native Trakt service/controller/view supports status, scan/pause/continue, kind/search/paging, rating mode, cooldown, explicit Apply/Keep TwilDiary/Use Trakt/Skip, safe batch apply, stop scan and disconnect. Auth-only ephemeral browser preserves existing server PKCE/state callback; external-browser fallback is included. No backend change/deploy or real account mutation.

Tests prepared: 18 core + 24 native unit + 6 UI cases. Tests include all four Trakt wire choices, conflict exclusion from ready batches, explicit local/Trakt choices, Skip/filter counts, retry identity/date preservation and a fixture-only review→safe apply→conflict resolution UI walkthrough. General workspace mutation UI fixtures remain read-only; their transport/domain contracts are tested independently, not claimed as full end-to-end mutation UI coverage. Date calculations now match the web's local-day future cutoff; immutable ISO parsing and indexed title lookups remove repeated formatter/linear-search work. Full parity checklist remains unfinished. Exact next action: commit/push build 10, fix every CI diagnostic, download and compare passed screenshots, then continue Library/Glance/Stats/locations hardening and broader regression.
