# Native TwilDiary progress

## Resume first

Current step: **10 — stabilization, parity and release hardening**. Not finished.
Audit scope: **native iOS UI, its database/API/Trakt data flow and CI workflows**.
Do not restart web/PWA UI walkthroughs. Tests use synthetic native fixtures,
URLProtocol or disposable local D1/SQLite. Current hosted library stays untouched.

Read ROADMAP.md, this file, git status/log and actual CI/provider results before
editing. Source tests and notes never replace executed evidence. Historical
progress is preserved in ios/docs/BUILD-HISTORY-THROUGH-NATIVE54.md and
BUILD-HISTORY-NATIVE55-64.md; old pending statements there are historical.

Windows has no Mac/Xcode/Swift compiler. Swift compiles and runs only in macOS
CI. XcodeGen generates the project; no hand-written pbxproj. Swift6/Observation,
iOS26+ for owner's iOS27, no third-party Swift packages. Toolchain: Xcode26.6,
iOS26.5 iPhone17Pro/17e/17ProMax. CM M2candidate; GHA macos-26-intel independent.

## Current source/provider matrix — 26 October2026 IST

- **61 complete Codemagic / delivered IPA:** source8c9514094e96498855b83034c52c4b4349af8fee,
  run6ade36de4a72334e32e5107f, official check121249082762. Downloaded logs prove
  219native,17focused,10early,53primary UI;3layout cases each extra phone;
  68Core cases, zero build warnings. Actual physical arm64 IPA/ZIP/checksum/resources
  verified. D:/Downloads/TwilDiary-native61-codemagic-passed.ipa,
  SHA25696eb75f475fdc1ff006c4e3acecbb94f50e6effd8d08d3b0f5ec86e29f24362e.
  Original screenshots:ios/docs/screenshots/step-10/build-61-codemagic-passed;
  scope/hash/provenance JSON retained and images visually inspected/shared.
- **62 complete official Codemagic; independent GitHub now running:** exact
  50134fc9addcc243434ee5721eb74ea1eec13f61, CM6ade49474a72334e32e515c7,
  official completed/success check121268303837. verify-codemagic.py accepts it.
  Prior live log inspection proved219native/17focused/10early, device Release,
  privacy manifest in actual bundle and no fixtures. Complete official provider
  pass is verified; final screenshot/IPA archive download remains pending.
  Only this exact SHA fast-forwardedios-native. **GHA40228034161** candidate-proof
  and backend-contracts pass; downloaded Ubuntu logs prove407tests, typecheck
  0errors/0warnings and successful Worker build. Intel Core calculations passed; simulator/test targets compiling.
  Do not call the independent GHA/IPA stable until all later gates pass.
- **63 running Codemagic candidate:** source0c087e72745e44a39cb4439ea1036f3ee26c0a71,
  CM6ade51214a72334e32e51821, official check121268338393 in_progress. Queued UI
  metadata and official GitHub check both identify this exact SHA.228native and
  54primary UI source cases; no runtime result yet. Candidate refcodex/ios-ci-next
  stays at this source. No automatic candidate trigger.
- **64 local draft:** eb0f3db plus evidence/document reconciliation oncodex/ios-phone-polish.236native/54primary and69Core
  source cases; Swift grammar/YAML/Bash and16CI-tool cases pass.408backend tests
  and0-error/0-warning typecheck pass. Not compiled/run on macOS. Do not publish
  it over63's candidate ref while that evidence is still being collected.

Browser control currently reports disabled; GitHub CLI still works. CM62artifact
and63log inspection needs a working browser or official result evidence. Do not
extract cookies/tokens or bypass that boundary. Browser ID2; CM62tab7/CM63tab8
were markedhandoff. Re-read CUA docs after compaction; get fresh tab inventory
if stale. Preserve any owner tabs. A downloaded artifact event can timeout while
its file still finishes inD:/Downloads; inspect the file before retrying.

## Implemented and actually tested through61

- First-party SwiftUI TabView bar, stable per-tab paths, both-direction body
  swipes/no wrapping with short Glance watch gesture/Undo ownership preserved.
- Shared single native saved-title header action: crossfade Information/Share,
  centered identity and fixed toolbar slots. Episode grid tick overlays thumbnail
  bottom-right with44pt touch target. Native keyboard-safe Back/search/Notes.
- Retained bulk Trakt controller survives tabs; only approved runID persists.
  2,000-change regression, typed cooldown/Retry-After/D1reset, GETread-back before
  further write, bounded6recovery failures, explicit Pause and background/resume.
  No blind POST transport replay. Global counts/progress and rounded controls.
- Protected owner-scoped AES-GCM cache: off-main save preparation/cold read,
  cancellation/session/snapshot/cache generation fences. Keychain and short atomic
  commit stay on UI actor. Cold-load/restoration and stale callback tests pass.
  Index/projection still on MainActor; no physical FPS/battery claim.
- Actual full UI covers Home carousel/controls, Library filters/sorting/Queue/
  Trash/restore, title/range/movie/history/Undo, spoilers/ratings/notes, discovery/
  cast, Stats/date/unknown history, settings/files/scanner, Information states,
  per-card pending/category reuse, native root/navigation/empty/error states.
  Physical motion/material/accessibility remains separately unverified.

##62qualified changes and pending hosted data rollout

- Catalog reuses the saved-title one-button header; focused search-return
  assertions now include forward/reverse Share/Information ownership.
- PrivacyInfo.xcprivacy explicitly packaged; CA92.1app-only preferences and
  35F9.1in-app elapsed time. Built-bundle verifier checks reasons and excludes
  fixtures/TestSupport. No empty collected-data declaration; final privacy labels
  and provider/log retention still need review.
- Legacy runtime import now accepts whole1–1440minutes/null; malformed existing
  rows projectunknown without rewriting storage. Negative regressions reproduced
  acceptance/serialization beforefix.
- Actual SQL captured unbounded ordered latest review/movie-watch reads.
  Four first-row queries nowLIMIT1;0016ordered/partial indexes avoid full history
  sorting in real SQLite plans (1,000reviews/600rewatches). Local WranglerD1pass.
-0014incremental review bucket triggers/counters/indexes remove repeated COUNT
  scans after every apply;0015durable planning IDcursor replaces continuingOFFSET
  work and upgrades old checkpoints after one compatibility read. Atomicity,
  rollback/replay/600apply/2kchange/backfill/query-plan tests pass locally.
- GHA now requires same-SHA CM pass plus Ubuntu native API/database contracts
  before macOSartifact publication.17focused-case Intel budget35min is based on
  actual8-case12m37s/17-case M2~13m30s; individual test deadlines unchanged.

**No0014–0016hosted migration/deployment during this audit.** Dashboard rolling24h
showed12.23Mreads,36.56kwrites/34.98kqueries. Five hot scans explained11.41Mreads;
3counts6.70M. Rolling24h is not a current UTC/account quota measurement.
FreeD1allowance5Mreads/100kwrites/account/day,00UTC=05:30IST reset. No fixed number
of imports/day can be claimed. Direct Wrangler analytics401; authenticated dashboard
provided the evidence. Do not infer all Cloudflare auth is broken from that.

Previously authorized incoming46deployment is preserved: scheduler
3150a352-0013-4151-a93a-00d6266b9b46, mainWorker1dc0eced-83ac-4312-8d40-73aa6124cba5.
An unfinished manual review fences automatic incoming; do not cancel/apply it to
manufacture latency evidence. User permits linking exactly one unlinked local
sameepisode/movie watch within6h, retaining local date; ambiguous matchesreview.
Active Free10msCPU/real-watch latency/new hosted quota cost remain unproven;
earlier3ms was paused idle only. Before authorized rollout: validated backup,
quota/auth/schema checks, additive migrations before dependent code, preserve
owner review and verify actual metrics. No new hosted writes just for tests.

##63cold-process approved-import recovery — runtime pending

Persisted approval existed but resume required already-loaded status/review, so a
cold launch duringD1quota owned no retry timer.63adds a retained GET-only bootstrap:
wait typed reset/providerRetry-After, check current connection/exact reviewed run
and approval after every await, then use the existing paced worker. Six failed
recovery attempts/auth/account/review changes stop; Pause clearsapproval and cancels
restoration; background preservesapproval. Status transport keeps typed errors.
UI shows restoration/cooldown/Pause without fabricatedcounts/percentage before
review loads. Debug-only coldquota fixture starts a20srefusal; actual UI test
checks nofakeprogress, tabcontinuation, automaticrecovery andPause.

Eight controller cases plusURLProtocolcase cover status/reviewquota, Retry-After,
Pause, mismatchedreview/disconnection, latecallback, boundedoutage, background/
foreground and expiredAccess. Self-reviewed syntax only until CM63results.

##64workspace consistency — reproduced API race, native runtime pending

An isolated real D1-driver/API characterization reads titles, commits fictional
external movie/watch, then reads events:1watch refers to missing earlierparent.
Fresh titles resolve it. This proves a possible interleaving, not hosted data loss.
64validates parent titles and episode ownership after uniqueIDs; one full GET
snapshot retry on typed incompleteness. Persistent badpages/quota preserve last
complete diary/cache; no rowdrop/mutationretry. Corecase plus4URLProtocoltests
cover reference validity, transient success, bounded persistentfailure/cache,
quota and signoutduringheldretry.408backendtests/checkpass; macOS64stillpending.
This protects references, not a transactionally versioned snapshot of every value.

64also fences Pause/cancellation immediately after a held recovery GET. Previously
apply/scan checked Pause before that await but could begin one extraPOST after it.
New held-read regressions assert no additional apply after Pause/background and
no scan-step after Pause/cancellation; background approval still resumes only after
foreground read-back. This source-confirmed race is repaired in the local draft,
not claimed as native runtime evidence. Four added cases bring native source236.
Swift grammar/YAML/Bash checks pass; no backend rerun needed for this native-only
follow-up.63remains frozen on its separate running source. Matching already-complete runs
are also accepted via GET without replaying a lost final receipt, clearing the
persisted approval and showing the confirmed completed state. Its regression
requires zero apply requests.

## Exact next work

1. Monitor GHA62and CM63. Do not restart a failing run unchanged. Read concrete
   compiler/test logs before repair. Download/verify passed artifacts/screenshots.
2. If63passes, verify full source/gates and keep GHA62running independently;
   do not cancel it merely to promote a newer build.64has its own macOSgate next.
3. Finish isolated native data/logic/quality checks and current parity evidence.
   Avoid broad unmeasured refactors or new features while stability is under test.
4. Remaining real-phone checks: slow/reversing compactheader, barphysics/root/
   controlgestures, glassdetents/contrast, largeDynamicType/VoiceOver, coldlock/
   offline/accountswitch, large-library responsiveness/battery/haptics.

## Build/test/resume commands and safety

Repo C:/Users/Amit Singh/Documents/ChatGPT/Track Everything/TwilDiary.
Usegit status/log-20, gh run list --branchios-native, gh run view/log-failed,
gh run download. AddC:/Program Files/GitHub CLItoPATHifneeded. Node24.21installed.
Windows:python.local/validate58.py (grammar only); python-munittestdiscover-sios/tools
-p'test_*.py'; npmtest/API SQLitefixtures; npmruncheck; npmrunbuildforWorker.
Do not run PWA/browserUItests. Mac:ios/scripts/xcodegen.sh thenios/scripts/ci.sh
stages via codemagic.yaml/.github/workflows/ios.yml. Official complete CM
check must match exactSHA; verify-codemagic.py before fast-forwardstablebranch.

No secrets/.dev.vars/SQLbackups/privatevideos/.localin commits/output. No mainpush,
force-push, unapprovedirreversibledatachange, signing/AppStore action. Update this
file before meaningfulstep10commits. User requests autonomouswork; proceed with
reversible authorized fixes and tests, report material results concisely.
