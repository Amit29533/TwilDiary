# Native TwilDiary progress

## Resume first

Current step: **10 — parity, stabilization and release hardening**. The app is
not declared finished. The complete older notes are preserved in
[ios/docs/BUILD-HISTORY-THROUGH-NATIVE54.md](ios/docs/BUILD-HISTORY-THROUGH-NATIVE54.md);
read specific historical sections only when needed. ROADMAP.md remains the
original10-step checklist. Owner subsequently prioritized building actual
features over repeating procedural gates.

At every session: read this file/ROADMAP, git status/log, current provider
results and actual artifacts; reconcile before editing. Notes and source test
counts never substitute for runtime evidence. No Mac/Xcode/Swift runtime is
available locally; Windows checks grammar/YAML/Bash/Python only.

## Three distinct source states

| Track | Exact source | Current evidence |
| --- | --- | --- |
| GitHub ios-native, native54 | d59f55e5fa574382b067477f6b4fb079690507a8 | Complete Codemagic54 passed. GHA54attempt1 stopped on an incompatible restored pre-split Core module; cache invalidated, same-source attempt2 requested. |
| Codemagic candidate codex/ios-ci-next, native55 | ae2cfdcccbe58fbd2f353abbbfabb4fa67b59766 | Warning-free simulator build and all194native/all8focused/all10early cases pass. Full51/extra-phone/Release still running. |
| Local codex/ios-carousel-parity, native56 |9e30c49 plus this documentation update; use git rev-parse HEAD| Carousel batch,196native/52primary/9focused source cases; uncompiled. |

Native source is **Amit29533/TwilDiary**, /ios. Original web /preview source
and user-directed native changes are authoritative. The old TwilDiary-iOS repo
is preserved historical source, not the active build or proof. No push to main,
force push, signing setup or new backend deploy is part of current work.

Only a complete official Codemagic regression success for an exact SHA may
promote that SHA to ios-native. GitHub then independently runs the complete
suite before stable IPA publication. The differently named device-diagnostic
workflow cannot satisfy promotion. Candidate source on GitHub is needed for
Codemagic checkout; it is not stable publication. Preserve the frozen55ref
while it runs. Do not accidentally send local56with54/55acceptance.

## Last complete acceptance — native54

Codemagic54 **6adde71f4a72334e32e4fa14**:
https://codemagic.io/app/6adcc927390bc3069c9e5490/build/6adde71f4a72334e32e4fa14

- Zero simulator/device/compiler/tool warnings and zero failures.
-188native tests,8focused UI,10early UI, all51primary UI, and3layout cases
  on each extra phone (iPhone17e/17ProMax) pass.
- Actual unsigned physical Release/resource gate passes. IPA independently
  verified: hash, ZIP CRC, arm64/iPhoneOS/minOS26/build54, system-encryption
  flag and no fixture/TestSupport JSON. No provider uptime/phone FPS claim.
- Official same-SHA check was verified before fast-forwarding ios-native.
  Independent GitHub54 **40192486938**:
  https://github.com/Amit29533/TwilDiary/actions/runs/40192486938
  Candidate-proof passes. Attempt1failed simulator test compilation: RandomPickScopeTests saw both old Core.SampleWorkspace and new TestSupport.SampleWorkspace, although Core source no longer contains that helper and clean CM54/55compile. Actual log restored pre-split native cache9471189867. Invalidating the13matching old native cache entries prevents fallback to another pre-split module; rerun failed macOS job on unchanged54source after that environment repair (attempt2queued/running). This is not yet an
  independently green stable release. Read its latest jobs before changing it.

Delivered: **D:/Downloads/TwilDiary-native54-codemagic-passed.ipa**
(5,616,221bytes), SHA256
71c8597fdc218ff2370148cbf733d66376304ef2987293486eac6e92437a9798.
Metadata/hash beside it; committed proof:
ios/docs/releases/native54-codemagic-candidate.json.
Original diagnostics archive: D:/Downloads/TwilDiary_21_artifacts.zip
(654,763,214bytes, CRC pass), logs/screens extracted to .local/codemagic54-diagnostics.

Six original primary PNGs, original attachment IDs/test/device/hash scope:
ios/docs/screenshots/step-10/build-54-codemagic-passed.
Visually inspected .local/native54-passed-overview.png and Home/Glance
side-by-side references. Matching402x778 usable canvases use declared scale3
and top62/bottom34OS-only insets, with no stretching. Font weights/metrics,
small spacing/card padding and requested native controls differ; no claim of
pixel-identical parity. Comparison outputs remain .local/native54-*-web-comparison.png.

Owner asked which IPA to try; directed them explicitly to native54, with History/Explore Back, slow/reverse compact-header scroll and the visible watched-episode Log rewatch action. No new phone result yet. Native53diagnostic remains available but is superseded for this check. Earlier native40 owner feedback confirms
Information sentiments/dismissal, incoming-switch persistence, Notes targeting,
watch/Undo, keyboard-safe search, tab scrub and offline navigation.

## Native55 — isolated cache optimization, running

CM55 **6addf45f4a72334e32e4fd86**:
https://codemagic.io/app/6adcc927390bc3069c9e5490/build/6addf45f4a72334e32e4fd86
Actual checkoutae2cfdc was read in its source log. Startup proof:
.local/codemagic55-started.jpg. This source has194native/51primary/8focused
cases. All194native cases, including five cache concurrency tests and the store sign-out interleaving, now pass with warning-free simulator compilation; full UI/Release acceptance remains pending.

Production changes: WorkspaceCache validation/JSON/AES preparation moves into a
utility detached task with immutable Sendable inputs. Cancellation reaches the
worker; newer sync/async saves and removeAll invalidate its ticket before the
atomic MainActor protected-file commit. The store rechecks session/snapshot
following the await and treats cache failure as optional. Same format/owner
scope/bounds/protection/backup exclusion; no offline write outbox.

Six new deterministic cache/store cases cover off-main work, removal/sign-out,
newer-save wins, cancellation preserving the previous cache and over-limit
preservation. Tests use temporary paths/injected keys. Scale test prints total
async latency separately from sync load/index. Cold load, Keychain lookup and
final protected commit intentionally remain synchronous. Prior native52M2
10k-watch measurements: save66.66ms/load56.28ms/index25.47ms. No55speed claim
until actual macOS measurements. Native55M2 diagnostic now reports10k events: sync save139.71ms, async total77.56ms, sync load75.51ms, index45.12ms (1k9.75/9.80/8.45/4.10ms). These are cross-run-noisy diagnostics; the gated test proves off-main preparation, not a phone speedup/FPS. All13CI-tool checks pass locally.

## Native56 — separate local carousel and card-parity batch

Direct audit confirmed web ContinueCarousel.svelte has guarded5second rotation,
wrap previous/next, pause and retained identity, while native Home had only
snapping/manual swipe. Prepared ContinueWatchingCarousel retains card geometry,
cover/watch actions and root gesture exclusion. It adds visibility/scene/tab/
path/write/drag/motion/VoiceOver/open-controls guards, interaction cooldown,
scene identity/pause restoration and an ID/session-keyed cancelled task.

A small rounded top-corner popover exposes previous/next/pause rather than the
web's hover/focus-only controls. This deliberate native adaptation is documented
in IOS-PARITY.md. Two policy tests and one actual automatic/pause/tab-return
UI test are added; Home search explicitly suppresses automatic movement while open; the new case joins the focused gate (9cases, all old8remain)
so failures stop before the long suite. Source196native/52primary; local
.local/validate56.py passes, **no56Swift compile/runtime/screenshots yet**.

Direct54web/native screenshot comparison also confirmed the Glance name/time gap: a44pt Menu occupied the title HStack height although the web absolutely positions its menu. Prepared56extracts that menu into an overlay, retains every existing action/Notes target, reserves title space, and matches the web17pt name/3pt copy gap. The web also uses44pt stepper/Home hit areas around32–36pt painted buttons. Native controls were only32–36pt;56adds44pt content shapes without enlarging the card row, fixes Home pending opacity by keeping tint inside the disabled-aware press style, and adds real hit-frame assertions to the existing toast/cover/menu UI case. No watch/menu/state rules changed. These layout/input changes are uncompiled56, absent from the owner's54IPA, and require fresh screenshots/full regression.

## Owner phone checklist

Owner requested the complete device test list. Wrote ios/docs/DEVICE-TEST-BUILD54.md
and D:/Downloads/TwilDiary-native54-iPhone-checklist.md with41numbered checks,
prioritized old UI issues, watch/rewatch/Undo/date/season rules, all screens,
reviewed/automatic Trakt distinction and real-phone offline/accessibility/performance.
Explicitly excludes55cache and56carousel features from54expectations. Phone results
remain pending; do not treat sending a checklist as a pass.

## GitHub54 cache repair / native56future protection

GHA54attempt1fails with ambiguous SampleWorkspace.make and two downstream key-path inference errors; actual notes identify a removed Core symbol plus the new Support symbol. Source is unchanged from fully passed clean CM54. Saved .local/github54-{failed,all}.log and exact restored cache list. Clear only rebuildable native-macos26-X64-xcode26.6 caches on ios-native (not diary/hosted data), then rerun the failed54job once. This is a changed cache environment, not retrying an unexplained failure. Future56restore/save keys now also include the Package.swift graph hash before the source hash, and fallback is restricted to the same graph; it cannot reuse the old target/resource layout. Current55CMref remains frozen.

## Exact next actions

1. Inspect55compiler and all194native cases, especially new cache interleavings.
   Read54GitHub focused/full/extra-phone evidence independently. Do not retry
   unchanged failures or promote a diagnostic-only success.
2. If55fullgreen, download/verify current artifacts and measurements, then
   hold it while54GitHub is collecting independent evidence; do not cancel54by pushing55. Promote only after the active GitHub run resolves, or batch its accepted changes into the later fully-qualified56source. A red55requires inspecting concrete logs first.
3. Continue56self-review while55runs. New56carousel UI test resolves its identified container independent of UIKit accessibility element type, rejects nil selection and also requires exactly one fully visible/hittable cover after movement. Keep56off the candidate ref until ready;
   then run its own complete Codemagic validation. Verify real automatic/pause,
   restoration, card/root gestures and current screenshots; no hidden assertion
   removal or timeouts-until-green.
4. Finish remaining visual/privacy/accessibility/performance and source parity
   gaps. Preserve source/run identity in every screenshot and IPA delivered.

## Remaining / blocked evidence

- Full independent GitHub54acceptance, then55/56complete provider runs.
- Owner phone: compact-header threshold/reverse scroll, bar/gesture timing,
  glass contrast/transparency, haptics, VoiceOver and large Dynamic Type.
  CI cannot establish tactile smoothness or battery use.
- Cold protected cache reads, workspace indexing/first projections and remote
  poster downsampling remain performance work. Existing NSCache/bounded card,
  discovery/person/community caches and projection memoization already exist;
  blanket uncached-image claims were false. No broad actor rewrite.
- PRIVACY-AUDIT.md records actual app-only preferences, local logo-tap uptime,
  fixed-backend/Trakt/TMDB flows and unverified provider/log retention. Required-
  reason manifest packaging/final labels and optional all-window app-switcher
  cover remain open. Do not claim D1-backed diary data is zero collection.
- Native54Home/Glance/other screen comparisons are not pixel-identical.
  Source references:80primary390x844 states and secondary402x778 canvases.
  See IOS-PARITY.md, QUALITY-AND-REMAINING.md, REVIEW-T24-T37.md and DEVICE-CHECKS.md.
- Backend incoming46is deployed,38focused/391complete Node tests passed before
  that authorized rollout. Scheduler3150a352-0013-4151-a93a-00d6266b9b46;
  main Worker1dc0eced-83ac-4312-8d40-73aa6124cba5. A preserved active manual
  review fences automatic imports; do not cancel/apply it just to manufacture
  a timing result. Real completed-watch import latency and active Free10msCPU/
  D1 usage are unproved. The earlier3ms was the paused idle path only.
- Unique single local watch within6h links a Trakt play preserving local date;
  ambiguous matches require review. Existing tests cover cursor quarantine,
  generation/account/title/event fences and revoked/Trash replay protection.

## Build/test and safety

XcodeGen ios/project.yml; Swift6strict concurrency/iOS26+ for owner's iOS27.
CI pins Xcode26.6, iOS26.5 iPhone17Pro,17e,17ProMax; GHA macos-26-intel,
CM mac_mini_m2. No hand-written pbxproj. No third-party Swift dependencies.
Use ios/scripts/ci.sh and codemagic.yaml; only macOS runs Swift.

Windows tools: C:/Program Files/GitHub CLI/gh.exe; python .local/validate56.py
for current9-case source; earlier55uses validate48.py/8cases. The unchanged
TraktSignIn parser limitation matches compiled47bytes; grammar is not typing.
Use python -B ios/tools/test_verify_codemagic.py, test_verify_release_resources.py,
test_run_bounded.py and test_verify_build_log.py (13cases total).
PIL/ffmpeg runtime: C:/Users/Amit Singh/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe.

Cua browser working, existing tab1=CM55, tab2=GitHub, tab3=passed53diagnostic.
Normal authenticated artifact link + download event works; downloadMedia times
out/unauthenticated URL401. A large archive's event may time out yet complete
normally in D:/Downloads: inspect the actual named file before retrying. Never
extract browser cookies/tokens. Re-read cua documentation after compaction.

No secrets, SQL backups, .dev.vars or .local/incoming-secrets in commits/output.
Hosted data stays read-only in current native work; local/fixtures for tests.
No new deployments, migrations, review destruction, signing or App Store actions.
Commit format step N: <what>. Update this current file before meaningful commits.
