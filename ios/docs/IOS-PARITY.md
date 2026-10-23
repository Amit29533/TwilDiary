# Native parity status — work in progress

Product source: the web app under /preview at b43454e. Active native source: Amit29533/TwilDiary, ios-native, ios/. No hosted backend changes are deployed by this work.

This is an interim gap list, not final parity acceptance. Run 40020975007 passed 13 core, 8 endpoint/session and 5 browsing UI tests with zero warnings. Screenshot review confirms the corrected single bar, poster bounds, theme colors, Stats range fill and series episode pieces; movie progress remains continuous. The title comparison still shows broader layout differences. Build-9 cache/concurrency work is awaiting CI. Debug fixtures are read-only for mutations; these UI tests establish navigation/browsing, not complete write-flow coverage.

| Screen / area | Native work present | Remaining parity / validation |
| --- | --- | --- |
| Shell | Fixed native headers, web vector icons, five native tab navigation stacks, six accents, single custom capsule | Reduced transparency, gestures and physical-device timing |
| Home | Continue cards, shortcuts, week metrics/day links, planned random pick, upcoming air dates, recent history | Full long-text/empty/error states and watch/Undo interaction tests; lower-page spacing review |
| Library | Categories, status/genre/disk search, public ratings, grid/list/genre layouts, Queue shortcut, Trash link | Bulk selection, independent composed Queue/favorite filters, shelf ordering/unclassified rows, provider-rating failures and all-size review |
| Title movie/show/anime | Clear art, personal/public ratings, status transactions, quick watch, season selection, screenshot-tested per-episode pieces, episode window/expansion, collapsed notes and locations | Interactive individual episode rows, spoiler reveal policy, date/rewatch editing, range editing, full header/panel layout alignment and transaction UI regression |
| Catalog review | Authenticated browse, allowed category choice, import, existing/trashed identity handling | Season preview and fixture-backed import/retry/conflict UI coverage |
| Explore | Discover type/sort, paged grid and online search | Source shelves, complete provider filters, genre discovery and surprise-pick parity |
| Cast/person | Cast scroller, person biography and searchable typed filmography | Remaining filters/shelf layout, loading/error/empty visual states |
| Glance | Categories/search, remaining-time metadata, quick +/- and swipe action | Waiting-for-new-episodes section, ordering, exact scroll retention/Undo and real-phone gesture checks |
| Stats | Period/menu shared selection, original range bar, current streak/heatmap, backlog counts, genre shares, basic chart drilldown | Average/comparison, hourly/monthly/zero-day buckets, longest/active streaks, backlog runtime/in-progress/stale titles and full date-zone fixtures |
| History | Search, date presets/range/undated, title navigation and chronological ordering | Watch date/rewatch editing, deletion/Undo interactions and grouped history parity |
| Files & drives | Saved drives, title/path/evidence display | Disk Map geometry, location editing, mismatch-review UI and scanner state management |
| Trash | List/empty and versioned restore | Permanent-delete/empty-trash flows and conflict/Undo UI tests |
| More/settings | Themes, public TMDB/Trakt preference, files/history/trash, sign-out, attribution | Tracking/region/default-date/rating-scale options, cache clearing, backups/import/export and complete About UI |
| TMDB setup | Existing backend metadata APIs consumed | Connection/status/credential setup UI |
| Trakt | Existing server connection remains authoritative | Native sign-in, scan/review/per-item directions/apply/cancel/conflicts and fixture sync matrix; no account writes are tested here |
| Offline/auth | Keychain credential, restricted API transport, session independent of D1 quota, atomic paginated reload, retry identities | Durable protected cache/outbox and process-relaunch recovery; real iPhone login in LiveContainer |

PC-only boundary: drive scanning and ingestion execute on the Windows host. Native iPhone screens must show the same saved mappings, scanner evidence and mismatch data as the mobile web product; the phone cannot scan arbitrary Windows volumes. No fake scan or fake successful provider sync is implemented.

Primary web references: docs/reference/chromium-win32 (70 enumerated states at 390x844). Secondary matching-content references: docs/reference/chromium-win32-402x778, excluding only documented iPhone 17 Pro OS insets for comparison. Neither set alone establishes native pixel parity. Physical-device checks are in DEVICE-CHECKS.md.
