import XCTest

final class PhoneReadinessUITests: XCTestCase {
    @MainActor
    func testOnboardingIsDismissibleAndHelpCanBeReopened() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Start taking photos"].waitForExistence(timeout: 15))
        attachScreenshot("Welcome")
        app.buttons["Start taking photos"].tap()
        XCTAssertTrue(app.buttons["Help"].waitForExistence(timeout: 5))
        app.buttons["Help"].tap()
        XCTAssertTrue(app.navigationBars["Welcome to Dali"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }

    @MainActor
    func testPoseChooserAndLandscapeControls() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
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
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
