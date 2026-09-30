import XCTest

final class WidgetReviewTests: XCTestCase {
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWidgetRendererLightAndDark() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-mock-data", "-mock-widget-review", "-mock-second-divisions", "-widget-design-review",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Widget renderer preview"].waitForExistence(timeout: 15))
        capture("widget-small-medium-light")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Large"].exists)
        capture("widget-large-light")
        app.switches["Dark appearance"].coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(app.switches["Dark appearance"].value as? String, "1")
        capture("widget-large-dark")
        app.swipeDown()
        capture("widget-small-medium-dark")
    }

    @MainActor
    func testWidgetMediumMetadataAndLink() {
        verifyCompactWidget(label: "Medium-sized widget", showsSecondFixture: true)
    }

    @MainActor
    func testWidgetSmallMetadataAndLink() {
        verifyCompactWidget(label: "Small widget", showsSecondFixture: false)
    }

    @MainActor
    private func verifyCompactWidget(label: String, showsSecondFixture: Bool) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-mock-data", "-mock-widget-review", "-mock-second-divisions",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Mock data"].waitForExistence(timeout: 15))
        XCUIDevice.shared.press(.home)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = home.icons["Sports Sync (L)"].firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 5))
        capture("widget-refined-current-size")
        icon.press(forDuration: 1.5)
        XCTAssertTrue(home.buttons[label].waitForExistence(timeout: 5))
        let selectedSize = home.cells.containing(.button, identifier: label).firstMatch
        if selectedSize.exists && selectedSize.isSelected {
            XCUIDevice.shared.press(.home)
        } else {
            home.buttons[label].tap()
        }
        if home.buttons["Done"].exists { home.buttons["Done"].tap() }
        XCTAssertTrue(home.staticTexts["Championship"].waitForExistence(timeout: 10))
        XCTAssertFalse(home.staticTexts["Norwich City"].exists)
        XCTAssertFalse(home.staticTexts["Almería"].exists)
        XCTAssertEqual(home.staticTexts["LaLiga 2"].exists, showsSecondFixture)
        XCTAssertEqual(home.staticTexts["Carrow Road"].exists, showsSecondFixture)
        XCTAssertTrue(home.staticTexts["Championship"].exists)
        XCTAssertFalse(home.staticTexts["ESPN+"].exists)
        XCTAssertFalse(home.staticTexts["Saint-Étienne"].exists)
        capture(showsSecondFixture ? "widget-medium-without-network" : "widget-small-without-location-network")
        icon.tap()
        XCTAssertTrue(app.navigationBars["Following"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testWidgetHomeScreenSizes() {
        verifyHomeScreenSizes([("small", "Small widget"), ("medium", "Medium-sized widget"), ("large", "Large widget")])
    }

    @MainActor
    func testWidgetLargeMetadataAndLink() {
        verifyHomeScreenSizes([("large", "Large widget")])
    }

    @MainActor
    private func verifyHomeScreenSizes(_ sizes: [(String, String)]) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-mock-data", "-mock-widget-review", "-mock-second-divisions",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Mock data"].waitForExistence(timeout: 15))
        XCUIDevice.shared.press(.home)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = home.icons["Sports Sync (L)"].firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 5), home.debugDescription)
        for (size, label) in sizes {
            if !home.buttons[label].exists { icon.press(forDuration: 1.5) }
            XCTAssertTrue(home.buttons[label].waitForExistence(timeout: 5))
            let selectedSize = home.cells.containing(.button, identifier: label).firstMatch
            if selectedSize.exists && selectedSize.isSelected {
                XCUIDevice.shared.press(.home)
            } else {
                home.buttons[label].tap()
            }
            if home.buttons["Done"].exists { home.buttons["Done"].tap() }
            XCTAssertEqual(icon.value as? String, "Widget")
            XCTAssertTrue(home.staticTexts["Championship"].waitForExistence(timeout: 10))
            XCTAssertFalse(home.staticTexts["Norwich City"].exists)
            if size != "large" {
                XCTAssertFalse(home.staticTexts["ESPN+"].firstMatch.exists)
            } else {
                XCTAssertTrue(home.staticTexts["ESPN+"].firstMatch.exists)
            }
            XCTAssertEqual(home.staticTexts["Carrow Road"].firstMatch.exists, size != "small")
            if size == "medium" {
                XCTAssertTrue(home.staticTexts["LaLiga 2"].exists)
                XCTAssertFalse(home.staticTexts["Almería"].exists)
                XCTAssertFalse(home.staticTexts["Saint-Étienne"].exists)
            }
            if size == "large" {
                XCTAssertFalse(home.staticTexts["Saint-Étienne"].exists)
                XCTAssertFalse(home.staticTexts["SV Darmstadt 98"].exists)
                XCTAssertTrue(home.staticTexts["Ligue 2"].exists)
                XCTAssertTrue(home.staticTexts["2. Bundesliga"].exists)
                XCTAssertFalse(home.staticTexts["Serie B"].exists)
            }
            capture("widget-live-\(size)")
        }
        icon.tap()
        XCTAssertTrue(app.navigationBars["Following"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Mock data"].exists)
        capture("widget-opens-following")
    }
}
