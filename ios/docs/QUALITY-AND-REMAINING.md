# Native quality and remaining work — 25 October 2026

This checkpoint reviews native candidate47 (`8c9f163`) and the separate,
unpromoted review draft (`5064856` plus the cache-size repair). It is a focused
correctness/performance/release review of store, transport, persistence,
projections, shared caching, navigation and CI, combined with T24–T37 claim
verification. It is not a fresh runtime test of every screen or a real-device
performance certification. Windows has not compiled Swift.

## Actual current evidence

* Codemagic47 `6addaa674a72334e32e4ed86` checked out exact
  `8c9f16376389a4b8d162b7cd7b12e96d4fffb7b6`. Native173 units, the4 focused
  stability cases, and all10 early progress/navigation cases pass. The focused
  cases cover Glass compact identity, filmography heading/control alignment,
  retained search/Back, and episode/range/movie Undo. Device Release compilation
  reached success; the full primary/all-phone/final warning gates are pending
  at this checkpoint. This is not overall acceptance.
* GitHub46 `40166839268` is the older `66d625e` diagnostic run. It failed its
  early gate and continues collecting full evidence under the old workflow.
  Do not call it stable or confuse it with candidate47.
* Backend hardening38 focused and391 complete Node tests passed before the
  authorized deployment. This review has not changed server code and has not
  rerun unchanged server tests just to increase the test count.
* Candidate/stable separation is implemented in47. GitHub promotion requires
  the official complete Codemagic check for the exact SHA, then independent
  full GitHub acceptance. A candidate compilation/IPA alone cannot promote.

## Confirmed correctness and release gaps

| Priority | Finding and scope | Status / required next proof |
| --- | --- | --- |
| P1 | Full acceptance across both providers is not yet established. Current focused repairs passing does not prove complete screen/layout acceptance. | Finish47 full49 UI plus both3-case extra-phone suites, inspect screenshots, then same-SHA GitHub validation. Physical scroll/interactive navigation remains separate. |
| P2 | Baseline `DiaryAPI` treats JSON403/304 as expired login and forgets D1 quota reset state. Repeated automatic reads can continue during a known outage. | Prepared typed-status and shared circuit-breaker changes with mock transport regressions on the private review branch. Not compiled/run in47 and not promoted. |
| P2 | An uncertain normal watch and a rewatch share one pending-operation key in baseline code, despite different user intent. | Prepared separate stable intent keys and an idempotency regression in the review draft; movie rewatch already exists. Explicit episode rewatch action is also drafted, not accepted. |
| P2 | Protected-cache writer accepts files larger than the reader's50MiB bound, reports successful caching, and can replace a previously loadable snapshot with one rejected after restart. | Newly prepared shared read/write bound, including encrypted-file overhead, with exact-limit/oversize/preserve-old-file regression. It does not change live diary data. Local syntax passes; new XCTest still needs macOS. |
| P2 | The release resource gate is incomplete: Core's test `workspace.json` is a resource of the production package target, while the gate only rejects `reference-workspace.json`, `catalog-*`, and `trakt-*`. | Confirmed in source and in the downloaded43 IPA at `TwilDiaryCore_TwilDiaryCore.bundle/workspace.json`. It is synthetic test data, with no demonstrated production fallback path; it is still unnecessary release payload. Move test support/resources out of the production target and make the bundle gate reject this name before final release. Do not claim all test fixtures are absent based on the current gate. |
| P2 | Sign-in web navigation policy, persistent Library layout/sort/filters and Codemagic tool pinning need hardening. | Changes and tests prepared on the private review branch.47 intentionally excludes new features. Real provider2FA/popups need a phone check after the policy is built. |
| P3 | Privacy manifest/API-use audit, app-switcher cover and full real VoiceOver/large Dynamic Type audit remain open. | Accessibility labels and selectable chart buckets already exist; an Audio Graph descriptor is an enhancement. A privacy cover must include presented sheets and not break sign-in. No placeholder completion checkboxes. |

## Performance: verified improvements and remaining costs

Already present and covered by current tests:

* Workspace pages decode in detached tasks, with cancellation and session
  fencing before publication. Failed/overlapping pages cannot replace a good
  workspace with partial or duplicate identities.
* Shared card requests coalesce, cache per title/revision/season/day and
  invalidate only affected inputs. The card cache is bounded at128 entries;
  discovery at16, person metadata and community information at32 each.
* Home/Stats projections memoize by workspace/day and relevant calendar,
  zone/range/year. In47's1000-event simulator diagnostic, the cold combined
  projections took72.08ms; the warm pair averaged0.02ms. That test includes
  correctness assertions and is not a phone frame-rate or battery measurement.
* History parses timestamps before ordering and pre-resolves episode lookups.
  Draft fields retain unsaved edits and detect conflicting record versions.
* Provider scores batch bounded requests, retain already-fetched values during
  transient outages and clear per-session state. Discovery can present cached
  recommendations during refresh. No claim of instant provider responses.

Remaining performance work, in order:

1. `ProtectedWorkspaceCache` JSON/AES/file reads and atomic writes currently
   execute on the main actor. Move these behind an asynchronous serialized
   cache interface after the stability baseline, retaining owner/session and
   generation checks so a late save cannot restore signed-out data. Measure
   cold load and save using realistic large snapshots before/after.
2. Workspace indexing and first Home/Stats projections still run synchronously.
   Every accepted edit fetches a full paginated snapshot and rebuilds indices.
   Warm memoization does not remove this cold cost. Profile large event/episode
   sets and invalidation frequency before adding incremental publication.
3. Production artwork uses `AsyncImage`; the app has no explicit remote
   downsampling pipeline. Demo artwork already uses `NSCache`, so the claim
   that every image is uncached is false. Profile repeated poster/backdrop
   decoding and memory before replacing the image layer.
4. Real-device frame pacing, material rendering, touch/haptic timing and battery
   behavior remain in DEVICE-CHECKS.md. CI timing cannot prove these.

## Product work versus validation work

The main views and flows exist: Home, Library/Queue/Trash, saved and catalog
titles/seasons/episodes, Explore/search/cast, Glance, Stats/History,
Files/scanner review, settings/provider setup, exports, reviewed Trakt sync,
Information sentiments and incoming-watch settings. Do not describe unchecked
historical roadmap acceptance boxes as if all those views still need building.

Still required before calling the app finished:

* Finish automated acceptance and inspect current, correctly attributed
  screenshots for every phone size/theme/state in scope.
* Verify on the owner's phone that compact-header crossing/reversing scroll,
  root swipes versus card/carousel gestures, destination-owned bar transitions,
  Information material and expanded episode grids match the latest requests.
* Finish the prepared correctness/release batch and validate it on Codemagic
  before promoting any feature to GitHub.
* Prove real incoming-watch idempotence and observed latency/CPU/D1 usage on
  the Free setup. The preserved manual review currently fences automatic work;
  the measured3ms was that paused path, not a normal enabled import. Never
  cancel the owner's review just to manufacture a performance result.
* Complete the source-of-truth parity comparison, documented intentional native
  differences, accessibility/privacy/release checklist and final regression.

Maintainability is serviceable but can improve: `DiaryStore`, `TitleDetailView`
and shared `Components` combine substantial responsibilities, and many long
view expressions make failures harder to inspect. Extract cohesive parts while
touching those areas, after correctness gates pass; a broad formatting/actor
rewrite during stability validation would increase the review surface without
proving better performance.

One checked apparent discrepancy is intentional: Home's planned cards use
personal ratings in both the current web source (`HomeSections`/`TitleCard`)
and native `personalRating:true`; the Library uses selected community ratings.
Do not change that behavior based solely on a pattern search.
