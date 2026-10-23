# Native architecture

The native application is a SwiftUI client of the existing Cloudflare Worker and D1 API. Swift 6 strict concurrency, Observation and iOS 26+ are used; the user confirmed an iOS 27 phone. XcodeGen generates the project in macOS CI. There are no third-party Swift dependencies.

DiaryStore is main-actor isolated. URLSession uses a restricted HTTPS backend and explicit Access credentials stored in Keychain. Sign-in uses a non-persistent WKWebView only for the existing Cloudflare login flow; all product screens are native SwiftUI. The database-independent session endpoint validates login before loading complete paginated workspace snapshots. Partial reloads never replace a valid snapshot. Mutation identities are retained for uncertain retries; version checks and server Undo receipts preserve concurrency semantics. Durable offline persistence is still outstanding.

TwilDiaryCore contains Codable API projections, calendar/progress calculations and catalog identities. Movie and TV provider IDs remain distinct. Public TMDB/Trakt ratings never fall back to personal ratings. Catalog screens review before import, and production requests use authenticated server routes.

AppRouter owns tab selection and independent navigation paths. The custom capsule navigation, opaque headers and Lucide vector PDF assets are derived from the web source. Assets are cached with NSCache. SwiftUI AsyncImage handles remote images. Remaining-time shadow is limited to the remaining-time text.

Debug --ui-testing selects an isolated synthetic workspace and provider fixtures. Release builds cannot activate that fixture mode. The web reference uses a disposable local D1 instance on port 5193 and blocks provider/hosted requests. Existing web files and deployment workflows are unchanged.

CI builds simulator/test targets, runs core and session tests and XCUITests, exports retained screenshot attachments and builds an unsigned physical-device IPA. Native visual parity and offline/provider management work are explicitly tracked in PROGRESS.md; this is not a finished parity claim.
