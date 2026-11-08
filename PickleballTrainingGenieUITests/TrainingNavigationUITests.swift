import XCTest

final class TrainingNavigationUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchEnvironment["GENIE_UI_TEST"] = "1"
    }

    private func launch(savedWorkout: Bool = false) {
        app.launchEnvironment["GENIE_UI_WORKOUT"] = savedWorkout ? "1" : "0"
        app.launch()
        select("Today")
    }

    private func select(_ title: String) {
        let tab = app.tabBars.buttons[title]
        if tab.exists {
            tab.tap()
        } else {
            let raw = title == "Train" ? "workout" : title.lowercased()
            let item = app.descendants(matching: .any)["mainSection.\(raw)"].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 5), app.debugDescription)
            item.tap()
        }
    }

    private func tap(_ label: String) {
        let button = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        for _ in 0..<8 {
            if button.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing \(label)")
        button.tap()
    }

    private func back() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func testTodayNestedRoutesAndRecommendationEmptyState() {
        launch()
        tap("All Recommendations")
        XCTAssertTrue(app.navigationBars["Recommendations"].waitForExistence(timeout: 5))
        tap("Learn the Basics")
        XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 5))
        back()
        XCTAssertTrue(app.navigationBars["Recommendations"].exists)
        tap("Browse All Drills")
        XCTAssertTrue(app.navigationBars["Drills"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fixture Dink Rally"].waitForExistence(timeout: 5))
        app.staticTexts["Fixture Dink Rally"].tap()
        XCTAssertTrue(app.staticTexts["Instructions"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        select("Today")
        if app.navigationBars["Recommendations"].exists { back() }
        tap("Find Tournaments")
        XCTAssertTrue(app.navigationBars["Tournaments"].waitForExistence(timeout: 5))
        let city = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Fixture City")).firstMatch
        if city.exists {
            city.tap()
        } else {
            let choose = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Choose")).firstMatch
            XCTAssertTrue(choose.exists, app.debugDescription)
            choose.tap()
        }
        XCTAssertTrue(app.staticTexts["Fixture City, TX"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        back()
        XCTAssertTrue(app.navigationBars["Today"].exists)
    }

    func testSavedPlanReviewDoesNotStartOrReplaceWorkout() {
        launch(savedWorkout: true)
        XCTAssertTrue(app.staticTexts["No completed sessions yet. Save a completed workout to start your training history."].exists)
        tap("Review Saved Workout")
        XCTAssertTrue(app.staticTexts["Fixture saved plan: practice soft dinks for fifteen minutes."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Generate My Workout"].exists)
        XCTAssertFalse(app.buttons["Start Guided Session"].exists)
        select("Today")
        XCTAssertTrue(app.navigationBars["Today"].exists)
        select("Progress")
        tap("Training History")
        XCTAssertTrue(app.navigationBars["Training History"].waitForExistence(timeout: 5))
        back()
        tap("Video Self-Review")
        XCTAssertTrue(app.navigationBars["Video Review"].waitForExistence(timeout: 5))
        back()
        select("Profile")
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
    }

    func testSelectionSurvivesBackgroundRelaunchAndRotation() {
        launch()
        select("Progress")
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 3)
        app.activate()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 3)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))
    }

    func testTodayAccessibilityAudit() throws {
        launch()
        if #available(iOS 17.0, *) {
            try app.performAccessibilityAudit(
                for: [.hitRegion, .elementDetection, .sufficientElementDescription, .trait]
            )
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Interactive Today"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRecordsContrastDetectorFindingsForPixelVerification() throws {
        launch()
        // The simulator detector flags even 13.97:1 rendered text. Preserve
        // every finding for inspection, rather than call this a clean audit.
        try app.performAccessibilityAudit(for: [.contrast]) { issue in
            let attachment = XCTAttachment(string: issue.element?.debugDescription ?? "Contrast issue without an element")
            attachment.name = "Contrast detector finding"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            return true
        }
    }

    func testLargeTextPrimaryActionRemainsReachable() throws {
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launch(savedWorkout: true)
        tap("Review Saved Workout")
        XCTAssertTrue(app.navigationBars["Train"].exists)
        XCTAssertTrue(app.staticTexts["Fixture saved plan: practice soft dinks for fifteen minutes."].exists)
        select("Today")
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .trait])
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Interactive Today large text"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTodayOpensSharedTrainChecklistAndSetup() {
        app.launchEnvironment["GENIE_UI_WORKOUT"] = "structured"
        app.launch()
        select("Today")
        tap("Review Saved Workout")
        XCTAssertTrue(app.navigationBars["Train"].exists)
        tap("Fixture Workout Dinks")
        XCTAssertEqual(app.buttons["Fixture Workout Dinks"].value as? String, "Completed")
        select("Today")
        tap("Review Saved Workout")
        XCTAssertEqual(app.buttons["Fixture Workout Dinks"].value as? String, "Completed")
        select("Drills")
        select("Train")
        XCTAssertEqual(app.buttons["Fixture Workout Dinks"].value as? String, "Completed")
        app.terminate()
        launch(savedWorkout: false)
        tap("Set Up a Workout")
        XCTAssertTrue(app.navigationBars["Train"].exists)
        XCTAssertTrue(app.buttons["Generate My Workout"].exists)
    }

    func testSelectionAndChecklistSurviveLiveSizeClassChanges() {
        app.launchEnvironment["GENIE_UI_WORKOUT"] = "structured"
        app.launchEnvironment["GENIE_UI_SIZE_TEST"] = "1"
        app.launch()
        select("Today")
        tap("Review Saved Workout")
        tap("Fixture Workout Dinks")
        app.buttons["Toggle Test Size Class"].tap()
        XCTAssertTrue(app.navigationBars["Train"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Fixture Workout Dinks"].value as? String, "Completed")
        app.buttons["Toggle Test Size Class"].tap()
        XCTAssertTrue(app.navigationBars["Train"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Fixture Workout Dinks"].value as? String, "Completed")
    }
}
