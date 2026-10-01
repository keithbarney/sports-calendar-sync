import XCTest

final class FollowingReviewTests: XCTestCase {
    @MainActor
    func testNextFixtureAndDetailNavigation() {
        continueAfterFailure = false
        let app = launch()
        let darmstadt = app.buttons["following-club-svdarmstadt98"]
        XCTAssertTrue(darmstadt.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(darmstadt.label.contains("Next: vs. Hannover 96"), darmstadt.label)
        capture("following-next-fixture-light")
        darmstadt.tap()
        XCTAssertTrue(app.staticTexts["SV Darmstadt 98 vs. Hannover 96"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(darmstadt.waitForExistence(timeout: 5))
        app.buttons["Competition filter"].tap()
        app.buttons["DFB-Pokal"].firstMatch.tap()
        XCTAssertTrue(darmstadt.waitForExistence(timeout: 5))
        XCTAssertTrue(darmstadt.label.contains("Next: vs. Hannover 96"), "Next match still spans the club's followed competitions")
        capture("following-next-fixture-filtered")
        app.terminate()
        let dark = launch(appearance: "Dark")
        XCTAssertTrue(dark.buttons["following-club-svdarmstadt98"].waitForExistence(timeout: 10))
        capture("following-next-fixture-dark")
    }

    @MainActor
    func testNoUpcomingFixture() {
        continueAfterFailure = false
        let app = launch(extra: ["-screenshot-date", "2000-01-01T00:00:00Z"])
        let darmstadt = app.buttons["following-club-svdarmstadt98"]
        XCTAssertTrue(darmstadt.waitForExistence(timeout: 10))
        XCTAssertTrue(darmstadt.label.contains("No upcoming fixtures"), darmstadt.label)
        capture("following-no-upcoming-fixtures")
    }

    @MainActor
    private func launch(appearance: String = "Light", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-mock-data", "-mock-second-divisions", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-appearanceMode", appearance] + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["Mock data"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Following"].tap()
        return app
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
