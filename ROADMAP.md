# Native TwilDiary roadmap

Work branch: `ios-native`. Product source: `/preview/*` at web baseline `b43454e`. Native project: `/ios`. The separate `TwilDiary-iOS` repository is preserved as reusable, previously compiled source, not accepted as parity evidence. The user subsequently asked to prioritize building the app over the sequential procedural gates. This remains the parity checklist; checked subtasks are evidence-backed and do not imply an entire step is complete. No hosted writes or deployments are authorized by this plan.

## 1. Foundation and CI

Goal: prove a Windows-to-macOS-to-iPhone-artifact workflow, then freeze the audited reference and design system.

- [x] Verify Git, Node 24+, GitHub CLI authentication and enabled Actions.
- [x] Prove minimal SwiftUI app, XCTest, XCUITest, screenshots and unsigned IPA via `gh run download` (overall warning gate tracked separately).
- [ ] Audit docs, all routes/components/controllers/domain rules/API/schema/migrations/tests; record code/document discrepancies.
- [x] Capture the 70 enumerated web screens/states at 390×844 with Playwright against isolated local data; save reference images and manifests. Further edge cases may expand this set.
- [x] Extract CSS/theme/type/spacing/radius/shadow/icon tokens and deterministic comparison tooling.
- [ ] Record architecture, install instructions and real-device checks; pin confirmed Xcode/simulator; zero build warnings.

Screens/files: `ios/project.yml`, `ios/App`, `ios/Tests`, `ios/UITests`, `ios/tools`, `ios/docs/reference`, `ios/docs/IOS-ARCHITECTURE.md`, `.github/workflows/ios.yml`.

Done: the complete CI pipeline is green, artifacts downloaded/verified, references reproducible, audit and tokens committed; foundation harness is explicitly distinct from finished product UI.

## 2. Data and networking

Goal: preserve the backend contract, history and credentials under success, failure and reconnect.

- [ ] Codable models for schema/API projections, validated date/identity/pagination rules and fixtures.
- [ ] Restricted URLSession client, cancellation, typed error/quota/conflict handling and Keychain.
- [ ] Lowest-friction secure Access sign-in; no bundled service tokens; document native callback constraints.
- [ ] Owner-scoped encrypted/protected local snapshot and durable operation identities; honest offline behavior.
- [ ] URLProtocol, serialization, authentication, cache, reconnect and stale-response regression tests.

Screens/files: `ios/Core`, `ios/Networking`, `ios/Persistence`, `ios/Tests`, authentication/loading/error/offline screens.

Done: fixture/local-backend flows preserve complete snapshots, authentication and retry identities; no live mutations; CI and every in-scope state comparison pass.

## 3. App shell and shared UI

Goal: reproduce fixed chrome and shared controls without changing product geometry.

- [ ] Five tabs, per-tab navigation/scroll/form restoration, fixed opaque header, exact safe areas and keyboard handling.
- [ ] Web-matched typography/icons/themes and Liquid Glass/reduced-transparency behavior for iOS 26+.
- [ ] Posters/carousels/chips/native selectors/sliders/dialogs/toasts/Undo and long-press policy.
- [ ] Motion, tap feedback, accessibility labels, rapid taps and reduced-motion tests.

Screens/files: `ios/Shell`, `ios/Design`, `ios/Components`, shared XCUITests.

Done: shared states match references at SE/390/Pro Max sizes; navigation and Undo do not jump; green regression and screenshots.

Pending device-feedback build29: typed Done ownership, keyboard-safe pushes and Add-sheet handoff, retained synopsis lead with full-width continuation, stable Notes editor targeting after late metadata, swipe-dismiss Surprise and collection list/grid preferences. All await macOS compile, functional UI checks and all-phone screenshots; no additional checkbox accepted yet.

## 4. Home

Goal: reproduce the existing Home and each linked daily action.

- [ ] Continue carousel and exact remaining-time layout, watch action and Undo.
- [ ] Horizontally scrolling shortcuts, This week, Up next/pick-for-me, new episodes and Recently watched.
- [ ] Inline grouped search, add/manual-add entry points, All history and Stats default-to-Today navigation.
- [ ] Empty/loading/error/long-title/rapid-update/scroll restoration tests and screenshots.

Screens/files: `ios/Features/Home`, corresponding models/tests/references.

Done: every Home control works against fixtures/local API and matches the web, including restored state and date navigation.

Pending follow-up after build 20: shared artwork random-pick dialog and three-tap logo entry; planned-only versus full collection scopes, previous-pick exclusion, empty Add search, and minute/foreground dates. Added source reference states and native regressions; acceptance awaits macOS CI and screenshots.

## 5. Library

Goal: preserve artwork-led browsing and independent collection commands.

Build-12 implementation includes normalized query/shelves, reviewed selection and atomic collection operations, shared progress reset/completion transactions, archived grid/list and deletion confirmations. Awaiting compile/unit/UI evidence; checkboxes below remain acceptance gates. Native Empty Trash adds a destructive confirmation before the existing explicit server action; disk files remain untouched.

- [ ] Category tabs, grid/list, genre rows, search, status/genre/disk filters and sorting.
- [ ] Public TMDB/Trakt rating badges and preference; distinct watch status and availability.
  - Build 17 pending: source cache TTL/batching/deduplication, scoped outage feedback, cancellation/sign-out and preference/public-versus-personal regressions; two additional web states captured.
- [ ] Selection/long press, bulk status, favorites, Queue, Trash/restore and explicit permanent-delete test fixtures.
- [ ] Filter composition, reviewed versions, pagination, empty/error/overflow/state restoration tests.

Screens/files: `ios/Features/Library`, collections/Queue/Trash, tests.

Done: every filter/action matches source semantics, no personal/public-rating substitution, atomic conflict-safe bulk operations; screenshots and CI green.

## 6. Title screens

Goal: reproduce movie/show/anime details and watch transactions.

- [ ] Clear hero/poster, ratings/synopsis, native toolbar menu and normal mark-watched button.
- [ ] Season selector beside Episodes, lazy metadata, spoiler reveal, episode list and progress slider.
- [ ] Status/history parity: Completed fills valid missing watches; Planned revokes all progress with Undo; preserve dates/rewatches appropriately.
- [ ] Individual watches, dates/rewatches, notes collapsed, server locations collapsed, cast and recommendations ordering.
- [ ] Person/cast pages and filmography destinations; stale writes, uncertain receipts, Undo and catalog-boundary tests.
  - Build 17 pending: full Person facts/server/known-for/media shelves and filtered filmography, source-role return and bounded metadata cache; 40 web golden cases and native navigation/filter regression.

Screens/files: `ios/Features/Title`, `ios/Features/People`, progress/history transactions.

Done: every title variant and mutation/recovery state matches the web; no fabricated catalog/history; CI/screenshots green.

## 7. Explore and discovery

Build-19 pushed follow-up (run 40072178351): shared catalog/title hero, lazy read-only season preview and reveal/cache regression, source category import and isolated identity-preservation fixture. Five additional web references captured (85 total); native compile/UI evidence pending.

Goal: reproduce provider search/review/import and exploration without accidental imports.

- [ ] TMDB/IMDb-aware grouped search, local matches and independent provider loading/errors.
- [ ] Discovery shelves/View more, recommendations, genres, filters/paging, surprise picks.
- [ ] Catalog review/category choice, retry-safe import and existing/trashed identity handling.
- [ ] Search cancellation, stale results, offline/provider outage and return-state tests.

Screens/files: `ios/Features/Explore`, catalog review/search, tests.

Done: all discovery routes and controls match references and import rules; fixture-backed tests and CI green.

## 8. Glance, Stats and history

Goal: reproduce quick updates and truthful date-based calculations.

- [ ] Glance filters/sorting, swipe-one-watch, stable release layout, +/-/Undo and waiting episodes.
- [ ] Watch-time chip/old rolling bar collision-only synchronization, Today/week/month/year, selected-year and chart drilldowns.
- [ ] Streaks, backlog/in-progress/stale titles, top-five expandable genres and horizontally scrolling data.
- [ ] Separate Recently watched with title/date/range filters and Home All history routing.
- [ ] DST/local-midnight/future/undated/unknown-runtime/rewatch/trashed data tests and chart accessibility.

Screens/files: `ios/Features/Glance`, `ios/Features/Stats`, `ios/Features/History`, Swift Charts/calculations.

Done: calculations agree with exported web fixtures and each chart/filter/history state passes visual and interaction regression.

Pending History follow-up: exact activity.ts ordering/date/search/unknown rules and independent rewatch evidence, visible source shortcuts, clearable date inputs and 12-row pagination. Nineteen generated source scenarios and a return/filter/paging UI flow await native CI.

## 9. Locations, More, provider setup and Trakt

Goal: reproduce every mobile management view and reviewed synchronization safely.

- [ ] Files/drives/Disk Map, location paths, scanner mismatch review; document Windows-only production/ingestion actions.
- [ ] More/settings, themes, spoilers, episode policy, dates/ratings/region/preferences, About/attribution and actual export.
- [ ] TMDB/Trakt connection states and native-safe credential setup boundaries.
- [ ] Trakt PKCE, direction/type settings, scan/review/apply/cancel/conflicts/retry; exclude demo data from exports.
- [ ] API/fixture UI coverage for all one-way/two-way combinations; no real account writes.

Screens/files: `ios/Features/Locations`, `ios/Features/Settings`, `ios/Features/Trakt`, `ios/docs/IOS-PARITY.md`.

Done: every mobile control works or exactly mirrors an explicit web limitation with evidence; fixture sync preserves histories/ratings/Queue; CI green.

## 10. Final polish and hardening

Goal: release a verified native client with an honest parity and device checklist.

- [ ] Offline/reconnect/conflicts, persistence recovery, protected cache lifecycle and authentication-expiry tests.
  - Next batch pending: confirmed mutation versus failed refresh acknowledgement, retained Undo, stale-write gating and explicit reconciliation; four transport regressions and one isolated UI recovery flow.
- [ ] Full screen/state screenshot regression on SE/390/Pro Max; long text, keyboard, accessibility, reduced motion/transparency.
- [ ] Animations/haptics, memory/network/image performance, app icon/launch screen and zero warnings.
- [ ] Complete `IOS-PARITY.md`, `DEVICE-CHECKS.md`, release checklist, artifact checksums and installation guide.
- [ ] One final clean build/test/download/visual pass across all prior steps.

Screens/files: all `/ios`, final screenshots, reports and release artifact.

Done: no unfinished native placeholders/dead controls; all tests/builds/warnings/visual gates pass; remaining physical-device checks and genuine web limitations are explicitly recorded; all changes committed only to `ios-native`.

## Evidence checkpoint — 24 October, build 14 prepared

- Run 40035195084: zero-warning simulator/device builds; all 25 core (17 web Stats golden scenarios) and 32 native unit tests pass; 7/9 UI tests pass. Full acceptance is still pending.
- Library reviewed Queue/Trash/restore/purge UI passes. Files/scanner mapping core/transport tests pass; dismissal hit bounds need correction. Trakt safe apply works; conflict button accessibility needs correction.
- Current source audit removes obsolete gaps from older mockups: no Glance waiting/sort, hourly Stats, settings import/backup or offline write outbox exists in current web code.
- Next gate: build-14 header Done / unique conflict action regression, complete CI green, downloaded screenshots and verified IPA; then remaining real parity work.

## Discovery/search checkpoint — build 15 prepared, uncompiled

- Existing source sections, filters, deterministic unwatched daily choice, real Trakt recommendation reads and provider paging are ported. Combined /api/search replaces metadata-only search; scoped Library/Glance search stays unchanged.
- 20 web golden cases/five daily picks and controller/transport/UI regressions are added. Await CI before checking acceptance boxes.
- Reference inventory expands from 70 to 78 passing states. Read-only provider fixtures honor source filter/paging and search response contracts. No web product file changed.

Build 14 evidence checkpoint: run 40056346004 passes all 66 tests/zero warnings; 29 screenshots and verified IPA saved. Visual review still found sticky Trakt Apply overlap; build 15 follows the current source in-list action and asserts full bounds above navigation.

## Watch/editor hardening checkpoint — build 16 prepared, uncompiled

- The expanded real local API probe passes 30 requests with unchanged pre-existing fixtures and zero hosted requests; fixture watch/Undo receipts mirror those contracts and the existing server status projection.
- Title history refresh/initial season/window rules and retained editor state are corrected from source; three mutation/draft UI flows and two core selection regressions are added. Validation awaits CI.
- Core cache retains compiler work but never skips tests. Future full runs allow 65 minutes/35-minute native tests to cover the larger regression suite on the pinned Intel image.

## Build 23 follow-up prepared — not compiled

- [ ] Source-measured Library category/filter/sort/layout/grid geometry and all-size bounds acceptance.
- [ ] Navigation dark gradient, Liquid Glass selection/labels and reduced-transparency surface acceptance.
- [ ] Home upcoming episode carries its validated season and reveals Episodes; ordinary title links retain default behavior.
- [ ] Title menu reveals Notes/Files in view; location evidence/path/copy/empty/Files-return controls work.

The unchanged web unit suite passes 346 tests and isolated reference walkthrough passes 96 states; two additional menu states pass separately (98 in the manifest). Native compile/runtime/screenshots remain pending. Existing earlier-step regressions remain enabled.
