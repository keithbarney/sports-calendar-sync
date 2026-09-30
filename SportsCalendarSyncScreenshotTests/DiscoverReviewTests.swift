import XCTest

final class DiscoverReviewTests: XCTestCase {
    @MainActor
    func testUnfollowedTeamShowsAllCompetitionsAndFixtures() {
        continueAfterFailure = false
        let app = launch(extra: ["-mock-second-divisions", "-screenshot-empty"])
        let all = app.buttons["All competitions"]
        if !all.isHittable { app.swipeUp() }
        all.tap()
        let league = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "2. Bundesliga")).firstMatch
        if !league.isHittable { app.swipeUp() }
        league.tap()
        XCTAssertTrue(app.staticTexts["SV Darmstadt 98"].waitForExistence(timeout: 10))
        app.staticTexts["SV Darmstadt 98"].tap()
        XCTAssertTrue(app.staticTexts["DFB-Pokal"].waitForExistence(timeout: 15))
        capture("team-detail-top")
        for _ in 0..<3 {
            if app.staticTexts.matching(identifier: "Club Friendlies").firstMatch.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts.matching(identifier: "Club Friendlies").firstMatch.exists)
        capture("team-all-competitions-unfollowed")
        for _ in 0..<4 {
            if app.staticTexts.matching(identifier: "SV Darmstadt 98 vs. Bayern Munich").firstMatch.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["SV Darmstadt 98 vs. Hannover 96"].exists)
        XCTAssertTrue(app.staticTexts["SV Darmstadt 98 vs. Bayern Munich"].exists)
        XCTAssertFalse(app.staticTexts["No upcoming fixtures"].exists)
        capture("team-league-and-cup-preview")
        app.navigationBars.buttons["Follow"].tap()
        XCTAssertTrue(app.navigationBars["Follow SV Darmstadt 98"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.switches["DFB-Pokal"].value as? String, "1")
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Follow"].exists)
    }

    @MainActor
    func testPopularCarouselAndFollowCompetitions() {
        continueAfterFailure = false
        let app = launch()
        let carousel = app.scrollViews["popular-teams-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["popular-team-realmadrid"].exists)
        capture("discover-popular-light")
        for _ in 0..<8 {
            if app.buttons["popular-team-arsenal"].isHittable { break }
            carousel.swipeLeft()
        }
        XCTAssertTrue(app.buttons["popular-team-arsenal"].isHittable)
        capture("discover-carousel-end")
        for _ in 0..<8 {
            if app.buttons["Follow Barcelona"].isHittable { break }
            carousel.swipeRight()
        }
        app.buttons["Follow Barcelona"].tap()
        XCTAssertTrue(app.navigationBars["Follow Barcelona"].waitForExistence(timeout: 10))
        for label in ["La Liga", "UEFA Champions League", "Copa del Rey"] {
            XCTAssertEqual(app.switches[label].value as? String, "1")
        }
        capture("discover-follow-competitions")
        app.navigationBars.buttons["Follow"].tap()
        XCTAssertTrue(app.buttons["Manage Barcelona"].waitForExistence(timeout: 10))
        app.buttons["Manage Barcelona"].tap()
        XCTAssertTrue(app.buttons["Manage competitions, 3 followed"].waitForExistence(timeout: 10), app.debugDescription)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(carousel.waitForExistence(timeout: 5))
    }

    @MainActor
    func testGlobalSearchAndEmptyResults() {
        continueAfterFailure = false
        let app = launch(appearance: "Dark")
        XCTAssertTrue(app.scrollViews["popular-teams-carousel"].waitForExistence(timeout: 15))
        capture("discover-popular-dark")
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Madrid")
        XCTAssertTrue(app.staticTexts["Real Madrid"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: "Real Madrid").count, 1)
        capture("discover-search-deduplicated")
        app.buttons["Follow Atlético Madrid"].tap()
        XCTAssertTrue(app.navigationBars["Follow Atlético Madrid"].waitForExistence(timeout: 10))
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.buttons["Clear text"].tap()
        search.tap()
        search.typeText("zzzznoresults")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "No results")).firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        capture("discover-search-empty")
    }

    @MainActor
    func testBrowseSecondDivisionAndClubDetails() {
        continueAfterFailure = false
        let app = launch(extra: ["-mock-second-divisions"])
        let all = app.buttons["All competitions"]
        if !all.isHittable { app.swipeUp() }
        XCTAssertTrue(all.waitForExistence(timeout: 10))
        capture("discover-leagues")
        all.tap()
        XCTAssertTrue(app.navigationBars["Competitions"].waitForExistence(timeout: 5))
        capture("discover-all-competitions")
        let bundesliga = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "2. Bundesliga")).firstMatch
        if !bundesliga.isHittable { app.swipeUp() }
        XCTAssertTrue(bundesliga.waitForExistence(timeout: 5))
        bundesliga.tap()
        XCTAssertTrue(app.staticTexts["SV Darmstadt 98"].waitForExistence(timeout: 10))
        capture("discover-second-division")
        app.staticTexts["SV Darmstadt 98"].tap()
        XCTAssertTrue(app.navigationBars["SV Darmstadt 98"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Mock data"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["SV Darmstadt 98"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launch(appearance: String = "Light", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-mock-data", "-initial-tab", "discover", "-appearanceMode", appearance,
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["Mock data"].waitForExistence(timeout: 15))
        return app
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
