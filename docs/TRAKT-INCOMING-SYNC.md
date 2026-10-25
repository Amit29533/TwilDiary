# Incoming Trakt watches on Free

Prepared 2026-10-25 on `ios-native`. **Not deployed or enabled on hosted D1.**
This is the owner's requested extension of the earlier manual-only contract.
Connecting Trakt still enables nothing automatically.

## Flow

Trakt → minute activity check → bounded incoming history import → existing D1 →
existing diary API when iOS opens/resumes. The upstream playback application is
outside this implementation; it only consumes Trakt's recorded history. This is
completed-watch sync, not live playback position. Ratings, watchlists, conflicts,
deletions and old bulk history retain the reviewed two-way sync.

One invocation fetches at most one ten-item history page and processes at most one
viewing or public metadata phase. Movie/episode activity timestamps are checked
each minute. Unchanged activity avoids history requests, except an hourly overlap
rescan. New activity interrupts older pagination; recent watches take priority
over old backlog. An unfamiliar title needs a title-metadata tick, then a selected
season tick for series, then its viewing. Mapped watches normally need the next
successful tick; cold metadata can need two additional ticks. Trakt availability,
scheduling, provider errors, quota and backlog prevent a hard 60-second SLA.

History uses a fixed seven-day overlapping window and durable remote IDs. A new
backdated play would be missed by a naive `watched_at > last_check` cursor. Run
reviewed sync once for existing history, and for bulk imports older than seven
days. Concurrent changes restart from the newest page; malformed/partial pages
never advance checkpoints. A scan is limited to 200 pages/2,000 recent plays;
larger batches need manual sync.

## Safeguards

- Default off. Owner-authenticated `GET/PUT /api/trakt/incoming` reads/configures it.
  No public trigger, Access bypass, bundled bearer or new service token.
- Small `workers/trakt-incoming` entry shares the existing D1/encrypted OAuth
  connection and refresh lease; it does not load Svelte SSR or copy the diary.
- Durable 50-second invocation lease. Every metadata/enqueue/watch write checks
  enabled generation, account/client, current connection version and absence of
  an active manual build/review/apply. Disable/disconnect fence late callbacks.
- Atomic viewing/status/acknowledgement batches. Unique operation/remote IDs and
  retained acknowledgements survive Undo/purge. Revoked plays are never revived.
- Trash/demo excluded; notes, score, favorites, Queue and Dropped status preserved.
  Equal local viewings need reviewed linking instead of a duplicate play.
  Unmatched IDs/oversized metadata remain in review; no fuzzy name matching.
- Metadata only inserts missing records. At most 200 season summaries or selected
  episodes, 100 KB normalized season payload. Larger metadata uses manual sync.
- Conservative daily 5,000-unit record/metadata write budget, including estimated
  index amplification. Fixed lease/checkpoint overhead is separate. Failed
  attempts can conservatively consume units. Reset at midnight UTC.
- Trakt responses capped at 32 KB here, TMDB at 100 KB; manual clients retain
  their 2 MB cap. Honor Retry-After, otherwise exponential backoff up to an hour
  with positive jitter for rate limits that omit a valid Retry-After header.
  D1 quota backoff persists until UTC reset if D1 still permits that write. If
  exhausted D1 refuses it too, later ticks can only fail safely and retry.
- Enumerated log outcomes only; no raw exceptions, SQL/parameters, provider
  bodies, account IDs or credentials. Status exposes health/counts, not payloads.
- iOS foreground reads coalesce rapid scene changes and wait for pending writes.
  No phone background timer or requirement to leave the app running.

## Free limits and remaining measurements

Official limits checked 2026-10-25:

| Resource        | Free allowance                                         | Design                                                             |
| --------------- | ------------------------------------------------------ | ------------------------------------------------------------------ |
| Cron            | Every minute supported                                 | 1,440 invocations/day                                              |
| CPU             | **10 ms per Cron invocation**                          | Small bounded phase; production CPU not yet proven                 |
| Worker requests | 100,000/day, account shared                            | Minute checks plus normal app traffic                              |
| D1              | 5m rows read / 100k rows written daily, account shared | Indexed singleton/provider/episode/due-job lookups; bounded writes |
| Subrequests     | 50/invocation                                          | Ten-item enqueue + one viewing/metadata phase                      |

SQLite correctness/query plans and a Wrangler dry run do **not** prove the 10 ms
CPU budget. After explicit deployment approval, measure idle, new-watch, token
refresh and cold-metadata CPU, plus actual D1 rows read/written including indexes.
Other account traffic shares the allowance. If cold metadata exceeds Free CPU,
leave those entries for manual metadata while retaining the cheap matched-watch
minute path. Never silently switch to paid; 15-minute wall time is not CPU time.

Sources: [Workers limits](https://developers.cloudflare.com/workers/platform/limits/),
[D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/),
[Cron configuration](https://developers.cloudflare.com/workers/configuration/cron-triggers/),
[Trakt activity/history contract](https://github.com/trakt/trakt-api/blob/master/projects/api/src/contracts/sync/index.ts),
[current Trakt rate-limit guide](https://github.com/trakt/trakt-api/blob/master/projects/developer/src/lib/guides/rate-limiting.md).

## Source and validation

`src/lib/server/trakt-incoming.ts`, owner API route, worker entry/config and
generated `0013_trakt_incoming.sql`/Drizzle schema/snapshot/journal. Migration adds
three tables, one due-job index and a provider-tombstone trigger on title purge;
existing diary tables are not rewritten. Manually re-adding a title explicitly
allows future incoming watches again; a missing purged title is never auto-added.
Config has an all-zero local DB ID. No deployment workflow/signing/credentials.
`tests/unit/trakt-incoming.test.ts` uses disposable SQLite and mocked Trakt/TMDB.
Native service/panel/foreground tests belong to the next iOS validation batch.

```powershell
node --test tests/unit/trakt-incoming.test.ts
npm test
npm run check
npx tsc -p workers/trakt-incoming/tsconfig.json
npx wrangler deploy --dry-run --config workers/trakt-incoming/wrangler.jsonc
```

## Deployment review — pending owner approval

1. Verify actual database/binding and pending migrations; take a recoverable
   backup and apply only the reviewed additive migration to existing D1.
2. Release the incoming API with the existing Worker, retaining Access, owner and
   same-origin write checks. Existing web deployment workflows are unchanged.
3. Configure the small scheduled Worker with that same D1 and existing client ID,
   server encryption key and TMDB read token through Cloudflare secrets. No public
   route. Do not commit/print secrets or put them in CI artifacts.
4. Keep opt-in off initially; validate runtime/CPU with an isolated account. Then
   enable in iOS and check one completed play, a cold season, duplicates,
   disconnect/disable and local Undo on a phone.
5. To roll back, disable incoming first/remove its Cron. Keep acknowledgements to
   prevent replay. Existing manual sync and diary data remain available.

The owner explicitly approved this feature rollout on 2026-10-25. A complete
ignored SQL backup was downloaded/restored and existing encryption/client setup
verified without printing credentials. Only migration0013 is pending. Current
Wrangler credentials return403 on Worker deployment APIs, so no hosted migration,
secret upload, deployment or incoming enable has succeeded. Authentication recovery
is in progress; owner consent is no longer the deployment blocker.
