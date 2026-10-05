import XCTest

final class PhoneReadinessUITests: XCTestCase {
    @MainActor
    func testOnboardingIsDismissibleAndHelpCanBeReopened() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "NO"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["Start taking photos"].waitForExistence(timeout: 15))
        attachScreenshot("Welcome")
        app.buttons["Start taking photos"].tap()
        app.tap()
        XCTAssertTrue(app.buttons["Help"].waitForExistence(timeout: 5))
        app.buttons["Help"].tap()
        XCTAssertTrue(app.navigationBars["Welcome to Dali"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }

    @MainActor
    func testPoseChooserAndLandscapeControls() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["Poses & angles"].waitForExistence(timeout: 15))
        attachScreenshot("Camera portrait")
        app.buttons["Poses & angles"].tap()
        XCTAssertTrue(app.navigationBars["Poses & angles"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Female / Feminine"].tap()
        attachScreenshot("Pose chooser")
        app.buttons["Cancel"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["Take photo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Configure"].isHittable)
        attachScreenshot("Camera landscape")
        app.buttons["Configure"].tap()
        XCTAssertTrue(app.navigationBars["Configure"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testLargeTextKeepsShutterAndHelpReachable() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["Take photo"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Help"].isHittable)
        attachScreenshot("Camera large text")
    }

    @MainActor
    private func allowCameraPrompt() {
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for label in ["Allow", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    @MainActor
    func testReviewActionsAndFullScreenPhoto() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launchEnvironment["DALI_UI_REVIEW"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["Save a copy"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Share"].exists)
        XCTAssertTrue(app.buttons["Back to camera"].exists)
        attachScreenshot("Photo review")
        app.buttons["Open full-screen photo"].tap()
        XCTAssertTrue(app.buttons["Close photo"].waitForExistence(timeout: 5))
        attachScreenshot("Full-screen photo")
        app.buttons["Close photo"].tap()
        XCTAssertTrue(app.buttons["Save a copy"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
