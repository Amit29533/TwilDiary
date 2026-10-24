import XCTest
import UIKit

@MainActor final class NativeScreensTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(mutations: Bool = false, scanner: Bool = false, ratingsUnavailable: Bool = false, titleMetadata: Bool = false, empty: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]
        if mutations || scanner { app.launchArguments.append("--ui-mutations") }
        if scanner { app.launchArguments.append("--ui-scanner") }
        if ratingsUnavailable { app.launchArguments.append("--ui-ratings-unavailable") }
        if titleMetadata { app.launchArguments.append("--ui-title-metadata") }
        if empty { app.launchArguments.append("--ui-empty") }
        app.launchEnvironment["TZ"] = "Asia/Kolkata"
        app.launch(); XCTAssertTrue(app.buttons["tab-home"].waitForExistence(timeout: 15)); return app
    }
    func testNativeTabsAndTitleNavigation() {
        let app = launch()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'complete'")).firstMatch.waitForExistence(timeout: 5))
        capture("Glance")
        app.buttons["tab-home"].tap()
        XCTAssertTrue(app.staticTexts["Pick up where you left off"].waitForExistence(timeout: 5)); capture("Home")
        app.buttons["tab-library"].tap()
        XCTAssertTrue(app.buttons["Search library"].waitForExistence(timeout: 5)); capture("Library")
        XCTAssertEqual(app.tabBars.count, 0, "The custom capsule must be the only tab bar")
        let first = app.buttons["title-after-rain"].frame, second = app.buttons["title-again"].frame, third = app.buttons["title-frieren"].frame
        XCTAssertLessThan(first.maxX, second.minX)
        XCTAssertLessThan(second.maxX, third.minX)
        XCTAssertLessThanOrEqual(third.maxX, app.frame.width - 10)
        app.buttons["title-again"].tap()
        XCTAssertTrue(app.buttons["title-personal-rating"].waitForExistence(timeout: 5))
        let track = app.sliders["episode-progress"]
        XCTAssertTrue(track.waitForExistence(timeout: 5))
        XCTAssertEqual(track.value as? String, "8 of 16 episodes watched")
        capture("Title detail")
        assertEpisodePieces(track, app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["title-quiet-orbit"].tap()
        XCTAssertTrue(app.progressIndicators["movie-progress"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["episode-progress"].exists)
        capture("Movie detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["tab-stats"].tap()
        XCTAssertTrue(app.staticTexts["Watch time"].waitForExistence(timeout: 5)); capture("Stats")
        app.buttons["tab-more"].tap()
        XCTAssertTrue(app.staticTexts["Appearance & region"].waitForExistence(timeout: 5)); capture("More")
    }
    func testEmptyDiaryScreensRetainNavigationAndSourceEmptyStates() {
        let app = launch(empty: true)
        XCTAssertTrue(app.staticTexts["A clear little corner"].waitForExistence(timeout: 5)); capture("Empty Glance")
        app.buttons["tab-home"].tap()
        XCTAssertTrue(app.staticTexts["This week"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Pick up where you left off"].exists); XCTAssertFalse(app.staticTexts["Recently watched"].exists)
        XCTAssertTrue(app.staticTexts["0m"].exists); capture("Empty Home")
        app.buttons["tab-library"].tap()
        XCTAssertTrue(app.staticTexts["Nothing here just yet"].waitForExistence(timeout: 5)); capture("Empty Library")
        app.buttons["tab-stats"].tap()
        XCTAssertTrue(app.staticTexts["Log a movie or episode to start your stats."].waitForExistence(timeout: 5)); capture("Empty Stats")
        XCTAssertTrue(app.buttons["stats-calendar"].isHittable)
    }

    func testRandomPickKeepsPlannedScopeAndLogoRerollsWithoutRepeating() {
        let app = launch(); app.buttons["tab-home"].tap()
        let planned = app.buttons["home-pick-planned"]
        for _ in 0..<8 { if planned.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(planned.isHittable); planned.tap()
        let name = app.staticTexts["random-picked-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); XCTAssertEqual(name.label, "A Quiet Orbit")
        XCTAssertFalse(app.buttons["random-pick-again"].isEnabled, "The planned fixture has only one eligible title")
        capture("Home planned random pick")
        app.buttons["Close random pick"].tap()
        let logo = app.buttons["random-pick-logo"]
        logo.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        XCTAssertTrue(name.waitForExistence(timeout: 5)); let previous = name.label
        let again = app.buttons["random-pick-again"]
        wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: again)], timeout: 5)
        again.tap()
        wait(for: [expectation(for: NSPredicate(format: "label != %@", previous), evaluatedWith: name)], timeout: 5)
        capture("Collection random pick")
        app.buttons["random-pick-open"].tap()
        XCTAssertTrue(app.buttons["title-personal-rating"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Close random pick"].exists)
    }
    func testEmptyRandomPickOpensTheWorkingAddSearch() {
        let app = launch(empty: true)
        app.buttons["random-pick-logo"].tap(withNumberOfTaps: 3, numberOfTouches: 1)
        XCTAssertTrue(app.staticTexts["Your next story starts here"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["random-pick-open"].exists); capture("Empty collection random pick")
        app.buttons["Add a title"].tap()
        XCTAssertTrue(app.textFields["Search library and online"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add manually"].exists); capture("Library add search")
        app.buttons["Close search"].tap()
        XCTAssertTrue(app.staticTexts["Nothing here just yet"].waitForExistence(timeout: 5))
    }

    func testHistoryUnknownDatesSearchPagingAndReturnKeepTheSourceFilters() {
        let app = launch(); app.buttons["tab-home"].tap()
        let history = app.buttons["All history →"]
        for _ in 0..<12 { if history.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(history.isHittable); history.tap()
        let count = app.staticTexts["history-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5)); capture("History first page")
        app.buttons["Date filters"].tap()
        let unknown = app.switches["Unknown dates only"]
        XCTAssertTrue(unknown.waitForExistence(timeout: 5)); unknown.tap()
        XCTAssertEqual(count.label, "1 watch")
        XCTAssertTrue(app.staticTexts["Watch date unknown"].waitForExistence(timeout: 5)); capture("History unknown dates")
        app.buttons["Clear filters"].tap()
        let search = app.textFields["Search watch history"]
        search.tap(); search.typeText("Ｆｒｉｅｒｅｎ\n")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-event-'")).firstMatch.waitForExistence(timeout: 5))
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-event-'")).firstMatch
        XCTAssertTrue(row.label.contains("Frieren")); row.tap()
        XCTAssertTrue(app.buttons["title-personal-rating"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertEqual(search.value as? String, "Ｆｒｉｅｒｅｎ")
        XCTAssertEqual(unknown.value as? String, "0"); capture("History retained search")
        app.buttons["Clear filters"].tap()
        let more = app.buttons["history-load-more"]
        for _ in 0..<12 { if more.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(more.isHittable); let before = more.label; more.tap()
        XCTAssertTrue(!more.exists || more.label != before, "Paging must reveal the next twelve watches")
        capture("History expanded page")
    }

    func testLibrarySearchAndSelectionPersistAcrossTabs() {
        let app = launch()
        app.buttons["tab-library"].tap(); app.buttons["Search library"].tap()
        let search = app.textFields["library-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Frieren\n")
        XCTAssertTrue(app.buttons["title-frieren"].exists); XCTAssertFalse(app.buttons["title-again"].exists)
        capture("Library search")
        app.buttons["tab-home"].tap(); app.buttons["tab-library"].tap()
        XCTAssertEqual(search.value as? String, "Frieren")
        app.buttons["Clear search"].tap(); app.buttons["List layout"].tap(); capture("Library list")
        app.buttons["Genre sections"].tap(); capture("Library genres")
    }
    func testLibraryStatusGenreAndDriveComposeThenClearTogether() {
        let app = launch(); app.buttons["tab-library"].tap()
        app.buttons["library-status"].tap(); app.buttons["Watching"].tap()
        app.buttons["library-genre"].tap(); app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Romance ('")).firstMatch.tap()
        app.buttons["library-disk"].tap(); app.buttons["E: Toshiba (4TB)"].tap()
        XCTAssertTrue(app.buttons["title-night"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["title-again"].exists); XCTAssertFalse(app.buttons["title-frieren"].exists)
        XCTAssertTrue(app.staticTexts["1 title"].exists); capture("Library composed filters")
        app.buttons["Clear filters"].tap()
        XCTAssertTrue(app.buttons["title-again"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["title-frieren"].exists)
        XCTAssertTrue(app.buttons["List layout"].exists); XCTAssertFalse(app.buttons["Grid layout"].exists)
        capture("Library filters cleared")
    }

    func testLibraryCommunityRatingPreferenceNeverDisplaysPersonalScores() {
        let app = launch()
        app.buttons["tab-more"].tap()
        let picker = app.buttons["settings-rating-source"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5)); picker.tap(); app.buttons["Trakt"].tap()
        app.buttons["tab-library"].tap()
        let title = app.buttons["title-again"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue((title.value as? String)?.contains("Rating 7.7") == true)
        XCTAssertFalse((title.value as? String)?.contains("Rating 7.5") == true)
        capture("Library Trakt community ratings")
        app.buttons["tab-more"].tap(); picker.tap(); app.buttons["TMDB"].tap()
        app.buttons["tab-library"].tap()
        XCTAssertFalse((title.value as? String)?.contains("Rating") == true, "This fixture has no TMDB score; its personal rating must not substitute")
        capture("Library TMDB missing scores")
    }
    func testUnavailableCommunityScoresKeepLibraryUsableAndCanSwitchBack() {
        let app = launch(ratingsUnavailable: true)
        app.buttons["tab-more"].tap()
        let picker = app.buttons["settings-rating-source"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5)); picker.tap(); app.buttons["Trakt"].tap()
        app.buttons["tab-library"].tap()
        let message = app.staticTexts["Some Trakt ratings are unavailable. Try again later or select TMDB in Settings."]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["title-again"].isHittable)
        XCTAssertFalse((app.buttons["title-again"].value as? String)?.contains("Rating") == true)
        capture("Library community ratings unavailable")
        app.buttons["tab-more"].tap(); picker.tap(); app.buttons["TMDB"].tap()
        app.buttons["tab-library"].tap(); XCTAssertFalse(message.exists)
    }
    func testCatalogSearchReviewAndCastProfile() {
        let app = launch(); app.buttons["tab-home"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == 'Search'")).count, 1, "Inactive tabs must not expose controls to VoiceOver")
        app.buttons["search-twildiary"].tap()
        let search = app.textFields["Search library and online"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Clockmaker\n")
        let result = app.buttons["search-movie:900001"]
        XCTAssertTrue(result.waitForExistence(timeout: 10)); capture("Catalog search"); result.tap()
        XCTAssertTrue(app.buttons["Add to Planned"].waitForExistence(timeout: 10)); capture("Catalog review")
        let actor = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Reference Actor 1'")).firstMatch
        if !actor.isHittable { app.swipeUp() }
        XCTAssertTrue(actor.waitForExistence(timeout: 5)); actor.tap()
        XCTAssertTrue(app.staticTexts["Facts & trivia"].waitForExistence(timeout: 10)); capture("Cast profile")
    }
    func testSavedEpisodeRevealPersistsAfterCollapseWithoutRevealingOtherRows() {
        let app = launch(); app.buttons["tab-library"].tap(); app.buttons["title-again"].tap()
        let episode = app.buttons["title-episode-9"]
        for _ in 0..<8 { if episode.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(episode.isHittable); XCTAssertEqual(episode.value as? String, "A story for later")
        episode.tap()
        XCTAssertEqual(episode.value as? String, "Episode 9"); capture("Title revealed episode")
        episode.tap()
        XCTAssertEqual(episode.value as? String, "Episode 9", "Collapsing a revealed synopsis must not hide its title again")
        XCTAssertEqual(app.buttons["title-episode-10"].value as? String, "A story for later", "A season metadata response must not reveal unselected rows")
        capture("Title revealed episode collapsed")
    }

    func testManualTitleYearValidationStatusRatingAndSavedNavigation() {
        let app = launch(mutations: true); app.buttons["tab-home"].tap(); app.buttons["search-twildiary"].tap(); app.buttons["Add manually"].tap()
        let name = app.textFields["manual-name"], year = app.textFields["manual-year"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Manual reference movie")
        year.tap(); year.typeText("1799"); app.buttons["manual-keyboard-done"].tap()
        app.buttons["manual-save"].tap(); XCTAssertTrue(app.staticTexts["Choose a valid release year"].waitForExistence(timeout: 5)); capture("Manual invalid year")
        year.tap(); year.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "1800"); app.buttons["manual-keyboard-done"].tap()
        app.buttons["manual-category"].tap(); app.buttons["Movie"].tap()
        app.buttons["manual-status"].tap(); app.buttons["Watching"].tap()
        app.buttons["Rating"].tap()
        let score = app.textFields["manual-score"]
        XCTAssertTrue(score.waitForExistence(timeout: 5)); score.tap(); score.typeText("7.5"); app.buttons["manual-keyboard-done"].tap(); capture("Manual title review")
        let save = app.buttons["manual-save"]
        for _ in 0..<4 { if save.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(save.isHittable); save.tap()
        XCTAssertTrue(app.buttons["title-personal-rating"].waitForExistence(timeout: 10)); XCTAssertEqual(app.buttons["title-personal-rating"].value as? String, "7.5")
        XCTAssertTrue(app.buttons["title-watch-status"].exists); capture("Manual title saved")
    }

    func testCatalogSeriesSeasonsSpoilersAndImport() {
        let app = launch(mutations: true); app.buttons["tab-home"].tap(); app.buttons["search-twildiary"].tap()
        let search = app.textFields["Search library and online"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Quiet Journey\n")
        let result = app.buttons["search-tv:900002"]
        XCTAssertTrue(result.waitForExistence(timeout: 10)); result.tap()
        XCTAssertTrue(app.buttons["catalog-add"].waitForExistence(timeout: 10)); capture("Catalog series hero")
        let season = app.buttons["catalog-season"]
        for _ in 0..<6 { if season.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(season.isHittable)
        let first = app.buttons["catalog-episode-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 5)); capture("Catalog spoiler-safe episodes")
        first.tap(); XCTAssertTrue(app.staticTexts["Reference episode summary."].waitForExistence(timeout: 5)); capture("Catalog revealed episode")
        season.tap(); app.buttons["Season 2"].tap()
        XCTAssertTrue(app.buttons["catalog-episode-1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Reference episode summary."].exists, "Expansion state must reset on season change")
        capture("Catalog second season")
        let showAll = app.buttons["Show all 12 episodes"]
        for _ in 0..<6 { if showAll.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(showAll.isHittable); showAll.tap()
        let last = app.buttons["catalog-episode-12"]
        for _ in 0..<8 { if last.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(last.isHittable); capture("Catalog all episodes")
        let add = app.buttons["catalog-add"]
        for _ in 0..<12 { if add.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(add.isHittable); add.tap()
        XCTAssertTrue(app.buttons["title-personal-rating"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["title-personal-rating"].value as? String, "Not rated")
        XCTAssertTrue(app.buttons["title-watch-status"].exists)
        let importedTrack = app.sliders["episode-progress"]
        XCTAssertTrue(importedTrack.waitForExistence(timeout: 10)); XCTAssertEqual(importedTrack.value as? String, "0 of 12 episodes watched")
        capture("Catalog imported title")
    }

    func testExploreAndHomeStatsShortcut() {
        let app = launch(); app.buttons["tab-home"].tap()
        let explore = app.buttons["explore-shortcut"]
        XCTAssertTrue(explore.waitForExistence(timeout: 5)); explore.tap()
        XCTAssertTrue(app.buttons["explore-daily-pick"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Highest rated shows"].exists); capture("Explore")
        let more = app.buttons["explore-more-rated-shows"]
        if !more.isHittable { app.swipeUp() }
        XCTAssertTrue(more.isHittable); more.tap()
        XCTAssertTrue(app.staticTexts["Highest rated shows"].waitForExistence(timeout: 5)); capture("Explore rated shows")
        app.buttons["explore-filters"].tap()
        let minimum = app.buttons["explore-minimum"]
        XCTAssertTrue(minimum.waitForExistence(timeout: 5)); minimum.tap(); app.buttons["9+"].tap()
        XCTAssertTrue(app.staticTexts["No titles in this mix"].waitForExistence(timeout: 5)); capture("Explore filtered empty")
        app.buttons["Reset filters"].tap()
        XCTAssertTrue(app.staticTexts["12 titles"].waitForExistence(timeout: 5))
        let loadMore = app.buttons["Load more"]
        for _ in 0..<10 { if loadMore.isHittable && loadMore.frame.maxY < app.buttons["tab-home"].frame.minY { break }; app.swipeUp() }
        XCTAssertTrue(loadMore.isHittable); XCTAssertLessThan(loadMore.frame.maxY, app.buttons["tab-home"].frame.minY); capture("Explore Load more reachable"); loadMore.tap()
        let lastResult = app.buttons["catalog-tv:900002"]
        for _ in 0..<8 { if lastResult.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(lastResult.isHittable, "The second page must publish its final unique result")
        capture("Explore second page")
        let count = app.staticTexts["16 titles"]
        for _ in 0..<12 { if count.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(count.isHittable)
        app.buttons["explore-section-done"].tap()
        XCTAssertTrue(app.buttons["explore-daily-pick"].waitForExistence(timeout: 5))
    }
    func testHomeStatsUsesTodayAndKeepsTheOriginalRangeBar() {
        let app = launch(); app.buttons["tab-stats"].tap()
        XCTAssertTrue(app.buttons["30D"].waitForExistence(timeout: 5))
        app.buttons["1Y"].tap()
        XCTAssertTrue(app.buttons["1Y"].isSelected)
        capture("Stats year")
        assertRangeHighlight(app.buttons["1Y"], app: app)
        app.buttons["tab-home"].tap()
        app.buttons["home-stats"].tap()
        XCTAssertTrue(app.staticTexts["Today"].exists || app.buttons.containing(NSPredicate(format: "label CONTAINS 'Today'")).firstMatch.exists)
        XCTAssertTrue(app.buttons["7D"].exists)
        XCTAssertTrue(app.buttons["90D"].exists)
        XCTAssertFalse(app.buttons["1Y"].isSelected)
        capture("Stats from Home")
    }
    func testTraktReviewAppliesSafeChangesThenRequiresAnExplicitConflictChoice() {
        let app = launch(); app.buttons["tab-more"].tap()
        XCTAssertTrue(app.buttons["settings-trakt-summary"].waitForExistence(timeout: 5))
        app.buttons["settings-trakt-summary"].tap()
        XCTAssertTrue(app.staticTexts["Review changes"].waitForExistence(timeout: 10))
        capture("Trakt review")
        let filter = app.segmentedControls["trakt-kind"]
        if !filter.isHittable { app.swipeUp() }
        filter.buttons["Ratings"].tap()
        XCTAssertTrue(app.staticTexts["Showing 3 of 3 loaded changes"].waitForExistence(timeout: 5))
        capture("Trakt ratings")
        filter.buttons["All"].tap()
        let ready = app.buttons["trakt-apply-ready"]
        for _ in 0..<12 {
            if ready.isHittable && ready.frame.maxY < app.buttons["tab-more"].frame.minY { break }
            app.swipeUp()
        }
        XCTAssertTrue(ready.isHittable)
        XCTAssertLessThan(ready.frame.maxY, app.buttons["tab-more"].frame.minY, "The entire Apply button must clear the capsule")
        capture("Trakt Apply visible"); ready.tap()
        XCTAssertTrue(app.staticTexts["1 remaining"].waitForExistence(timeout: 5))
        let useTrakt = app.buttons["trakt-trakt-change-2"]
        for _ in 0..<8 { if useTrakt.isHittable { break }; app.swipeDown() }
        for _ in 0..<8 { if useTrakt.isHittable { break }; app.swipeUp() }
        XCTAssertEqual(app.buttons.matching(identifier: "trakt-trakt-change-2").count, 1, "One conflict must expose exactly one Trakt action")
        XCTAssertTrue(useTrakt.isHittable); useTrakt.tap()
        XCTAssertTrue(app.staticTexts["You’re up to date"].waitForExistence(timeout: 5))
        capture("Trakt applied")
    }
    func testStatsCalendarRangesEmptyBucketsAndUndatedHistory() {
        let app = launch(); app.buttons["tab-stats"].tap()
        XCTAssertTrue(app.buttons["stats-calendar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["30D"].isSelected, "Fresh Stats starts with Today, as on the web")
        app.buttons["30D"].tap(); XCTAssertTrue(app.buttons["30D"].isSelected)
        let firstDay = app.buttons["stats-bucket-0"]
        if !firstDay.isHittable { app.swipeUp() }
        XCTAssertTrue(firstDay.waitForExistence(timeout: 5)); firstDay.tap()
        XCTAssertTrue(app.staticTexts["1 Oct 2026"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No watches logged in this period."].exists)
        capture("Stats empty day")
        app.buttons["Close"].tap(); app.swipeDown()
        app.buttons["stats-calendar"].tap()
        let week = app.buttons["This Week"]
        XCTAssertTrue(week.waitForExistence(timeout: 5)); week.tap()
        XCTAssertTrue(app.buttons["7D"].isSelected)
        XCTAssertFalse(app.buttons["30D"].isSelected)
        capture("Stats week")
        let review = app.buttons["Review dates"]
        if !review.isHittable { app.swipeDown() }
        review.tap()
        XCTAssertTrue(app.staticTexts["Recently watched"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 watch"].waitForExistence(timeout: 5))
        capture("Undated history")
    }
    func testLibraryBulkQueueTrashRestoreAndPermanentDeleteInIsolatedFixture() {
        let app = launch(mutations: true); app.buttons["tab-library"].tap()
        app.buttons["title-again"].press(forDuration: 1)
        app.buttons["Select"].tap()
        let other = app.buttons["select-title-after-rain"]
        XCTAssertTrue(other.waitForExistence(timeout: 5)); other.tap()
        XCTAssertTrue(app.staticTexts["2 selected"].exists)
        app.buttons["collection-action"].tap(); app.buttons["Queue"].tap()
        app.buttons["Apply selection action"].tap()
        let confirm = app.buttons["confirm-collection"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); capture("Bulk Queue review"); confirm.tap()
        XCTAssertTrue(app.buttons["title-again"].waitForExistence(timeout: 5))
        app.buttons["tab-home"].tap(); app.buttons["queue-shortcut"].tap()
        XCTAssertTrue(app.buttons["title-again"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["title-after-rain"].exists); XCTAssertFalse(app.buttons["title-frieren"].exists)
        app.buttons["title-again"].press(forDuration: 1); app.buttons["Move to Trash"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        let trash = app.buttons["Open Trash"]
        if !trash.isHittable { app.scrollViews.element(boundBy: 0).swipeLeft() }
        trash.tap()
        XCTAssertTrue(app.staticTexts["In Trash"].waitForExistence(timeout: 5)); capture("Trash populated")
        app.buttons["Restore"].tap(); XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.staticTexts["Trash is clear"].waitForExistence(timeout: 5))
        app.buttons["Return to Library"].tap()
        XCTAssertTrue(app.buttons["title-again"].waitForExistence(timeout: 5))
        app.buttons["title-again"].press(forDuration: 1); app.buttons["Move to Trash"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        if !trash.isHittable { app.scrollViews.element(boundBy: 0).swipeLeft() }
        trash.tap(); app.buttons["Delete permanently"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.staticTexts["Trash is clear"].waitForExistence(timeout: 5)); capture("Trash after permanent delete")
    }
    func testFilesAndScannerMatchPublishLocationWithoutChangingWatchHistory() {
        let app = launch(scanner: true); app.buttons["tab-more"].tap()
        app.buttons["settings-files"].tap()
        XCTAssertTrue(app.staticTexts["Mapped folders"].waitForExistence(timeout: 5)); capture("Files and drives")
        let review = app.buttons["Fix mismatches →"]
        for _ in 0..<8 { if review.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(review.isHittable); review.tap()
        let match = app.buttons["match-scan-fixture-unmatched"]
        XCTAssertTrue(match.waitForExistence(timeout: 5)); capture("Unmatched scan"); match.tap()
        let search = app.textFields["Search library and online"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("18 Again\n")
        let chosen = app.buttons["match-title-again"]
        XCTAssertTrue(chosen.waitForExistence(timeout: 5)); chosen.tap()
        XCTAssertTrue(app.staticTexts["No unmatched scans"].waitForExistence(timeout: 5)); capture("Scanner resolved")
        let done = app.buttons["scanner-done"]
        XCTAssertTrue(done.isHittable)
        XCTAssertLessThan(done.frame.maxY, app.buttons["tab-more"].frame.minY, "Dismiss must never overlap the tab bar")
        done.tap()
        XCTAssertTrue(app.staticTexts["Mapped folders"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab-more"].isSelected)
        let path = app.staticTexts["R:\\Reference\\Unmatched Series"]
        for _ in 0..<10 { if path.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(path.exists); capture("Confirmed scanned location")
        let filesDone = app.buttons["files-done"]
        XCTAssertTrue(filesDone.isHittable); filesDone.tap()
        XCTAssertTrue(app.staticTexts["Appearance & region"].waitForExistence(timeout: 5))
    }
    func testStatsMoreAndFilesOfferInlineSearchWithoutChangingTheActiveTab() {
        let app = launch()
        for tab in ["stats", "more"] {
            app.buttons["tab-" + tab].tap(); app.buttons["search-" + tab].tap()
            let field = app.textFields["Search library and online"]
            XCTAssertTrue(field.waitForExistence(timeout: 5)); field.typeText("Frieren\n")
            XCTAssertTrue(app.buttons["search-library-frieren"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["tab-" + tab].isSelected); capture("Inline search " + tab)
            app.buttons["Close search"].tap()
            XCTAssertFalse(field.exists)
        }
        app.buttons["settings-files"].tap(); app.buttons["search-files & drives"].tap()
        let field = app.textFields["Search library and online"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.typeText("Frieren\n")
        XCTAssertTrue(app.buttons["search-library-frieren"].waitForExistence(timeout: 5)); capture("Inline search Files")
        app.buttons["Close search"].tap(); app.buttons["files-done"].tap()
        XCTAssertTrue(app.staticTexts["Appearance & region"].waitForExistence(timeout: 5))
    }
    func testGlanceSwipeLogsExactlyOneWatchAndUndoPreservesTheCardPosition() {
        let app = launch(mutations: true)
        let count = app.staticTexts["watch-count-again"], mark = app.buttons["Mark next watch for 18 Again"]
        XCTAssertTrue(count.waitForExistence(timeout: 5)); XCTAssertEqual(count.label, "8")
        let originalY = mark.frame.minY
        let title = app.buttons["progress-title-again"]
        let start = title.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 140, dy: 0)))
        wait(for: [expectation(for: NSPredicate(format: "label == '9'"), evaluatedWith: count)], timeout: 10)
        XCTAssertEqual(mark.frame.minY, originalY, accuracy: 1, "Release must not reflow the page")
        XCTAssertTrue(app.buttons["tab-glance"].isSelected); XCTAssertTrue(count.isHittable)
        capture("Glance swipe marked")
        app.buttons["Undo"].tap()
        wait(for: [expectation(for: NSPredicate(format: "label == '8'"), evaluatedWith: count)], timeout: 10)
        XCTAssertEqual(mark.frame.minY, originalY, accuracy: 1)
        app.buttons["Remove latest watch for 18 Again"].tap()
        wait(for: [expectation(for: NSPredicate(format: "label == '7'"), evaluatedWith: count)], timeout: 10)
        app.buttons["Undo"].tap()
        wait(for: [expectation(for: NSPredicate(format: "label == '8'"), evaluatedWith: count)], timeout: 10)
        capture("Glance Undo restored")
    }
    func testTitleWatchAndUndoUpdateTheEpisodePiecesAndMovieHistory() {
        let app = launch(mutations: true); app.buttons["tab-library"].tap(); app.buttons["title-again"].tap()
        let progress = app.sliders["episode-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5)); XCTAssertEqual(progress.value as? String, "8 of 16 episodes watched")
        let mark = app.buttons["mark-title-watch"]
        if !mark.isHittable { app.swipeUp() }
        mark.tap()
        wait(for: [expectation(for: NSPredicate(format: "value == '9 of 16 episodes watched'"), evaluatedWith: progress)], timeout: 10)
        capture("Title episode marked")
        app.buttons["Undo"].tap()
        wait(for: [expectation(for: NSPredicate(format: "value == '8 of 16 episodes watched'"), evaluatedWith: progress)], timeout: 10)
        let start = progress.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: progress.coordinate(withNormalizedOffset: CGVector(dx: 0.625, dy: 0.5)))
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 10), "A range edit must produce a real Undo receipt, not only a draft value")
        wait(for: [expectation(for: NSPredicate(format: "value == '10 of 16 episodes watched'"), evaluatedWith: progress)], timeout: 10)
        capture("Title range committed"); app.buttons["Undo"].tap()
        wait(for: [expectation(for: NSPredicate(format: "value == '8 of 16 episodes watched'"), evaluatedWith: progress)], timeout: 10)
        app.navigationBars.buttons.element(boundBy: 0).tap(); app.buttons["title-quiet-orbit"].tap()
        let movieMark = app.buttons["mark-title-watch"]
        XCTAssertTrue(movieMark.waitForExistence(timeout: 5)); movieMark.tap()
        XCTAssertTrue(app.buttons["Log a rewatch"].waitForExistence(timeout: 5))
        capture("Movie watched")
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.buttons["Log a watch"].waitForExistence(timeout: 5)); capture("Movie watch undone")
    }
    func testPersonShelvesOpenFilteredFilmographyAndPreserveReturnNavigation() {
        let app = launch(); app.buttons["tab-home"].tap(); app.buttons["search-twildiary"].tap()
        let search = app.textFields["Search library and online"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.typeText("Clockmaker\n")
        let result = app.buttons["search-movie:900001"]
        XCTAssertTrue(result.waitForExistence(timeout: 10)); result.tap()
        let actor = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Reference Actor 1'")).firstMatch
        for _ in 0..<5 { if actor.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(actor.isHittable); actor.tap()
        XCTAssertTrue(app.staticTexts["Facts & trivia"].waitForExistence(timeout: 10))
        let factLabel = app.staticTexts["person-fact-known-for-label"], factValue = app.staticTexts["person-fact-known-for-value"]
        XCTAssertTrue(factLabel.waitForExistence(timeout: 5)); XCTAssertTrue(factValue.exists)
        XCTAssertGreaterThan(factLabel.frame.width, 80); XCTAssertLessThan(factLabel.frame.height, 60)
        XCTAssertLessThan(abs(factValue.frame.minY - factLabel.frame.minY), 8)
        XCTAssertLessThan(app.staticTexts["person-fact-birthplace-label"].frame.minY - factLabel.frame.minY, 75)
        capture("Person facts")
        let more = app.buttons["person-more-shows"]
        for _ in 0..<12 { if more.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(more.isHittable); capture("Person credit shelves"); more.tap()
        let count = app.staticTexts["person-result-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5)); XCTAssertEqual(count.label, "16 titles"); capture("Person show filmography")
        app.buttons["person-filters"].tap(); app.buttons["person-minimum"].tap(); app.buttons["9+"].tap()
        XCTAssertTrue(app.staticTexts["No titles in this mix"].waitForExistence(timeout: 5)); capture("Person filtered empty")
        app.buttons["person-reset"].tap(); app.buttons["person-collection"].tap(); app.buttons["On your server"].tap()
        XCTAssertTrue(app.staticTexts["No titles in this mix"].waitForExistence(timeout: 5)); XCTAssertEqual(count.label, "0 titles · On your server")
        capture("Person server filmography empty")
        app.buttons["person-filmography-done"].tap()
        XCTAssertTrue(app.buttons["person-more-shows"].waitForExistence(timeout: 5))
    }
    func testTitleRatingEditsInlineWithoutChangingItsWatchCount() {
        let app = launch(mutations: true); app.buttons["tab-library"].tap(); app.buttons["title-again"].tap()
        let personal = app.buttons["title-personal-rating"]
        XCTAssertTrue(personal.waitForExistence(timeout: 5)); XCTAssertEqual(personal.value as? String, "7.5"); personal.tap()
        let clear = app.buttons["Clear your rating"]
        for _ in 0..<6 { if clear.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(clear.isHittable); capture("Title inline rating"); clear.tap()
        let rate = app.buttons["Rate 7.0"]
        XCTAssertTrue(rate.waitForExistence(timeout: 5)); rate.tap()
        XCTAssertTrue(clear.waitForExistence(timeout: 5)); capture("Title rating saved")
        for _ in 0..<6 { if personal.isHittable { break }; app.swipeDown() }
        XCTAssertEqual(personal.value as? String, "7.0")
        XCTAssertEqual(app.sliders["episode-progress"].value as? String, "8 of 16 episodes watched")
    }
    func testNotesDraftSurvivesOpeningACastProfileAndReturning() {
        let app = launch(mutations: true, titleMetadata: true); app.buttons["tab-library"].tap(); app.buttons["title-again"].tap()
        let notes = app.buttons["Notes"]
        for _ in 0..<14 { if notes.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(notes.isHittable); notes.tap()
        let editor = app.textViews["title-notes"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5)); editor.tap(); editor.typeText("Native draft survives cast navigation")
        let done = app.buttons["notes-keyboard-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        let actor = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Reference Actor 1'")).firstMatch
        for _ in 0..<10 { if actor.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(actor.isHittable); actor.tap()
        XCTAssertTrue(app.staticTexts["Facts & trivia"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        for _ in 0..<10 { if editor.isHittable { break }; app.swipeUp() }
        XCTAssertTrue((editor.value as? String)?.contains("Native draft survives cast navigation") == true)
        capture("Notes draft retained")
        app.buttons["Save notes"].tap()
        wait(for: [expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: app.buttons["Save notes"])], timeout: 10)
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func assertEpisodePieces(_ track: XCUIElement, app: XCUIApplication) {
        guard let image = XCUIScreen.main.screenshot().image.cgImage else { XCTFail("Missing episode screenshot"); return }
        let scale = CGFloat(image.width) / app.frame.width
        // Accessibility reports the visible ink bounds, excluding the SVG's outer margins.
        // Count actual foreground runs instead of deriving slot positions from those bounds.
        let left = floor(track.frame.minX * scale)
        let width = Int(ceil(track.frame.maxX * scale) - left)
        guard width > 0, let row = image.cropping(to: CGRect(x: left, y: floor(track.frame.midY * scale), width: CGFloat(width), height: 1)) else { XCTFail("Missing episode row"); return }
        var bytes = [UInt8](repeating: 0, count: width * 4)
        let rendered = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: 1, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(row, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: 1)); return true
        }
        XCTAssertTrue(rendered)
        var pieces: [(start: Int, end: Int)] = []
        var insidePiece = false
        for x in 0..<width {
            let foreground = bytes[x * 4] > 35 || bytes[x * 4 + 1] > 35 || bytes[x * 4 + 2] > 40
            if foreground {
                if !insidePiece { pieces.append((start: x, end: x)) }
                else { pieces[pieces.count - 1].end = x }
            }
            insidePiece = foreground
        }
        guard pieces.count == 16 else { XCTFail("Expected 16 separate episode pieces; rendered \(pieces.count)"); return }
        for index in pieces.indices {
            let center = (pieces[index].start + pieces[index].end) / 2
            let piece = [Int(bytes[center * 4]), Int(bytes[center * 4 + 2])]
            if index > 0 { XCTAssertGreaterThan(pieces[index].start - pieces[index - 1].end, 2, "Every adjacent pair must have a visible gap") }
            if index < 8 {
                XCTAssertGreaterThan(piece[0], 120, "Each watched episode must have its own filled piece")
                XCTAssertGreaterThan(piece[1], 180)
            } else {
                XCTAssertLessThan(piece[0], 120, "Unwatched episodes must not appear filled")
                if index == 8 { XCTAssertGreaterThan(piece[1], 70, "Up next must have a softer accent tint") }
            }
        }
    }
    private func sample(_ image: CGImage, at point: CGPoint, scale: CGFloat) -> [Int] {
        guard let pixel = image.cropping(to: CGRect(x: floor(point.x * scale), y: floor(point.y * scale), width: 1, height: 1)) else { XCTFail("Missing pixel sample"); return [0, 0, 0, 0] }
        var bytes = [UInt8](repeating: 0, count: 4)
        let rendered = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1)); return true
        }
        XCTAssertTrue(rendered)
        return bytes.map(Int.init)
    }
    private func assertRangeHighlight(_ button: XCUIElement, app: XCUIApplication) {
        guard let source = XCUIScreen.main.screenshot().image.cgImage else { XCTFail("Missing screenshot"); return }
        let scale = CGFloat(source.width) / app.frame.width
        // Sample the clear left side of the segment, away from label glyphs and borders.
        let point = CGPoint(x: button.frame.minX + button.frame.width * 0.15, y: button.frame.midY)
        let bytes = sample(source, at: point, scale: scale)
        XCTAssertGreaterThan(bytes[0], 120, "The selected range must visibly use the accent fill")
        XCTAssertGreaterThan(bytes[2], 180, "A selected accessibility trait alone is insufficient")
    }
}
