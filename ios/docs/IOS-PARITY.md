# Native parity status — work in progress

Product source: the web /preview code at b43454e. Active native source: Amit29533/TwilDiary → ios-native → ios/. No hosted changes or deployments.

Latest run 40035195084 compiled both targets with zero warnings: 25 core and 32 native unit tests passed, 7/9 UI passed. Files dismissal and Trakt conflict accessibility failed. Build 8 (40020975007) remains the last complete green run. The new screenshots are diagnostic evidence, not release acceptance. Pixel parity remains unfinished.

| Screen / area | Native work present | Remaining parity / validation |
| --- | --- | --- |
| Shell | Fixed headers, source vector icons, per-tab stacks, six accents, floating capsule | All-size spacing, transparency, keyboard and physical gesture/timing review |
| Home | Continue cards, shortcuts, weekly metrics/day links, planned pick, upcoming episodes, history | Watch/Undo UI tests; empty/error/long text and lower-page comparison |
| Library | Category/status/genre/disk search; public ratings; grid/list/ordered genre shelves; reviewed bulk Queue/favorite/status/Trash | Composed Queue/favorite/tag/availability filter UI, sorting coverage, provider failures and all-size review |
| Title movie/show/anime | Art/ratings/status; episode pieces versus continuous movie; aired prefix slider plans; dates/rewatches; versioned Undo; spoiler reveal; notes/locations collapsed | End-to-end transaction tests and complete header/panel spacing/typography comparisons |
| Catalog | Combined search with IMDb identity normalization/local matches/paging (build 15 awaiting CI), review/import, identity/category handling, cast | Season preview, fixture-backed import/retry/conflict UI coverage |
| Explore | Build 15 (awaiting CI): source daily pick/four shelves/section grids, unwatched list, Trakt recommendations, genre/year/rating/sort, paging/retry | Full native screenshot/all-size/interaction acceptance; provider connection/failure visual coverage |
| Cast/person | Biography, searchable movie/TV filmography | Filters/shelves, loading/error/empty states and visual alignment |
| Glance | Source-order watching cards; category/search; remaining time; quick +/- and swipe | Watch/Undo and scroll-retention regression, real-device gesture checks. Current source has no waiting section or sort control. |
| Stats | 17 web golden scenarios pass; average/comparison; zero/day/aggregate/year-month buckets; streaks/84-day heatmap; backlog runtime/stale titles; genre shares; accessible bucket drilldown | Full visual/all-size review. Calendar collision, Home→Today, empty bucket and undated history UI tests pass. Current source has no hourly chart. |
| History | Search, presets/range/undated, title navigation, chronological ordering | Full source grouping/filter edge cases and transaction entry-point review |
| Files & drives | Device/volume summaries, filters, mapped folders/evidence/path copy, disk Library link; paginated scanner review/match | Navigation return fix, visual comparison and error/retry/empty/paging UI tests. PC creates scans; phone reviews existing scan data. |
| Trash | Shared Library search/layout, reviewed restore/delete/Empty Trash | Queue→Trash→restore→delete UI passed. More stale/conflict/empty/error coverage; native adds confirmation before explicit Empty Trash command. |
| More/settings | Source tracking/region/theming/public ratings, export/storage/About; TMDB status/PC credential boundary | Every option interaction and visual regression. Current source has no import or automatic-backup settings. |
| Trakt | Existing server PKCE auth, status/scan/step/pause/cancel, filters/paging/cooldown, safe apply and explicit local/Trakt/skip choice; unit/transport tests pass | Conflict action accessibility fix, full direction/type UI matrix and actual device/provider authentication. Synthetic provider makes no HTTP requests. |
| Offline/auth | Keychain; restricted transport; complete atomic reload; encrypted owner-scoped snapshot; generation guards; retained retry identities | Real-device login/relaunch/network transitions. Current web requires reconnect before writes; no offline outbox is a parity requirement. |

PC-only boundary: scanning/ingestion and provider credential editing remain on the existing Windows/server side, as on mobile web. Native presents saved mappings, scanner evidence and reviewed resolution. No arbitrary Windows-volume scanning from the phone, bundled service token or fake provider success.

Primary references: reference/chromium-win32 (70 states, 390×844). Secondary: reference/chromium-win32-402x778 (matching iPhone 17 Pro content excluding documented 62pt top/34pt bottom system insets). DEVICE-CHECKS.md records what CI cannot establish.
