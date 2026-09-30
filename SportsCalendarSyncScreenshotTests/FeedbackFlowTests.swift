import XCTest

/// Exercises native controls with isolated fixtures; never sends an email.
final class FeedbackFlowTests: XCTestCase {
    private let app = XCUIApplication()
    private let baseArguments = ["-mock-data"]

    private func launch(reset: Bool = true, invite: Bool = false) {
        continueAfterFailure = false
        app.launchArguments = baseArguments + (reset ? ["-feedback-reset"] : []) + (invite ? ["-feedback-invitation"] : [])
        app.launch()
    }

    override func tearDown() {
        if (testRun?.failureCount ?? 0) > 0 {
            capture("failure-state")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.lifetime = .keepAlways
            add(tree)
        }
        super.tearDown()
    }

    private func tapTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.exists && tab.isHittable { tab.tap(); return }
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", name)).allElementsBoundByIndex
        guard let button = matches.last(where: { $0.isHittable }) else { XCTFail("Missing tab: \(name)"); return }
        button.tap()
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<16 {
            if element.exists && element.isHittable { return }
            if app.frame.width < 600 {
                app.swipeUp()
                continue
            }
            let scroller = app.collectionViews.allElementsBoundByIndex.last(where: { $0.isHittable }) ?? app
            let above = element.exists && element.frame.maxY < scroller.frame.minY + 80
            let start = scroller.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.4 : 0.7))
            let end = scroller.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.7 : 0.4))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.exists && element.isHittable, "Cannot reveal \(element)")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFeedbackPrivacyFallbackAndDiscard() {
        launch()
        tapTab("Settings")
        let open = app.buttons["Send Feedback"]
        reveal(open); open.tap()
        XCTAssertTrue(app.navigationBars["Send Feedback"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Submit"].isEnabled)
        let message = app.descendants(matching: .any)["feedback-message"].firstMatch
        message.tap(); message.typeText("The event did not appear after refreshing.")
        XCTAssertTrue(app.buttons["Submit"].isEnabled)
        let details = app.switches["Include app and permission details"]
        reveal(details); details.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let preview = app.staticTexts["feedback-preview"]
        reveal(preview)
        XCTAssertFalse(preview.label.contains("iOS:"))
        XCTAssertTrue(preview.label.contains("The event did not appear"))
        capture("feedback-preview-privacy")
        app.buttons["Submit"].tap()
        let copy = app.buttons.matching(identifier: "Copy Feedback").allElementsBoundByIndex.last(where: { $0.isHittable })!
        copy.tap()
        XCTAssertTrue(app.alerts["Feedback"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "copied, not sent")).firstMatch.exists)
        app.alerts.buttons["OK"].tap()
        app.navigationBars["Send Feedback"].buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Discard"].waitForExistence(timeout: 3))
        app.buttons["Discard"].tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["Send Feedback"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
    }

    func testSurveyDraftSurvivesRelaunch() {
        launch()
        tapTab("Settings")
        let open = app.buttons["Take Three-Question Survey"]
        reveal(open); open.tap()
        XCTAssertTrue(app.navigationBars["Three-Question Survey"].waitForExistence(timeout: 5))
        capture("survey-introduction")
        XCTAssertFalse(app.buttons["Submit"].isEnabled)
        let choice = app.buttons["I’m still getting started"]
        reveal(choice); choice.tap()
        XCTAssertTrue(app.buttons["Submit"].isEnabled)
        let answer = app.descendants(matching: .any)["survey-frustrations"].firstMatch
        reveal(answer); answer.tap(); answer.typeText("I need clearer calendar setup instructions.")
        app.navigationBars["Three-Question Survey"].buttons["Cancel"].tap()
        app.terminate()
        launch(reset: false)
        tapTab("Settings")
        let resume = app.buttons["Continue Three-Question Survey"]
        reveal(resume); resume.tap()
        XCTAssertTrue(app.navigationBars["Three-Question Survey"].waitForExistence(timeout: 5))
        let saved = app.descendants(matching: .any)["survey-frustrations"].firstMatch
        reveal(saved)
        XCTAssertEqual(saved.value as? String, "I need clearer calendar setup instructions.")
        capture("survey-saved-draft")
        app.buttons["Submit"].tap()
        let copy = app.buttons.matching(identifier: "Copy Survey Answers").allElementsBoundByIndex.last(where: { $0.isHittable })!
        copy.tap()
        XCTAssertTrue(app.alerts["Survey"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "copied, not sent")).firstMatch.exists)
        app.alerts.buttons["OK"].tap()
        app.navigationBars["Three-Question Survey"].buttons["Cancel"].tap()
    }

    func testContextRequiresConsent() {
        launch()

        tapTab("Following")
        // Team row labels include fixture summaries; use the stable club identifier.
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "following-club-")).firstMatch
        reveal(row); row.tap()
        let report = app.buttons["Report Incorrect Fixture"]
        reveal(report); report.tap()
        XCTAssertTrue(app.buttons["Category"].exists || app.staticTexts["Incorrect Fixture"].exists)

        XCTAssertTrue(app.navigationBars["Send Feedback"].waitForExistence(timeout: 5))
        let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "Include context:")).firstMatch
        reveal(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        let preview = app.staticTexts["feedback-preview"]
        reveal(preview)
        XCTAssertFalse(preview.label.contains("Context:"))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        XCTAssertTrue(preview.label.contains("Context:"))
        capture("contextual-feedback")
        app.navigationBars["Send Feedback"].buttons["Cancel"].tap()
    }

    func testInvitationCanBeDeferred() {
        launch(invite: true)
        tapTab("Following")
        let invite = app.buttons["Take a Three-Question Survey"]
        reveal(invite)
        invite.tap()
        XCTAssertTrue(app.navigationBars["Three-Question Survey"].waitForExistence(timeout: 5))
        app.navigationBars["Three-Question Survey"].buttons["Cancel"].tap()
        XCTAssertFalse(invite.exists)
        app.terminate()
        launch(reset: false)
        tapTab("Following")
        XCTAssertFalse(invite.exists)
    }
}
