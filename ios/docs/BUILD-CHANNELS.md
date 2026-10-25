# Candidate and stable build tracks

Owner-directed policy, 25 October 2026:

* **Codemagic is the candidate track.** Push experiments only to
  `codex/ios-ci-next`, then run its unsigned regression workflow. Its IPA is a
  test artifact even when compilation passes. A failed focused gate stops the
  long regression; logs and screenshots remain available.
* **GitHub Actions is the stable track.** Promote the exact candidate SHA to
  `ios-native` only after the entire Codemagic workflow succeeds: units, focused
  regressions, full primary UI, both extra-phone layouts, Release packaging and
  zero build warnings. Do not rebuild different source and call it promoted.
* GitHub checks the official Codemagic GitHub App check for that exact SHA
  before allocating a macOS runner. Missing, pending, cancelled or failed
  evidence blocks promotion. A newer failed check overrides an older pass.
* GitHub independently runs the complete regression. Only its completely
  successful job publishes `TwilDiary-stable-unsigned-IPA`, with source SHA,
  both provider evidence URLs and IPA SHA256. Diagnostic screenshots/logs may
  still be published after failure; those are not release acceptance.

Candidate source still has to be stored in a GitHub branch for Codemagic to
fetch it. That branch does not trigger the stable GitHub workflow. Never push
experimental source to `main` or force-push a shared branch.

Existing native46 provider runs predate this guard and are diagnostic. Neither
is an accepted stable release. New review features are preserved on local
`codex/ios-review-pending` at `5064856`, without promotion, until current
navigation/layout regressions are closed. No build track deploys the backend
or writes the hosted diary as part of its tests.
