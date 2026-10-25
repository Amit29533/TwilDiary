# Bulk import reliability and D1 read budget

## Observed on 25 October 2026

Owner reported a roughly2,000-change review stopping without automatic recovery,
stopping when leaving Trakt, missing progress, and reaching a database limit after
roughly600imports. The opened Cloudflare D1 dashboard was inspected read-only.
Its **Last24hours** window showed12.23million rows read,36,560rows written,
34,980queries and12.35MBstorage. This rolling window is not the current UTC
quota day or all databases in the account.

The displayed query costs identify repeated review scans:

| Query | Calls | Rows read |
| --- | ---: | ---: |
| Choose next ready change, ordered, without SQL LIMIT |627|2.30M|
| Count pending links |1,668|2.62M|
| Count safe pending proposals |1,480|1.97M|
| Group all proposal states |1,202|2.11M|
| Order remote planning records with LIMIT/OFFSET |552|2.41M|

Calling Drizzle `.get()` did not put LIMIT1into the first SQL statement. Counting
an indexed range still reads that entire range. Therefore600imported records
can exhaust a read allowance even when write usage remains below its allowance.
Cloudflare's published free allowance is5million reads/100,000writes per
account/day, resetting00:00UTC (05:30India time). Indexes and aggregate triggers
also have write costs; an import count is not a database billing unit.

Sources: [D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/),
[D1 analytics](https://developers.cloudflare.com/d1/observability/metrics-analytics/).

## Native58 candidate

- Store-owned approved bulk task survives leaving the Trakt view. A saved run ID
  permits the same approved review to resume after foreground/relaunch checks.
- User Pause revokes automatic continuation. iOS background suspension preserves
  that approval and stops requests; the app reconciles on return. This does not
  promise continuous background execution or an offline write queue.
- Removed the100request loop limit. Pacing is1second between successful bulk
  steps and0.5seconds during a scan. Server progress, conflicts and explicit
  Pause determine when to stop; two unchanged responses stop a stuck job.
- Typed network/provider errors retain Retry-After. A review GET reconciles each
  interrupted operation before further writes. Six consecutive failed recovery
  attempts stop with a resumable error. Account/snapshot conflicts require review.
- A D1 daily limit waits for its actual reset while the app remains open. Closing
  the app preserves the approved run; reopening checks that same review. No retry
  loop can bypass an exhausted daily allowance.
- Global applied/skipped/remaining counts and percentage, known-stage scan
  progress, cooldown details, Pause/Resume and rounded review actions.

## Additive backend candidate

Migration0014backfills at most40aggregate buckets per existing review. SQLite
triggers update those buckets in the change transaction. Status reads those
buckets rather than three full scans after every operation. The ready-pick
partial expression index matches the existing dependency order; the selection
now has an explicit LIMIT1. A partial ordered planning index removes repeated
sorting, although existing OFFSET checkpoints still incur skipped-row reads.

An explicit Trakt429rejection remains pending after cooldown only when no
uncertain-send flag is present. Lost/accepted-but-unconfirmed sends retain their
existing reconciliation guards. No blind watch POST replay was introduced.

Local SQLite regressions cover2,000changes,600applies/skips, retry/reclassification,
rollback, cascade cleanup, existing-review backfill and EXPLAIN QUERY PLAN for
both hot ordered queries. The full396Node tests pass. Native212test source and
17focused UI cases require the next macOS run; local grammar is not compilation.

## Rollout and evidence still required

**Not deployed; hosted migration not applied.** No hosted diary mutation or SQL
usage probe was run during this investigation. The daily allowance is exhausted.
Before rollout: complete candidate CI, preserve the existing production backup,
validate migration with Wrangler's local D1 runtime, then apply the additive
migration before deploying code that reads the aggregate table. Verify existing
review counts before resuming the owner's unfinished review. Inspect real D1
read/write metadata afterward; local EXPLAIN proves index selection, not hosted
metering or a numerical free-plan capacity guarantee.

Wrangler OAuth's direct analytics request returned401during the audit; the
authenticated dashboard supplied the evidence above. No credentials are stored
in this document, screenshots, fixtures or test logs.
