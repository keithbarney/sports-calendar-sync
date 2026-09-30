import XCTest

final class CaptureTests: XCTestCase {
    private var appearance: String {
        if let selected = ProcessInfo.processInfo.environment["SCREENSHOT_APPEARANCE"] { return selected }
        #if DARK_CAPTURE
        return "Dark"
        #else
        return "Light"
        #endif
    }

    private func launchArguments(_ extra: [String] = []) -> [String] {
        ["-screenshot-fixtures", "-screenshot-date", ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date())),
         "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-appearanceMode", appearance] + extra
    }

    private func tapTab(_ label: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[label]
        if tab.exists {
            tab.tap()
        } else {
            let sidebarItem = app.buttons[label].firstMatch
            XCTAssertTrue(sidebarItem.waitForExistence(timeout: 5), "Missing navigation item: \(label)")
            sidebarItem.tap()
        }
    }

    @MainActor
    func testCalendarSettingsKeepManualSyncAction() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-screenshot-fixtures", "-initial-tab", "profile",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        let sync = app.buttons["Sync Calendar Events"]
        XCTAssertTrue(sync.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.switches["Sync to Calendar"].exists)
        XCTAssertFalse(app.buttons["Remove This App’s Calendar Events"].exists)
        XCTAssertFalse(app.staticTexts["Last successful refresh"].exists)
        sync.tap()
        XCTAssertTrue(app.staticTexts["Follow a team to add calendar events"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "simple-calendar-settings"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testSecondDivisionDiscoveryAndCompetitionFollow() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-mock-data", "-mock-second-divisions", "-screenshot-empty",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-appearanceMode", "Light"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Mock data"].waitForExistence(timeout: 15))
        tapTab("Discover", in: app)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Darmstadt")
        let club = app.buttons.containing(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@ AND NOT label CONTAINS %@", "SV Darmstadt 98", "2. Bundesliga", "Playoff")).firstMatch
        XCTAssertTrue(club.waitForExistence(timeout: 10), app.debugDescription)
        club.tap()
        XCTAssertTrue(app.staticTexts["SV Darmstadt 98 vs. Hannover 96"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.matching(identifier: "Follow").allElementsBoundByIndex.last!.tap()
        XCTAssertTrue(app.switches["DFB-Pokal"].waitForExistence(timeout: 10))
        for name in ["2. Bundesliga", "DFB-Pokal", "Bundesliga Promotion/Relegation Playoff",
                     "2. Bundesliga Promotion/Relegation Playoff", "Club Friendlies"] {
            XCTAssertTrue(app.switches[name].exists, name)
        }
        app.navigationBars["Follow SV Darmstadt 98"].buttons["Follow"].tap()
        let manage = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Manage competitions")).firstMatch
        XCTAssertTrue(manage.waitForExistence(timeout: 10))
        manage.tap()
        XCTAssertTrue(app.switches["DFB-Pokal"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["DFB-Pokal"].value as? String, "1")
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "second-division-competitions"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["Cancel"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        tapTab("Following", in: app)
        let followed = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "SV Darmstadt 98")).firstMatch
        XCTAssertTrue(followed.waitForExistence(timeout: 5))
        followed.tap()
        XCTAssertTrue(app.staticTexts["SV Darmstadt 98 vs. Hannover 96"].waitForExistence(timeout: 5))
        let detail = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        detail.name = "second-division-fixtures"; detail.lifetime = .keepAlways; add(detail)
    }

    @MainActor
    func testCatalogArtworkReview() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = launchArguments()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Discover"].tap()
        app.buttons["Competition filter"].tap()
        XCTAssertTrue(app.buttons["Serie A"].waitForExistence(timeout: 5))
        app.buttons["Serie A"].tap()
        let inter = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Inter Milan")).firstMatch
        XCTAssertTrue(inter.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Mock data"].exists)
        let catalog = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        catalog.name = "serie-a-actual-crests"
        catalog.lifetime = .keepAlways
        add(catalog)
        inter.tap()
        XCTAssertTrue(app.staticTexts["Upcoming fixtures"].waitForExistence(timeout: 10))
        let detail = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        detail.name = "inter-actual-crest"
        detail.lifetime = .keepAlways
        add(detail)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(inter.waitForExistence(timeout: 5))
    }

    @MainActor
    func testMockScenarioPickerAndReminderChange() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-mock-data", "-screenshot-empty", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Mock data"].waitForExistence(timeout: 15))
        app.buttons["mock-scenario-picker"].tap()
        XCTAssertTrue(app.buttons["Dates pending"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sync failure"].exists)
        XCTAssertTrue(app.buttons["Long titles"].exists)
        app.buttons["Long titles"].tap()
        XCTAssertTrue(app.staticTexts["Association Sportive de la Ville de Manchester United Supporters Club"].waitForExistence(timeout: 10))
        app.buttons["mock-scenario-picker"].tap()
        app.buttons["Typical library"].tap()
        tapTab("Settings", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        let reminder = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Reminder")).firstMatch
        if reminder.exists { reminder.tap() } else { app.staticTexts["Reminder"].tap() }
        XCTAssertTrue(app.navigationBars["Reminder"].waitForExistence(timeout: 5))
        app.buttons["Off"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testThirtyMinuteReminderPersistsAfterRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-mock-data", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Mock data"].waitForExistence(timeout: 15))
        tapTab("Settings", in: app)
        let reminder = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Reminder")).firstMatch
        XCTAssertTrue(reminder.waitForExistence(timeout: 5))
        reminder.tap()
        XCTAssertTrue(app.navigationBars["Reminder"].waitForExistence(timeout: 5))
        app.buttons["30 min before"].tap()
        // Selecting the already selected native Picker row can leave it open.
        if app.navigationBars["Reminder"].exists {
            app.navigationBars["Reminder"].buttons.firstMatch.tap()
        }
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Mock data"].waitForExistence(timeout: 15))
        tapTab("Settings", in: app)
        let savedReminder = app.buttons["Reminder"]
        XCTAssertTrue(savedReminder.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(savedReminder.value as? String, "30 min before")
        savedReminder.tap()
        XCTAssertTrue(app.navigationBars["Reminder"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["30 min before"].isSelected)
        for option in ["15 min before", "30 min before", "1 hour before", "Day before", "Off"] {
            XCTAssertTrue(app.buttons[option].exists)
        }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "reminder-thirty-minutes-after-relaunch"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCaptureCoreScreens() {
        continueAfterFailure = false
        let selected = Set((ProcessInfo.processInfo.environment["SCREENSHOT_SCREENS"] ?? "following,team-detail,broadcasts,reminder").split(separator: ",").map(String.init))
        let app = XCUIApplication()
        app.launchArguments = launchArguments()
        XCUIDevice.shared.press(.home)
        app.launch()
        func capture(_ name: String) {
            XCTAssertFalse(app.staticTexts["Mock data"].exists)
            XCTAssertFalse(app.buttons["Review scenario"].exists)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        tapTab("Following", in: app)
        let united = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Manchester United")).firstMatch
        XCTAssertTrue(united.waitForExistence(timeout: 15))
        if selected.contains("following") { capture("01-following") }
        if !selected.isDisjoint(with: ["team-detail", "manage-competitions", "broadcasts"]) {
            united.tap()
            XCTAssertTrue(app.staticTexts["Upcoming fixtures"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Manchester United vs.")).firstMatch.exists)
            if selected.contains("team-detail") { capture("02-team-detail") }
            if selected.contains("broadcasts") {
                let firstFixture = app.staticTexts["Manchester United vs. Arsenal"].firstMatch
                let desiredTop: CGFloat = app.frame.width > 700 ? 170 : 150
                let distance = max(0, firstFixture.frame.minY - desiredTop)
                if distance > 0 {
                    let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                    let destination = origin.withOffset(CGVector(dx: 0, dy: -distance))
                    origin.press(forDuration: 0.1, thenDragTo: destination, withVelocity: .slow, thenHoldForDuration: 0.5)
                }
                XCTAssertTrue(firstFixture.isHittable)
                XCTAssertGreaterThan(firstFixture.frame.minY, 100)
                XCTAssertTrue(app.staticTexts["NBC, Peacock"].waitForExistence(timeout: 5))
                capture("10-broadcasts")
            }
            if selected.contains("manage-competitions") {
                app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Manage competitions")).firstMatch.tap()
                XCTAssertTrue(app.switches["FA Cup"].waitForExistence(timeout: 10))
                capture("03-manage-competitions")
                app.buttons["Cancel"].tap()
            }
        }
        if selected.contains("discover") {
            tapTab("Discover", in: app)
            XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
            capture("04-discover")
        }
        if !selected.isDisjoint(with: ["settings", "reminder"]) {
            tapTab("Settings", in: app)
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
            let permission = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ AND (label CONTAINS %@ OR value CONTAINS %@)", "Calendar", "Allowed", "Allowed")).firstMatch
            XCTAssertTrue(permission.exists, app.debugDescription)
            if selected.contains("settings") { capture("06-settings") }
            if selected.contains("reminder") {
                let reminder = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Reminder")).firstMatch
                if reminder.exists { reminder.tap() } else { app.staticTexts["Reminder"].tap() }
                XCTAssertTrue(app.navigationBars["Reminder"].waitForExistence(timeout: 5))
                XCTAssertTrue(app.staticTexts["30 min before"].exists)
                capture("07-reminder")
                app.navigationBars.buttons.firstMatch.tap()
                XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
            }
        }
    }

    @MainActor
    func testCaptureAllScreens() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = launchArguments()
        app.launch()
        func capture(_ name: String) {
            XCTAssertFalse(app.staticTexts["Mock data"].exists)
            XCTAssertFalse(app.buttons["Review scenario"].exists)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        tapTab("Following", in: app)
        let united = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Manchester United")).firstMatch
        XCTAssertTrue(united.waitForExistence(timeout: 90))
        capture("01-following")
        united.tap()
        XCTAssertTrue(app.staticTexts["Upcoming fixtures"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Manchester United vs.")).firstMatch.exists)
        capture("02-team-detail")
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Manage competitions")).firstMatch.tap()
        XCTAssertTrue(app.switches["FA Cup"].waitForExistence(timeout: 90))
        capture("03-manage-competitions")
        app.buttons["Cancel"].tap()
        tapTab("Discover", in: app)
        let searchField = app.searchFields.firstMatch
        if !searchField.waitForExistence(timeout: 5) {
            let searchButton = app.buttons["Search"].firstMatch
            if searchButton.waitForExistence(timeout: 5) { searchButton.tap() }
        }
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        if app.keyboards.buttons["Done"].exists { app.keyboards.buttons["Done"].tap() }
        capture("04-discover")
        tapTab("Following", in: app)
        app.buttons["Competition filter"].tap()
        XCTAssertTrue(app.buttons["Premier League"].waitForExistence(timeout: 5))
        capture("05-competition-filter")
        app.buttons["Premier League"].tap()
        tapTab("Settings", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("06-settings")
        let reminder = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Reminder")).firstMatch
        if reminder.waitForExistence(timeout: 5) {
            reminder.tap()
        } else {
            XCTAssertTrue(app.staticTexts["Reminder"].waitForExistence(timeout: 5))
            app.staticTexts["Reminder"].tap()
        }
        XCTAssertTrue(app.navigationBars["Reminder"].waitForExistence(timeout: 5))
        capture("07-reminder")
        app.navigationBars.buttons.firstMatch.tap()
        let appearance = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Appearance")).firstMatch
        if appearance.waitForExistence(timeout: 5) {
            appearance.tap()
        } else {
            XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 5))
            app.staticTexts["Appearance"].tap()
        }
        XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 5))
        capture("08-appearance")
        app.terminate()
        app.launchArguments += ["-screenshot-empty"]
        app.launch()
        XCTAssertTrue(app.staticTexts["No followed teams"].waitForExistence(timeout: 10))
        capture("09-empty-following")
        // Relaunch verifies that a scenario never persists into the next run.
        app.terminate()
        app.launchArguments.removeLast()
        app.launch()
        XCTAssertTrue(united.waitForExistence(timeout: 10))
        // The same fixtures are ready for ordinary testing with a visible review header.
        app.terminate()
        app.launchArguments[0] = "-mock-data"
        app.launch()
        XCTAssertTrue(app.staticTexts["Mock data"].waitForExistence(timeout: 10))
        XCTAssertTrue(united.waitForExistence(timeout: 5))
        app.buttons["mock-scenario-picker"].tap()
        app.buttons["Empty library"].tap()
        XCTAssertTrue(app.staticTexts["No followed teams"].waitForExistence(timeout: 5))
        app.buttons["mock-scenario-picker"].tap()
        app.buttons["Typical library"].tap()
        XCTAssertTrue(united.waitForExistence(timeout: 5))
        // Leave the clean capture version visible for review.
        app.terminate()
        app.launchArguments[0] = "-screenshot-fixtures"
        app.launch()
        XCTAssertTrue(united.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Mock data"].exists)
    }
}
