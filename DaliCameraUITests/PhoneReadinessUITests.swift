import XCTest

final class PhoneReadinessUITests: XCTestCase {
    @MainActor
    func testCameraControlPlacementAndBasicModes() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()

        let cameraControl = app.buttons["cameraControlButton"]
        XCTAssertTrue(cameraControl.waitForExistence(timeout: 15))
        XCTAssertEqual(cameraControl.label, "Camera controls")
        cameraControl.tap()

        XCTAssertTrue(app.navigationBars["Camera controls"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shutterControlsGroup"].exists)
        XCTAssertTrue(app.buttons["filterControlsGroup"].exists)
        XCTAssertTrue(app.buttons["capturePolishGroup"].exists)
        XCTAssertTrue(app.buttons["focusExposureControlsGroup"].exists)
        XCTAssertFalse(app.switches["automaticFilterSelection"].exists)
        app.buttons["focusExposureControlsGroup"].tap()
        XCTAssertTrue(app.segmentedControls["focusExposureMode"].exists)
        app.buttons["focusExposureControlsGroup"].tap()
        XCTAssertFalse(app.segmentedControls["shutterTimerPicker"].exists)
        app.buttons["shutterControlsGroup"].tap()
        XCTAssertTrue(app.segmentedControls["shutterTimerPicker"].exists)
        XCTAssertTrue(app.buttons["Off"].exists)
        XCTAssertTrue(app.buttons["3s"].exists)
        XCTAssertTrue(app.buttons["5s"].exists)
        XCTAssertTrue(app.buttons["10s"].exists)
        XCTAssertTrue(app.switches["voiceShutterToggle"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["voiceShutterStatus"].exists)
        XCTAssertTrue(app.buttons["shutterLongPressAction"].exists)
        XCTAssertFalse(app.segmentedControls["tapMeteringTarget"].exists)
        app.switches["voiceShutterToggle"].tap()
        XCTAssertTrue(app.textFields["voiceShutterCustomPhrase"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertEqual(app.buttons["cameraControlButton"].label, "Camera controls")
    }

    @MainActor
    func testCameraBrandUsesDaliCamName() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()

        let brand = app.staticTexts["cameraBrandName"]
        XCTAssertTrue(brand.waitForExistence(timeout: 15))
        XCTAssertEqual(brand.label, "Dali Cam")
    }

    @MainActor
    func testOnboardingIsDismissibleAndHelpCanBeReopened() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "NO"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["tutorialNextButton"].waitForExistence(timeout: 15))
        attachScreenshot("Welcome")
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Choose a posture package"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Choose a landscape package"].waitForExistence(timeout: 3))
        while app.buttons["Next"].exists {
            app.buttons["Next"].tap()
        }
        app.buttons["Start taking photos"].tap()
        app.tap()
        XCTAssertTrue(app.buttons["appSettingsButton"].waitForExistence(timeout: 5))
        app.buttons["appSettingsButton"].tap()
        XCTAssertTrue(app.buttons["cameraTutorialButton"].waitForExistence(timeout: 5))
        app.buttons["cameraTutorialButton"].tap()
        XCTAssertTrue(app.navigationBars["Quick Camera Tutorial"].waitForExistence(timeout: 5))
        app.buttons["Skip"].tap()
    }

    @MainActor
    func testCompactCoachingMenusAndGuidance() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["situationMenu"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["cameraControlButton"].exists)
        XCTAssertFalse(app.buttons["angleMenu"].exists)
        XCTAssertTrue(app.buttons["postureMenu"].exists)
        XCTAssertTrue(app.buttons["Turn coaching off"].exists)
        app.buttons["Turn coaching off"].tap()
        XCTAssertTrue(app.buttons["Turn coaching on"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["situationMenu"].exists)
        XCTAssertTrue(app.buttons["Take photo"].exists)
        app.buttons["Turn coaching on"].tap()
        XCTAssertTrue(app.buttons["postureMenu"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["angleMenu"].exists)

        app.buttons["postureMenu"].tap()
        XCTAssertTrue(app.navigationBars["Posture packages"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["naturalPostureOption"].exists)
        XCTAssertTrue(app.buttons["posturePackage_masculine"].exists)
        XCTAssertTrue(app.buttons["posturePackage_feminine"].exists)
        XCTAssertTrue(app.buttons["posturePackage_couples"].exists)
        XCTAssertFalse(app.buttons["postureOption_M1"].exists)
        app.buttons["naturalPostureOption"].tap()
        app.buttons["postureMenu"].tap()
        app.buttons["posturePackage_feminine"].tap()
        let handAtWaist = app.buttons["postureOption_F3"]
        for _ in 0..<12 where !handAtWaist.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(handAtWaist.isHittable)
        handAtWaist.tap()
        XCTAssertTrue(app.staticTexts["Hand at waist"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["activePostureThumbnail"].exists)
        XCTAssertTrue(app.staticTexts["Rest one hand lightly at your waist. Relax your other arm."].exists)
        XCTAssertTrue(app.staticTexts["Recommended angle: Eye level"].exists)
        XCTAssertTrue(app.staticTexts["Lighting: Soft, even front light"].exists)
        XCTAssertTrue(app.buttons["Next"].exists)
        let postureCard = app.descendants(matching: .any).matching(identifier: "activePostureCard").firstMatch
        XCTAssertTrue(postureCard.exists)
        postureCard.swipeLeft()
        XCTAssertTrue(app.staticTexts["Seated angled pose"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sit with your knees angled slightly to one side. Turn your face toward the camera."].exists)
        XCTAssertTrue(app.staticTexts["Recommended angle: Slightly high"].exists)
        XCTAssertEqual(app.buttons["postureMenu"].label, "Posture, Seated angled pose")
        postureCard.tap()
        XCTAssertTrue(app.navigationBars["Seated angled pose"].waitForExistence(timeout: 5))
        let examplePhoto = app.descendants(matching: .any).matching(identifier: "postureExamplePhoto").firstMatch
        XCTAssertTrue(examplePhoto.exists)
        XCTAssertTrue(app.staticTexts["Recommended camera angle: Slightly high"].exists)
        examplePhoto.swipeLeft()
        XCTAssertTrue(app.navigationBars["Over-shoulder glance"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["postureMenu"].label, "Posture, Over-shoulder glance")
        app.buttons["Done"].tap()
        app.buttons["postureMenu"].tap()
        app.buttons["posturePackage_feminine"].tap()
        let hairSweep = app.buttons["postureOption_F10"]
        for _ in 0..<12 where !hairSweep.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(hairSweep.isHittable)
        hairSweep.tap()
        XCTAssertTrue(app.staticTexts["Gentle hair sweep"].waitForExistence(timeout: 5))
        attachScreenshot("Camera portrait")

        app.buttons["postureMenu"].tap()
        app.buttons["posturePackage_couples"].tap()
        let couplePose = app.buttons["postureOption_CP1"]
        for _ in 0..<16 where !couplePose.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(couplePose.isHittable)
        couplePose.tap()
        XCTAssertTrue(app.staticTexts["Close standing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Stand close with your shoulders lightly touching. Turn both faces toward the camera and relax your outside arms."].waitForExistence(timeout: 5))

        app.buttons["postureMenu"].tap()
        app.buttons["naturalPostureOption"].tap()
        app.buttons["situationMenu"].tap()
        app.buttons["Landscape"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "landscapeGuidanceCard").firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["postureMenu"].exists)
        XCTAssertTrue(app.buttons["landscapeMenu"].exists)

        app.buttons["situationMenu"].tap()
        app.buttons["Action"].tap()
        XCTAssertTrue(app.staticTexts["Find the moving subject"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["postureMenu"].exists)

        app.buttons["situationMenu"].tap()
        app.buttons["Close-up"].tap()
        XCTAssertTrue(app.staticTexts["Choose one clear detail"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["postureMenu"].exists)

        app.buttons["situationMenu"].tap()
        app.buttons["Portrait"].tap()
        XCTAssertTrue(app.buttons["postureMenu"].waitForExistence(timeout: 5))
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
    func testQuickEffectsMenuControlsFilterAndBeautifier() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasSeenDaliTutor", "YES",
            "-filterApplicationMode", "off",
            "-beautifierApplicationMode", "off"
        ]
        app.launch()
        app.tap()

        let effects = app.buttons["effectsMenu"]
        XCTAssertTrue(effects.waitForExistence(timeout: 15))
        XCTAssertEqual(effects.label, "Effects, Filters Off, Beautifier Off")
        effects.tap()
        XCTAssertTrue(app.buttons["quickEffectsAuto"].waitForExistence(timeout: 3))
        app.buttons["quickEffectsAuto"].tap()
        XCTAssertEqual(effects.label, "Effects, Filters Auto, Beautifier Auto")

        effects.tap()
        XCTAssertTrue(app.buttons["quickBeautifierMode_off"].waitForExistence(timeout: 3))
        app.buttons["quickBeautifierMode_off"].tap()
        XCTAssertEqual(effects.label, "Effects, Filters Auto, Beautifier Off")
    }

    @MainActor
    func testMountainsLandscapePackageIsSelectable() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["situationMenu"].waitForExistence(timeout: 15))
        app.buttons["situationMenu"].tap()
        app.buttons["Landscape"].tap()

        XCTAssertTrue(app.buttons["landscapeMenu"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["postureMenu"].exists)
        app.buttons["landscapeMenu"].tap()
        XCTAssertTrue(app.navigationBars["Landscape packages"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["naturalLandscapeOption"].exists)
        XCTAssertTrue(app.buttons["landscapePackage_mountains"].exists)
        XCTAssertTrue(app.buttons["landscapePackage_lakes"].exists)
        XCTAssertTrue(app.buttons["landscapePackage_plains"].exists)
        XCTAssertTrue(app.buttons["landscapePackage_plants"].exists)
        XCTAssertFalse(app.buttons["landscapeOption_MT1"].exists)

        app.buttons["landscapePackage_mountains"].tap()
        XCTAssertTrue(app.navigationBars["Mountains"].waitForExistence(timeout: 5))

        let trailRecipe = app.buttons["landscapeOption_MT1"]
        XCTAssertTrue(trailRecipe.waitForExistence(timeout: 5))
        trailRecipe.tap()
        XCTAssertTrue(app.staticTexts["Foreground trail to peak"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Lower the camera near the trail. Use the trail to lead toward the peak."].exists)
        XCTAssertTrue(app.staticTexts["Recommended angle: Low angle"].exists)
        XCTAssertTrue(app.staticTexts["Best light: Sunrise or sunset"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "activeLandscapeCard").firstMatch.exists)

        app.descendants(matching: .any).matching(identifier: "activeLandscapeCard").firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Foreground trail to peak"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended camera angle: Low angle"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "landscapeSafetyNote").firstMatch.exists)
        app.buttons["Done"].tap()

        app.buttons["landscapeMenu"].tap()
        app.buttons["landscapePackage_lakes"].tap()
        let lakeRecipe = app.buttons["landscapeOption_LK1"]
        XCTAssertTrue(lakeRecipe.waitForExistence(timeout: 5))
        lakeRecipe.tap()
        XCTAssertTrue(app.staticTexts["Centered reflection"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Center the shoreline horizontally. Keep the reflected peak or trees fully visible."].exists)
        XCTAssertTrue(app.staticTexts["Best light: Sunrise or sunset"].exists)
    }

    @MainActor
    func testFoodPackageShowsHeroPlateGuidance() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["situationMenu"].waitForExistence(timeout: 15))
        app.buttons["situationMenu"].tap()
        app.buttons["Food"].tap()

        XCTAssertTrue(app.buttons["foodMenu"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["postureMenu"].exists)
        XCTAssertFalse(app.buttons["landscapeMenu"].exists)
        app.buttons["foodMenu"].tap()
        XCTAssertTrue(app.navigationBars["Food package"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["naturalFoodOption"].exists)

        let heroPlate = app.buttons["foodOption_FD1"]
        XCTAssertTrue(heroPlate.waitForExistence(timeout: 5))
        heroPlate.tap()
        XCTAssertTrue(app.staticTexts["Hero plate"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended angle: 45-degree angle"].exists)
        XCTAssertTrue(app.staticTexts["Best light: Soft window side light"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "activeFoodCard").firstMatch.exists)

        app.descendants(matching: .any).matching(identifier: "activeFoodCard").firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Hero plate"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended camera angle: 45-degree angle"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "foodSafetyNote").firstMatch.exists)
    }

    @MainActor
    func testCouplesPosturePackageIsSelectable() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["postureMenu"].waitForExistence(timeout: 15))
        app.buttons["postureMenu"].tap()
        XCTAssertTrue(app.navigationBars["Posture packages"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["postureOption_CP1"].exists)
        app.buttons["posturePackage_couples"].tap()

        let couplePose = app.buttons["postureOption_CP1"]
        for _ in 0..<16 where !couplePose.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(couplePose.isHittable)
        couplePose.tap()
        XCTAssertTrue(app.staticTexts["Close standing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Stand close with your shoulders lightly touching. Turn both faces toward the camera and relax your outside arms."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFriendsGroupsPackageShowsAngleAndLighting() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["postureMenu"].waitForExistence(timeout: 15))
        app.buttons["postureMenu"].tap()

        let groupPackage = app.buttons["posturePackage_friendsGroups"]
        for _ in 0..<6 where !groupPackage.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(groupPackage.isHittable)
        groupPackage.tap()

        let groupPose = app.buttons["postureOption_G1"]
        XCTAssertTrue(groupPose.waitForExistence(timeout: 5))
        groupPose.tap()
        XCTAssertTrue(app.staticTexts["Shoulder-to-shoulder row"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended angle: Eye level"].exists)
        XCTAssertTrue(app.staticTexts["Lighting: Broad, even light across every face"].exists)

        let postureCard = app.descendants(matching: .any).matching(identifier: "activePostureCard").firstMatch
        postureCard.tap()
        XCTAssertTrue(app.staticTexts["Recommended camera angle: Eye level"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended lighting: Broad, even light across every face"].exists)
    }

    @MainActor
    func testFamilyPackageIsSelectable() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["postureMenu"].waitForExistence(timeout: 15))
        app.buttons["postureMenu"].tap()

        let familyPackage = app.buttons["posturePackage_family"]
        for _ in 0..<8 where !familyPackage.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(familyPackage.isHittable)
        familyPackage.tap()

        let familyPose = app.buttons["postureOption_FA1"]
        XCTAssertTrue(familyPose.waitForExistence(timeout: 5))
        familyPose.tap()
        XCTAssertTrue(app.staticTexts["Family standing row"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended angle: Eye level"].exists)
        XCTAssertTrue(app.staticTexts["Lighting: Broad, even light across every face"].exists)
        XCTAssertTrue(app.staticTexts["Stand in one relaxed row with shorter family members near the center. Close the gaps gently and keep every face visible."].exists)
    }

    @MainActor
    func testGraduationPackageIsSelectableAndKeepsCapTossGrounded() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["postureMenu"].waitForExistence(timeout: 15))
        app.buttons["postureMenu"].tap()

        let graduationPackage = app.buttons["posturePackage_graduation"]
        for _ in 0..<10 where !graduationPackage.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(graduationPackage.isHittable)
        graduationPackage.tap()

        let capToss = app.buttons["postureOption_GR6"]
        for _ in 0..<10 where !capToss.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(capToss.isHittable)
        capToss.tap()
        XCTAssertTrue(app.staticTexts["Cap toss"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended angle: Low angle"].exists)
        XCTAssertTrue(app.staticTexts["Lighting: Soft golden-hour light"].exists)
        let safetyCue = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Keep both feet grounded")
        ).firstMatch
        XCTAssertTrue(safetyCue.exists)
    }

    @MainActor
    func testMaternityPackageIncludesComfortFirstHusbandPose() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["postureMenu"].waitForExistence(timeout: 15))
        app.buttons["postureMenu"].tap()

        let maternityPackage = app.buttons["posturePackage_maternity"]
        for _ in 0..<12 where !maternityPackage.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(maternityPackage.isHittable)
        maternityPackage.tap()

        let husbandWalk = app.buttons["postureOption_MT5"]
        for _ in 0..<10 where !husbandWalk.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(husbandWalk.isHittable)
        husbandWalk.tap()
        XCTAssertTrue(app.staticTexts["Walk with husband"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended angle: Eye level"].exists)
        XCTAssertTrue(app.staticTexts["Lighting: Soft golden-hour light"].exists)
        let comfortCue = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Hold hands and take one small, slow step")
        ).firstMatch
        XCTAssertTrue(comfortCue.exists)
    }

    @MainActor
    func testKidsPackageKeepsSuperheroPoseGrounded() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["postureMenu"].waitForExistence(timeout: 15))
        app.buttons["postureMenu"].tap()

        let kidsPackage = app.buttons["posturePackage_kids"]
        for _ in 0..<16 where !kidsPackage.isHittable { app.swipeUp() }
        XCTAssertTrue(kidsPackage.isHittable)
        kidsPackage.tap()

        let superhero = app.buttons["postureOption_K5"]
        for _ in 0..<10 where !superhero.isHittable { app.swipeUp() }
        XCTAssertTrue(superhero.isHittable)
        superhero.tap()
        XCTAssertTrue(app.staticTexts["Superhero stance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended angle: Low angle"].exists)
        let stableCue = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Plant both feet comfortably wide")
        ).firstMatch
        XCTAssertTrue(stableCue.waitForExistence(timeout: 5))
    }

    @MainActor
    func testNewbornPackageUsesSafeBackPoseAndCaregiverCoaching() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["postureMenu"].waitForExistence(timeout: 15))
        app.buttons["postureMenu"].tap()

        let newbornPackage = app.buttons["posturePackage_newborn"]
        for _ in 0..<18 where !newbornPackage.isHittable { app.swipeUp() }
        XCTAssertTrue(newbornPackage.isHittable)
        newbornPackage.tap()

        let safeBack = app.buttons["postureOption_NB1"]
        XCTAssertTrue(safeBack.waitForExistence(timeout: 5))
        safeBack.tap()
        XCTAssertTrue(app.staticTexts["Safe back pose"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended angle: Overhead"].exists)
        let safeCue = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Place the baby on their back")
        ).firstMatch
        XCTAssertTrue(safeCue.exists)
    }

    @MainActor
    func testProfessionalPackageShowsHeadshotGuidance() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["postureMenu"].waitForExistence(timeout: 15))
        app.buttons["postureMenu"].tap()

        let professionalPackage = app.buttons["posturePackage_professional"]
        for _ in 0..<6 where !professionalPackage.isHittable { app.swipeUp() }
        XCTAssertTrue(professionalPackage.isHittable)
        professionalPackage.tap()

        let classicHeadshot = app.buttons["postureOption_PR1"]
        XCTAssertTrue(classicHeadshot.waitForExistence(timeout: 5))
        classicHeadshot.tap()
        XCTAssertTrue(app.staticTexts["Classic headshot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended angle: Eye level"].exists)
        XCTAssertTrue(app.staticTexts["Lighting: Soft, even front light"].exists)
        XCTAssertTrue(app.staticTexts["Turn your shoulders slightly away from the camera. Bring your face back toward the lens and relax your jaw."].exists)
    }

    @MainActor
    func testWeddingPackageShowsStableProposalGuidance() {
        allowCameraPrompt()
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenDaliTutor", "YES"]
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["postureMenu"].waitForExistence(timeout: 15))
        app.buttons["postureMenu"].tap()

        let weddingPackage = app.buttons["posturePackage_weddingEngagement"]
        for _ in 0..<10 where !weddingPackage.isHittable { app.swipeUp() }
        XCTAssertTrue(weddingPackage.isHittable)
        weddingPackage.tap()

        let proposal = app.buttons["postureOption_WE3"]
        XCTAssertTrue(proposal.waitForExistence(timeout: 5))
        proposal.tap()
        XCTAssertTrue(app.staticTexts["One-knee proposal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended angle: From the side"].exists)
        XCTAssertTrue(app.staticTexts["Lighting: Soft golden-hour light"].exists)
        let stableProposalCue = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "On a flat, clear surface, lower onto one knee")
        ).firstMatch
        XCTAssertTrue(stableProposalCue.exists)
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
        XCTAssertTrue(app.staticTexts["Photo 1 of 3"].exists)
        let reviewPane = app.images["reviewImagePane"]
        XCTAssertTrue(reviewPane.exists)
        reviewPane.swipeLeft()
        XCTAssertTrue(app.staticTexts["Photo 2 of 3"].waitForExistence(timeout: 10))
        reviewPane.swipeRight()
        XCTAssertTrue(app.staticTexts["Photo 1 of 3"].waitForExistence(timeout: 10))
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
