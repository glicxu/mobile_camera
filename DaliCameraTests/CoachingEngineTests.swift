import CoreGraphics
import UIKit
import XCTest

final class CoachingEngineTests: XCTestCase {
    func testWatermarkPreservesTheUnderlyingPhoto() throws {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 160)).image { context in
            UIColor(red: 0.82, green: 0.12, blue: 0.18, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 240, height: 160))
        }
        let signature = UIGraphicsImageRenderer(size: CGSize(width: 90, height: 30)).image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 90, height: 30))
            UIColor.white.setFill()
            context.fill(CGRect(x: 8, y: 10, width: 74, height: 8))
        }

        let output = DaliWatermarkRenderer.apply(to: photo, signature: signature)
        let bytes = try XCTUnwrap(rgbaBytes(output))
        let cgImage = try XCTUnwrap(output.cgImage)
        let sourceCGImage = try XCTUnwrap(photo.cgImage)
        let centerOffset = ((cgImage.height / 2) * cgImage.width + cgImage.width / 2) * 4

        XCTAssertGreaterThan(bytes[centerOffset], 180)
        XCTAssertLessThan(bytes[centerOffset + 1], 60)
        XCTAssertLessThan(bytes[centerOffset + 2], 70)
        XCTAssertEqual(cgImage.width, sourceCGImage.width)
        XCTAssertEqual(cgImage.height, sourceCGImage.height)
        XCTAssertEqual(output.size, photo.size)
    }

    func testCoachingToneStatusLabelsAreExplicit() {
        XCTAssertEqual(AdviceTone.ready.coachingStatusTitle, "Looks good")
        XCTAssertEqual(AdviceTone.ready.coachingStatusSymbol, "checkmark.circle.fill")
        XCTAssertEqual(AdviceTone.warning.coachingStatusTitle, "Needs attention")
        XCTAssertEqual(AdviceTone.danger.coachingStatusTitle, "Needs attention")
        XCTAssertEqual(AdviceTone.waiting.coachingStatusTitle, "Checking")
    }

    func testBeautifyLevelsHaveStableNamesAndClampTheirStrength() {
        let expectedNames = ["Original", "Natural", "Fresh", "Polished", "Glam", "Max"]
        for (level, name) in expectedNames.enumerated() {
            let settings = BeautifySettings(strength: level)
            XCTAssertEqual(settings.levelName, name)
            XCTAssertEqual(settings.normalizedStrength, Double(level) / 5, accuracy: 0.0001)
        }

        XCTAssertEqual(BeautifySettings(strength: -2).normalizedStrength, 0)
        XCTAssertEqual(BeautifySettings(strength: 8).normalizedStrength, 1)
        XCTAssertEqual(BeautifySettings(strength: 8).levelName, "Max")
        XCTAssertTrue(BeautifySettings().landscapeSkyEnabled)
        XCTAssertTrue(BeautifySettings().landscapeColorEnabled)
    }

    func testEnhanceLevelsHaveStableNamesAndClampTheirStrength() {
        let expectedNames = ["Original", "Natural", "Balanced", "Vivid", "Dramatic", "Max"]
        for (level, name) in expectedNames.enumerated() {
            let settings = EnhanceSettings(strength: level)
            XCTAssertEqual(settings.levelName, name)
            XCTAssertEqual(settings.normalizedStrength, Double(level) / 5, accuracy: 0.0001)
        }

        XCTAssertEqual(EnhanceSettings(strength: -1).normalizedStrength, 0)
        XCTAssertEqual(EnhanceSettings(strength: 9).normalizedStrength, 1)
        XCTAssertEqual(EnhanceSettings(strength: 9).levelName, "Max")
    }

    func testLandscapeBeautifyChangesRenderedPixels() {
        let size = CGSize(width: 120, height: 160)
        let original = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 0.34, green: 0.58, blue: 0.74, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: 100))
            UIColor(white: 0.92, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 18, y: 28, width: 48, height: 20))
            context.cgContext.fillEllipse(in: CGRect(x: 55, y: 18, width: 42, height: 24))
            UIColor(red: 0.34, green: 0.48, blue: 0.29, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 100, width: size.width, height: 60))
        }

        let normalOutput = BeautifyEngine().apply(
            to: original,
            measurements: measurements(personBox: nil, faceBox: nil, skyOrOpenAreaRatio: 0.65),
            settings: BeautifySettings(strength: 3)
        )
        let output = BeautifyEngine().apply(
            to: original,
            measurements: measurements(personBox: nil, faceBox: nil, skyOrOpenAreaRatio: 0.65),
            settings: BeautifySettings(strength: 5)
        )

        XCTAssertTrue(output.result.landscapeApplied)
        XCTAssertTrue(output.result.landscapeColorApplied)
        XCTAssertTrue(output.result.skyApplied)
        XCTAssertGreaterThan(meanRGBDifference(original, normalOutput.image), 4.0)
        XCTAssertGreaterThan(meanRGBDifference(original, output.image), 4.0)
        XCTAssertGreaterThan(meanRGBDifference(normalOutput.image, output.image), 2.0)
    }

    func testAutoPhotoFiltersFollowTheDetectedSituation() {
        XCTAssertEqual(
            PhotoFilterChoice.namedPresets.map(\.title),
            ["Natural", "Soft", "Bright", "Vivid", "Blue Sky", "Golden", "Fresh", "Night Clear"]
        )
        XCTAssertEqual(PhotoFilterChoice.auto.resolved(for: .portrait), .natural)
        XCTAssertEqual(PhotoFilterChoice.auto.resolved(for: .group), .natural)
        XCTAssertEqual(PhotoFilterChoice.auto.resolved(for: .personScene), .natural)
        XCTAssertEqual(PhotoFilterChoice.auto.resolved(for: .landscape), .blueSky)
        XCTAssertEqual(PhotoFilterChoice.auto.resolved(for: .action), .vivid)
        XCTAssertEqual(PhotoFilterChoice.auto.resolved(for: .closeUp), .bright)
        XCTAssertEqual(PhotoFilterChoice.auto.resolved(for: .food), .fresh)
        XCTAssertEqual(PhotoFilterChoice.golden.resolved(for: .landscape), .golden)
    }

    func testCapturePolishReusesReviewTreatmentsAtFiveLevels() {
        XCTAssertEqual(
            CapturePolishChoice.allCases.map(\.title),
            ["Off", "General Enhance", "Portrait Polish", "Landscape Polish"]
        )
        XCTAssertEqual((1...5).map(CapturePolishChoice.levelName), ["Light", "Natural", "Polished", "Strong", "Max"])
    }

    func testBeautifierPresetsKeepPortraitAndLandscapeSettingsSeparate() {
        XCTAssertEqual(EffectApplicationMode.allCases.map(\.title), ["Auto", "Custom", "Off"])
        XCTAssertEqual(FocusExposureMode.allCases.map(\.title), ["Auto", "Manual"])
        let naturalPortrait = PortraitBeautifierPreset.natural.defaultSettings
        XCTAssertEqual(naturalPortrait.strength, 2)
        XCTAssertTrue(naturalPortrait.skinSmoothingEnabled)
        XCTAssertFalse(naturalPortrait.eyeEnlargementEnabled)
        XCTAssertFalse(naturalPortrait.landscapeColorEnabled)

        let glamPortrait = PortraitBeautifierPreset.glam.defaultSettings
        XCTAssertEqual(glamPortrait.strength, 4)
        XCTAssertTrue(glamPortrait.eyeEnlargementEnabled)
        XCTAssertTrue(glamPortrait.lipPlumpingEnabled)

        let naturalLandscape = LandscapeBeautifierPreset.natural.defaultSettings
        XCTAssertEqual(naturalLandscape.strength, 2)
        XCTAssertTrue(naturalLandscape.landscapeColorEnabled)
        XCTAssertFalse(naturalLandscape.landscapeSkyEnabled)
        XCTAssertFalse(naturalLandscape.skinSmoothingEnabled)

        let dramaticLandscape = LandscapeBeautifierPreset.dramatic.defaultSettings
        XCTAssertEqual(dramaticLandscape.strength, 4)
        XCTAssertTrue(dramaticLandscape.landscapeSkyEnabled)
        XCTAssertTrue(dramaticLandscape.landscapeColorEnabled)
    }

    func testPhotoFilterStrengthChangesRenderedPixels() {
        let size = CGSize(width: 80, height: 80)
        let original = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 0.30, green: 0.52, blue: 0.68, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let engine = PhotoFilterEngine()
        let none = engine.apply(to: original, preset: .none, strength: 5)
        let vivid = engine.apply(to: original, preset: .vivid, strength: 3)

        XCTAssertEqual(meanRGBDifference(original, none), 0, accuracy: 0.01)
        XCTAssertGreaterThan(meanRGBDifference(original, vivid), 2)
    }

    func testVoiceShutterRecognizesOnlyTakePhotoCommands() {
        XCTAssertTrue(VoiceShutterCommand.matches("Cheese"))
        XCTAssertTrue(VoiceShutterCommand.matches("Okay, cheese!"))
        XCTAssertTrue(VoiceShutterCommand.matches("Take photo"))
        XCTAssertTrue(VoiceShutterCommand.matches("Please take a photo now"))
        XCTAssertTrue(VoiceShutterCommand.matches("take picture"))
        XCTAssertTrue(VoiceShutterCommand.matches("Okay, take a picture!"))
        XCTAssertTrue(VoiceShutterCommand.matches("Hey Dali, capture a photo please"))
        XCTAssertTrue(VoiceShutterCommand.matches("Could you snap a picture now?"))
        XCTAssertTrue(VoiceShutterCommand.matches("Say cheese now"))
        XCTAssertFalse(VoiceShutterCommand.matches("Take a break"))
        XCTAssertFalse(VoiceShutterCommand.matches("Beautiful photo"))
        XCTAssertFalse(VoiceShutterCommand.matches("Cheesecake"))
        XCTAssertFalse(VoiceShutterCommand.matches("Capture the moment"))
        XCTAssertEqual(VoiceShutterCommand.spokenExamples.count, 5)
    }

    func testVoiceShutterRecognizesUserPhraseAsWholeWords() {
        XCTAssertTrue(VoiceShutterCommand.matches("Okay, smile now!", customPhrase: "smile now"))
        XCTAssertTrue(VoiceShutterCommand.matches("DALI GO", customPhrase: "Dali go"))
        XCTAssertFalse(VoiceShutterCommand.matches("smiley now", customPhrase: "smile"))
        XCTAssertFalse(VoiceShutterCommand.matches("anything", customPhrase: ""))
    }

    func testShutterTimerOffersStandardDelays() {
        XCTAssertEqual(ShutterTimerDelay.allCases.map(\.rawValue), [0, 3, 5, 10])
        XCTAssertEqual(ShutterTimerDelay.allCases.map(\.title), ["Off", "3s", "5s", "10s"])
    }

    func testLongPressShutterOffersBurstByDefault() {
        XCTAssertEqual(ShutterLongPressAction.burst.rawValue, "burst")
        XCTAssertEqual(
            ShutterLongPressAction.allCases.map(\.title),
            ["Burst", "Timer", "Disabled"]
        )
        XCTAssertTrue(ShutterLongPressAction.burst.description.contains("release to stop"))
    }

    func testCameraControlCapabilitiesClampValuesPerActiveCamera() {
        var capabilities = CameraControlCapabilities.unavailable
        capabilities.minimumExposureBias = -2
        capabilities.maximumExposureBias = 1.5
        capabilities.minimumISO = 32
        capabilities.maximumISO = 1_600
        capabilities.minimumExposureDurationSeconds = 1.0 / 8_000.0
        capabilities.maximumExposureDurationSeconds = 1
        capabilities.minimumLensAperture = 1.4
        capabilities.maximumLensAperture = 4
        XCTAssertEqual(capabilities.clampedExposureBias(-3), -2)
        XCTAssertEqual(capabilities.clampedExposureBias(0.7), 0.7)
        XCTAssertEqual(capabilities.clampedExposureBias(2), 1.5)
        XCTAssertEqual(capabilities.clampedISO(20), 32)
        XCTAssertEqual(capabilities.clampedISO(3_200), 1_600)
        XCTAssertEqual(capabilities.clampedExposureDuration(1.0 / 10_000.0), 1.0 / 8_000.0)
        XCTAssertEqual(capabilities.clampedExposureDuration(2), 1)
        XCTAssertEqual(capabilities.clampedLensAperture(1), 1.4)
        XCTAssertEqual(capabilities.clampedLensAperture(8), 4)
        XCTAssertEqual(
            capabilities.linkedISO(baseExposureProduct: 1, shutterSeconds: 1.0 / 250.0, adjustmentEV: 0),
            250,
            accuracy: 0.001
        )
        XCTAssertEqual(
            capabilities.linkedISO(baseExposureProduct: 1, shutterSeconds: 1.0 / 250.0, adjustmentEV: 1),
            500,
            accuracy: 0.001
        )
        XCTAssertEqual(
            capabilities.linkedISO(baseExposureProduct: 1, shutterSeconds: 1.0 / 2_000.0, adjustmentEV: 1),
            1_600,
            accuracy: 0.001
        )
    }

    func testAdvancedControlsIncludeProExposurePrograms() {
        XCTAssertEqual(ProExposureProgram.allCases.map(\.title), ["Manual", "Tv", "Av"])
        XCTAssertEqual(TapMeteringTarget.allCases.map(\.title), ["AF + AE", "Focus", "Exposure"])
        XCTAssertTrue(TapMeteringTarget.focusAndExposure.includesFocus)
        XCTAssertTrue(TapMeteringTarget.focusAndExposure.includesExposure)
        XCTAssertTrue(TapMeteringTarget.focus.includesFocus)
        XCTAssertFalse(TapMeteringTarget.focus.includesExposure)
        XCTAssertFalse(TapMeteringTarget.exposure.includesFocus)
        XCTAssertTrue(TapMeteringTarget.exposure.includesExposure)
    }

    func testReviewTreatmentsAreSeparateAndUserSelectable() {
        XCTAssertEqual(
            ReviewTreatment.allCases.map(\.title),
            ["Portrait Polish", "Landscape Polish", "General Enhance"]
        )
        XCTAssertEqual(ReviewTreatment.allCases.map(\.shortTitle), ["Portrait", "Landscape", "Enhance"])
    }

    func testAssistedRecommendationsPrioritizeMotionAndApplyAvailableControls() {
        let engine = AssistedRecommendationEngine()
        let capabilities = cameraCapabilities(exposureBias: 0, duration: 1.0 / 20.0, iso: 1000)
        let moving = measurements(subjectMotion: 0.3)

        XCTAssertEqual(
            engine.recommendation(
                measurements: moving,
                capabilities: capabilities,
                shutterTimerSeconds: 5,
                recentCaptureCount: 0
            )?.action,
            .setShutterTimer(0)
        )
        XCTAssertEqual(
            engine.recommendation(
                measurements: measurements(cameraMotion: 0.35, cameraStable: false),
                capabilities: cameraCapabilities(),
                shutterTimerSeconds: 0,
                recentCaptureCount: 0
            )?.action,
            .setShutterTimer(3)
        )
    }

    func testAssistedRecommendationsCoverExposureAndConsistentSeries() {
        let engine = AssistedRecommendationEngine()
        let brightSky = measurements(
            personBox: nil,
            faceBox: nil,
            faceLuminance: nil,
            backgroundLuminance: 205,
            skyOrOpenAreaRatio: 0.5
        )
        XCTAssertEqual(
            engine.recommendation(
                measurements: brightSky,
                capabilities: cameraCapabilities(),
                shutterTimerSeconds: 0,
                recentCaptureCount: 0
            )?.kind,
            .brightSky
        )

        let darkFace = measurements(faceLuminance: 75, backgroundLuminance: 135, skyOrOpenAreaRatio: 0.05)
        XCTAssertEqual(
            engine.recommendation(
                measurements: darkFace,
                capabilities: cameraCapabilities(),
                shutterTimerSeconds: 0,
                recentCaptureCount: 0
            )?.action,
            .setExposureBias(0.3)
        )

        let consistent = engine.recommendation(
            measurements: measurements(
                personBox: nil,
                faceBox: nil,
                faceLuminance: nil,
                backgroundLuminance: 120,
                skyOrOpenAreaRatio: 0.05
            ),
            capabilities: cameraCapabilities(),
            shutterTimerSeconds: 0,
            recentCaptureCount: 2
        )
        XCTAssertEqual(consistent?.action, .lockFocusAndExposure)
    }

    func testEveryManualSituationProvidesIntegratedAngles() {
        for situation in PhotographicSituation.allCases where situation != .auto {
            XCTAssertGreaterThanOrEqual(situation.angleChoices.count, 3, "Missing angles for \(situation.title)")
            XCTAssertTrue(situation.angleChoices.allSatisfy { !$0.title.isEmpty && !$0.instruction.isEmpty })
        }
        XCTAssertEqual(PhotographicSituation.closeUp.angleChoices.first, .overhead)
        XCTAssertEqual(PhotographicSituation.landscape.angleChoices.first, .low)
        XCTAssertEqual(PhotographicSituation.food.angleChoices.first, .fortyFive)
        XCTAssertEqual(CameraAngleChoice.slightlyHigh.guidedPosition, .elevated)
    }

    func testSituationClassifierRecognizesSupportedAutomaticSituations() {
        let portrait = DetectionBox(
            rect: CGRect(x: 0.2, y: 0.08, width: 0.55, height: 0.72),
            confidence: 0.9,
            label: "person"
        )
        XCTAssertEqual(SituationClassifier.candidate(for: measurements(personBox: portrait)), .portrait)

        let personInScene = DetectionBox(
            rect: CGRect(x: 0.4, y: 0.25, width: 0.16, height: 0.42),
            confidence: 0.85,
            label: "person"
        )
        XCTAssertEqual(SituationClassifier.candidate(for: measurements(personBox: personInScene, faceBox: nil)), .personScene)

        let group = GroupAnalysis(
            peopleCount: 3,
            faceCount: 3,
            groupBounds: CGRect(x: 0.1, y: 0.15, width: 0.8, height: 0.7),
            faceVisibilityRatio: 1,
            edgeCrowdingScore: 0,
            spacingScore: 1
        )
        XCTAssertEqual(SituationClassifier.candidate(for: measurements(groupAnalysis: group)), .group)
        XCTAssertEqual(
            SituationClassifier.candidate(for: measurements(personBox: nil, faceBox: nil, horizonAngleDegrees: 0, horizonConfidence: 0.72)),
            .landscape
        )

        XCTAssertEqual(
            SituationClassifier.candidate(for: measurements(personBox: personInScene, faceBox: nil, subjectMotion: 0.22)),
            .action
        )

        let closeObject = DetectionBox(
            rect: CGRect(x: 0.2, y: 0.2, width: 0.62, height: 0.55),
            confidence: 0.78,
            label: "salient_object"
        )
        XCTAssertEqual(
            SituationClassifier.candidate(for: measurements(personBox: nil, faceBox: nil, salientObjectBox: closeObject, skyOrOpenAreaRatio: 0.08)),
            .closeUp
        )
    }

    func testSituationClassifierRequiresStableFramesAndKeepsAmbiguousRecommendation() {
        var classifier = SituationClassifier(requiredStableFrames: 3)
        let group = GroupAnalysis(
            peopleCount: 2,
            faceCount: 2,
            groupBounds: CGRect(x: 0.1, y: 0.15, width: 0.8, height: 0.7),
            faceVisibilityRatio: 1,
            edgeCrowdingScore: 0,
            spacingScore: 1
        )
        let groupMeasurements = measurements(groupAnalysis: group)
        XCTAssertEqual(classifier.update(with: groupMeasurements), .personScene)
        XCTAssertEqual(classifier.update(with: groupMeasurements), .personScene)
        XCTAssertEqual(classifier.update(with: groupMeasurements), .group)

        var ambiguous = measurements(personBox: nil, faceBox: nil, horizonAngleDegrees: nil, horizonConfidence: 0)
        ambiguous.skyOrOpenAreaRatio = 0.05
        XCTAssertEqual(classifier.update(with: ambiguous), .group)
    }

    func testSituationClassifierDoesNotOverreactToSmallMotionOrObjects() {
        let person = DetectionBox(
            rect: CGRect(x: 0.4, y: 0.25, width: 0.16, height: 0.42),
            confidence: 0.85,
            label: "person"
        )
        XCTAssertEqual(
            SituationClassifier.candidate(for: measurements(personBox: person, faceBox: nil, subjectMotion: 0.15)),
            .personScene
        )

        let smallObject = DetectionBox(
            rect: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2),
            confidence: 0.9,
            label: "salient_object"
        )
        XCTAssertNil(
            SituationClassifier.candidate(for: measurements(personBox: nil, faceBox: nil, salientObjectBox: smallObject, skyOrOpenAreaRatio: 0.08))
        )
        XCTAssertNil(
            SituationClassifier.candidate(for: measurements(personBox: nil, faceBox: nil, skyOrOpenAreaRatio: 0.42))
        )
    }

    func testPreviewGeometryFitsTheWholeFrameInPortraitAndLandscape() {
        let portrait = PreviewGeometry.fittedRect(in: CGSize(width: 390, height: 500), aspectRatio: 3.0 / 4.0)
        XCTAssertEqual(portrait, CGRect(x: 7.5, y: 0, width: 375, height: 500))
        let landscape = PreviewGeometry.fittedRect(in: CGSize(width: 500, height: 300), aspectRatio: 4.0 / 3.0)
        XCTAssertEqual(landscape, CGRect(x: 50, y: 0, width: 400, height: 300))
        XCTAssertEqual(PreviewGeometry.fittedRect(in: .zero, aspectRatio: 1), .zero)
    }

    func testGravityRollIsRelativeToDisplayRotationAndMirroring() {
        XCTAssertEqual(PreviewGeometry.rollDegrees(gravityX: 0, gravityY: -1, rotation: 90, mirrored: false), 0, accuracy: 0.001)
        XCTAssertEqual(PreviewGeometry.rollDegrees(gravityX: -1, gravityY: 0, rotation: 0, mirrored: false), 0, accuracy: 0.001)
        XCTAssertEqual(PreviewGeometry.rollDegrees(gravityX: 1, gravityY: 0, rotation: 180, mirrored: false), 0, accuracy: 0.001)
        let back = PreviewGeometry.rollDegrees(gravityX: 0.1, gravityY: -0.99, rotation: 90, mirrored: false)
        let front = PreviewGeometry.rollDegrees(gravityX: 0.1, gravityY: -0.99, rotation: 90, mirrored: true)
        XCTAssertEqual(front, -back, accuracy: 0.001)
        XCTAssertEqual(PreviewGeometry.rollDegrees(gravityX: 0, gravityY: 0, rotation: 90, mirrored: false), 0)
    }

    func testDirectionSymbolsDistinguishCameraRotationFromSubjectDirection() {
        let camera = Advice(type: "camera_tilted", recipient: "Photographer", instruction: "Tilt left", tone: .warning)
        let subject = Advice(type: "face_too_profile", recipient: "Subject", instruction: "Turn left", tone: .warning)
        XCTAssertNotEqual(camera.directionSymbol, subject.directionSymbol)
    }

    func testAdviceProducesSpecificVisualMovementGuidance() {
        XCTAssertEqual(advice("Move left").visualGuidanceDirection, .left)
        XCTAssertEqual(advice("Move a little to your right around the subject.").visualGuidanceDirection, .right)
        XCTAssertEqual(advice("Raise camera").visualGuidanceDirection, .up)
        XCTAssertEqual(advice("Lower the camera to their chest level.").visualGuidanceDirection, .down)
        XCTAssertEqual(advice("Step closer").visualGuidanceDirection, .closer)
        XCTAssertEqual(advice("Step back").visualGuidanceDirection, .farther)
        XCTAssertEqual(advice("Tilt left").visualGuidanceDirection, .rotateLeft)
        XCTAssertEqual(advice("Tilt right").visualGuidanceDirection, .rotateRight)
        XCTAssertNil(advice("Hold steady").visualGuidanceDirection)
    }
    func testGuidanceCatalogHasElevenPackagesSeventySixPosesAndFiveCameraPositions() {
        XCTAssertEqual(GuidedPoseCollectionID.allCases.count, 11)
        XCTAssertEqual(Set(GuidedPose.allCases.map(\.id)).count, 76)
        XCTAssertEqual(GuidedPose.allCases.filter { $0.package == .masculine }.count, 9)
        XCTAssertEqual(GuidedPose.allCases.filter { $0.package == .feminine }.count, 13)
        XCTAssertEqual(GuidedPose.allCases.filter { $0.package == .professional }.count, 6)
        XCTAssertEqual(GuidedPose.allCases.filter { $0.package == .couples }.count, 6)
        XCTAssertEqual(GuidedPose.allCases.filter { $0.package == .weddingEngagement }.count, 6)
        XCTAssertEqual(GuidedPose.allCases.filter { $0.package == .friendsGroups }.count, 6)
        XCTAssertEqual(GuidedPose.allCases.filter { $0.package == .family }.count, 6)
        XCTAssertEqual(GuidedPose.allCases.filter { $0.package == .graduation }.count, 6)
        XCTAssertEqual(GuidedPose.allCases.filter { $0.package == .maternity }.count, 6)
        XCTAssertEqual(GuidedPose.allCases.filter { $0.package == .kids }.count, 6)
        XCTAssertEqual(GuidedPose.allCases.filter { $0.package == .newborn }.count, 6)
        XCTAssertEqual(Set(GuidedCameraPosition.allCases.map(\.id)).count, 5)
        for pose in GuidedPose.allCases {
            XCTAssertEqual(pose.steps.count, 2)
            XCTAssertFalse(pose.symbol.isEmpty)
            XCTAssertFalse(pose.instruction.isEmpty)
            XCTAssertFalse(pose.exampleAssetName.isEmpty)
            let maternityCouplePoses: Set<GuidedPose> = [.maternityHusbandEmbrace, .maternityHusbandWalk, .maternityHusbandFaceToFace]
            let expectedRecipient: String
            if pose.package == .couples || pose.package == .weddingEngagement || maternityCouplePoses.contains(pose) {
                expectedRecipient = "Couple"
            } else if pose.package == .friendsGroups {
                expectedRecipient = "Group"
            } else if pose.package == .family {
                expectedRecipient = "Family"
            } else if pose.package == .newborn {
                expectedRecipient = "Caregiver"
            } else if pose == .kidsSiblingSideHug {
                expectedRecipient = "Children"
            } else if pose.package == .kids {
                expectedRecipient = "Child"
            } else {
                expectedRecipient = "Subject"
            }
            XCTAssertTrue(pose.steps.allSatisfy { $0.recipient == expectedRecipient && !$0.instruction.isEmpty })
            XCTAssertFalse(pose.recommendedCameraAngle.title.isEmpty)
            XCTAssertFalse(pose.recommendedLighting.title.isEmpty)
            XCTAssertFalse(pose.recommendedLighting.instruction.isEmpty)
        }
        XCTAssertEqual(Set(GuidedPose.allCases.map(\.category)), Set(PoseCategory.allCases))
        XCTAssertEqual(GuidedPose.walking.setting, .outdoor)
        XCTAssertEqual(GuidedPose.wallLeanMasculine.setting, .both)
        XCTAssertEqual(GuidedPose.hairSweepFeminine.category, .handsHair)
        for position in GuidedCameraPosition.allCases {
            XCTAssertTrue(position.steps(moveRight: false).allSatisfy { $0.recipient == "Photographer" })
        }
    }

    func testEveryPoseRecommendsCameraAngleAndLighting() {
        XCTAssertEqual(GuidedPose.relaxedStanding.recommendedCameraAngle, .eyeLevel)
        XCTAssertEqual(GuidedPose.handInPocket.recommendedCameraAngle, .eyeLevel)
        XCTAssertEqual(GuidedPose.handAtWaist.recommendedCameraAngle, .eyeLevel)
        XCTAssertEqual(GuidedPose.walking.recommendedCameraAngle, .low)
        XCTAssertEqual(GuidedPose.seatedAngle.recommendedCameraAngle, .slightlyHigh)
        XCTAssertEqual(GuidedPose.overShoulder.recommendedCameraAngle, .side)
        XCTAssertEqual(GuidedPose.walking.recommendedLighting, .openShade)
        XCTAssertEqual(GuidedPose.groupShoulderRow.recommendedLighting, .broadEven)
        XCTAssertEqual(GuidedPose.graduationCapToss.recommendedCameraAngle, .low)
        XCTAssertEqual(GuidedPose.graduationCapToss.recommendedLighting, .goldenHour)
        XCTAssertTrue(GuidedPose.graduationCapToss.cues.first?.contains("feet grounded") == true)
        XCTAssertEqual(GuidedPose.maternitySeatedSupport.recommendedCameraAngle, .slightlyHigh)
        XCTAssertEqual(GuidedPose.maternitySideProfile.recommendedLighting, .openShade)
        XCTAssertEqual(GuidedPose.maternityHusbandWalk.recommendedLighting, .goldenHour)
        XCTAssertTrue(GuidedPose.maternityHusbandWalk.cues.first?.contains("slow step") == true)
        XCTAssertEqual(GuidedPose.kidsSuperhero.recommendedCameraAngle, .low)
        XCTAssertTrue(GuidedPose.kidsSuperhero.cues.last?.contains("feet grounded") == true)
        XCTAssertTrue(GuidedPose.kidsPeekAround.cues.first?.contains("without climbing") == true)
        XCTAssertEqual(GuidedPose.newbornSafeBack.category, .lying)
        XCTAssertEqual(GuidedPose.newbornSafeBack.recommendedCameraAngle, .overhead)
        XCTAssertTrue(GuidedPose.newbornSafeBack.cues.first?.contains("on their back") == true)
        XCTAssertTrue(GuidedPose.newbornSeatedCradle.cues.first?.contains("head, neck, and body support") == true)
        XCTAssertEqual(GuidedPose.professionalClassicHeadshot.recommendedCameraAngle, .eyeLevel)
        XCTAssertEqual(GuidedPose.professionalThreeQuarter.recommendedLighting, .softSide)
        XCTAssertEqual(GuidedPose.professionalSeatedForward.recommendedCameraAngle, .slightlyHigh)
        XCTAssertEqual(GuidedPose.professionalEnvironmental.setting, .indoor)
        XCTAssertEqual(GuidedPose.weddingProposalReaction.recommendedCameraAngle, .side)
        XCTAssertEqual(GuidedPose.weddingProposalReaction.recommendedLighting, .goldenHour)
        XCTAssertEqual(GuidedPose.weddingProposalReaction.category, .kneeling)
        XCTAssertEqual(GuidedPose.weddingCelebrationWalk.recommendedCameraAngle, .low)
        XCTAssertTrue(GuidedPose.weddingProposalReaction.cues.first?.contains("flat, clear surface") == true)
    }

    func testLandscapeCatalogHasFourCompletePackagesAndTwentyFourRecipes() {
        let recipes = LandscapeCompositionRecipe.allCases
        XCTAssertEqual(recipes.count, 24)
        XCTAssertEqual(Set(recipes.map(\.id)).count, 24)
        XCTAssertEqual(LandscapeCompositionPackageID.allCases.count, 4)
        for package in LandscapeCompositionPackageID.allCases {
            XCTAssertEqual(recipes.filter { $0.package == package }.count, 6)
        }
        XCTAssertTrue(recipes.allSatisfy {
            !$0.title.isEmpty &&
            $0.cues.count == 2 &&
            $0.cues.allSatisfy { !$0.isEmpty } &&
            !$0.exampleAssetName.isEmpty &&
            !$0.recommendedLight.title.isEmpty &&
            !$0.recommendedLight.instruction.isEmpty &&
            !$0.safetyNote.isEmpty
        })
        XCTAssertEqual(LandscapeCompositionRecipe.mountainTrail.recommendedCameraAngle, .low)
        XCTAssertEqual(LandscapeCompositionRecipe.valleyAbove.recommendedCameraAngle, .slightlyHigh)
        XCTAssertEqual(LandscapeCompositionRecipe.mountainDetail.recommendedCameraAngle, .side)
        XCTAssertEqual(LandscapeCompositionRecipe.personScale.recommendedLight, .goldenHour)
        XCTAssertEqual(LandscapeCompositionRecipe.lakeReflection.package, .lakes)
        XCTAssertEqual(LandscapeCompositionRecipe.plainRepeatingRows.package, .plains)
        XCTAssertEqual(LandscapeCompositionRecipe.plantPattern.recommendedCameraAngle, .overhead)
    }

    func testFoodCatalogHasSixCompleteRecipes() {
        let recipes = FoodCompositionRecipe.allCases
        XCTAssertEqual(recipes.count, 6)
        XCTAssertEqual(Set(recipes.map(\.id)).count, 6)
        XCTAssertEqual(Set(recipes.map(\.recommendedCameraAngle)), Set([.overhead, .fortyFive, .side]))
        XCTAssertEqual(Set(recipes.map(\.recommendedLight)), Set(FoodLightRecommendation.allCases))
        for recipe in recipes {
            XCTAssertEqual(recipe.cues.count, 2)
            XCTAssertFalse(recipe.instruction.isEmpty)
            XCTAssertFalse(recipe.exampleAssetName.isEmpty)
            XCTAssertFalse(recipe.safetyNote.isEmpty)
            XCTAssertFalse(recipe.recommendedLight.instruction.isEmpty)
        }
        XCTAssertEqual(FoodCompositionRecipe.heroPlate.recommendedCameraAngle, .fortyFive)
        XCTAssertEqual(FoodCompositionRecipe.overheadFlatLay.recommendedCameraAngle, .overhead)
        XCTAssertTrue(FoodCompositionRecipe.pourAction.safetyNote.contains("hot liquid"))
    }

    func testGuidanceProgressesOnlyWhenExplicitlyAdvanced() {
        var session = GuidedSession(pose: .handInPocket, position: .elevated)
        XCTAssertEqual(session.steps.count, 4)
        XCTAssertEqual(session.currentStep?.action, .cameraHeight)
        session.advance()
        XCTAssertEqual(session.currentStep?.action, .cameraPitch)
        session.advance()
        XCTAssertEqual(session.currentStep?.recipient, "Subject")
        session.advance()
        XCTAssertFalse(session.isComplete)
        session.advance()
        XCTAssertTrue(session.isComplete)
        session.advance()
        XCTAssertEqual(session.stepIndex, 4)
        XCTAssertEqual(session.advice?.tone, .waiting)
    }

    func testNaturalGuidanceDoesNotAddInstructions() {
        let session = GuidedSession(pose: nil, position: nil)
        XCTAssertFalse(session.isActive)
        XCTAssertNil(session.advice)
        let issues = CoachingEngine().issues(for: measurements(personBox: nil))
        XCTAssertEqual(session.prioritizedIssues(issues), issues)
    }

    func testMissingSubjectInterruptsGuidanceWithoutAdvancingIt() {
        let engine = CoachingEngine()
        let session = GuidedSession(pose: .walking, position: nil)
        let issues = session.prioritizedIssues(engine.issues(for: measurements(personBox: nil)))
        let now = Date()
        _ = engine.selectAdvice(from: issues, now: now, fallback: session.advice)
        let advice = engine.selectAdvice(from: issues, now: now.addingTimeInterval(2), fallback: session.advice)
        XCTAssertEqual(advice.type, "subject_missing")
        XCTAssertEqual(session.stepIndex, 0)
        _ = engine.selectAdvice(from: [], now: now.addingTimeInterval(4), fallback: session.advice)
        XCTAssertEqual(engine.selectAdvice(from: [], now: now.addingTimeInterval(6), fallback: session.advice), session.advice)
        XCTAssertEqual(session.stepIndex, 0)
    }

    func testPoseConflictsAndPhotographerSideAreExplicit() {
        XCTAssertTrue(GuidedPose.overShoulder.conflicts.contains("face_missing"))
        XCTAssertTrue(GuidedPose.overShoulder.conflicts.contains("face_too_profile"))
        XCTAssertTrue(GuidedPose.walking.conflicts.contains("camera_unstable"))
        XCTAssertTrue(GuidedPose.seatedAngle.conflicts.contains("feet_cropped"))
        XCTAssertTrue(GuidedCameraPosition.side.steps(moveRight: false).last!.instruction.contains("your left"))
        XCTAssertTrue(GuidedCameraPosition.side.steps(moveRight: true).last!.instruction.contains("your right"))
        XCTAssertEqual(GuidedPose.threeQuarter.steps.first?.instruction, "Turn your body slightly to your right.")
    }

    func testOverShoulderSuppressesFaceDirectionButKeepsMissingSubject() {
        let engine = CoachingEngine()
        let session = GuidedSession(pose: .overShoulder, position: nil)
        let box = DetectionBox(rect: CGRect(x: 0.3, y: 0.12, width: 0.3, height: 0.65), confidence: 0.9, label: "person")
        let issues = engine.issues(for: measurements(personBox: box, faceBox: nil))
        XCTAssertTrue(issues.contains { $0.type == "face_missing" })
        XCTAssertFalse(session.prioritizedIssues(issues).contains { $0.type == "face_missing" })
        XCTAssertEqual(session.prioritizedIssues(engine.issues(for: measurements(personBox: nil))).first?.type, "subject_missing")
    }

    func testChangingGuidanceDoesNotRetainAnOldInstruction() {
        let engine = CoachingEngine()
        var first = GuidedSession(pose: .walking, position: .elevated)
        first.advance()
        let now = Date()
        _ = engine.selectAdvice(from: [], now: now, fallback: first.advice)
        _ = engine.selectAdvice(from: [], now: now.addingTimeInterval(2), fallback: first.advice)
        engine.reset()
        let replacement = GuidedSession(pose: .handAtWaist, position: nil)
        let initial = engine.selectAdvice(from: [], now: now.addingTimeInterval(3), fallback: replacement.advice)
        XCTAssertNotEqual(initial.type, first.advice?.type)
        XCTAssertEqual(engine.selectAdvice(from: [], now: now.addingTimeInterval(5), fallback: replacement.advice), replacement.advice)
        XCTAssertEqual(replacement.stepIndex, 0)
        XCTAssertEqual(replacement.currentStep?.completion, .userConfirmed)
    }

    func testPendingCaptureSurvivesStoreRecreationUntilExplicitRemoval() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data([0, 17, 42, 255])
        try PendingCaptureStore(url: url).retain(original)

        let reopenedStore = PendingCaptureStore(url: url)
        XCTAssertEqual(try reopenedStore.load(), original)
        try reopenedStore.remove()
        XCTAssertNil(try reopenedStore.load())
        XCTAssertNoThrow(try reopenedStore.remove())
    }

    func testPendingCaptureWriteFailureIsReported() {
        let missingDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PendingCaptureStore(url: missingDirectory.appendingPathComponent("capture.photo"))
        XCTAssertThrowsError(try store.retain(Data([1, 2, 3])))
        XCTAssertNil(try store.load())
    }

    func testCaptureHistoryLoadsNewestFirstAndPrunesOldPhotos() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CaptureHistoryStore(directoryURL: directory, maximumCount: 2)

        let first = try store.retain(Data([1]), capturedAt: Date(timeIntervalSince1970: 1), id: UUID())
        let second = try store.retain(Data([2]), capturedAt: Date(timeIntervalSince1970: 2), id: UUID())
        let third = try store.retain(Data([3]), capturedAt: Date(timeIntervalSince1970: 3), id: UUID())

        XCTAssertEqual(try store.loadAll().map(\.data), [third.data, second.data])
        XCTAssertFalse(try store.loadAll().contains(where: { $0.id == first.id }))

        try store.remove(id: third.id)
        XCTAssertEqual(try store.loadAll().map(\.data), [second.data])
    }

    func testSubjectMissingProducesHighestPriorityDangerIssue() {
        let issues = CoachingEngine().issues(for: measurements(personBox: nil))

        XCTAssertEqual(issues.first?.type, "subject_missing")
        XCTAssertEqual(issues.first?.recipient, "Photographer")
        XCTAssertEqual(issues.first?.instruction, "Frame the person")
        XCTAssertEqual(issues.first?.tone, .danger)
    }

    func testSubjectTooCloseIncludesReasonData() {
        let box = DetectionBox(
            rect: CGRect(x: 0.08, y: 0.08, width: 0.78, height: 0.82),
            confidence: 0.9,
            label: "person"
        )

        let issues = CoachingEngine().issues(for: measurements(personBox: box, faceBox: nil))
        let tooClose = issues.first { $0.type == "subject_too_close" }

        XCTAssertEqual(tooClose?.instruction, "Step back")
        XCTAssertGreaterThan(tooClose?.reasonData["person_area"] ?? 0, 0.48)
    }

    func testHorizonTiltUsesHorizonConfidence() {
        let box = DetectionBox(
            rect: CGRect(x: 0.3, y: 0.12, width: 0.32, height: 0.62),
            confidence: 0.86,
            label: "person"
        )

        let issues = CoachingEngine().issues(
            for: measurements(
                personBox: box,
                faceBox: DetectionBox(rect: CGRect(x: 0.4, y: 0.18, width: 0.12, height: 0.14), confidence: 0.8, label: "face"),
                horizonAngleDegrees: 5,
                horizonConfidence: 0.76
            )
        )

        let horizonIssue = issues.first { $0.type == "horizon_tilted" }
        XCTAssertEqual(horizonIssue?.instruction, "Tilt left")
        XCTAssertEqual(horizonIssue?.reasonData["horizon_angle_degrees"], 5)
    }

    func testBacklitFaceProducesSubjectLightingAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                faceLuminance: 45,
                backgroundLuminance: 150
            )
        )

        let backlit = issues.first { $0.type == "subject_backlit" }
        XCTAssertEqual(backlit?.recipient, "Subject")
        XCTAssertEqual(backlit?.instruction, "Face the light")
    }

    func testCameraUnstableDelaysReadyAdvice() {
        let engine = CoachingEngine()
        let now = Date()
        let unstableIssues = engine.issues(for: measurements(cameraMotion: 0.7, cameraStable: false))

        let firstAdvice = engine.selectAdvice(from: unstableIssues, now: now)
        let settlingAdvice = engine.selectAdvice(from: [], now: now.addingTimeInterval(0.7))
        let stableAdvice = engine.selectAdvice(from: [], now: now.addingTimeInterval(1.4))

        XCTAssertEqual(firstAdvice.instruction, "Hold steady")
        XCTAssertEqual(settlingAdvice.type, "waiting")
        XCTAssertEqual(stableAdvice.type, "ready")
    }

    func testHandNearFaceProducesSubjectPoseAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                poseAnalysis: PoseAnalysis(
                    confidence: 0.7,
                    visibleKeypointCount: 8,
                    shoulderLineAngleDegrees: 2,
                    shoulderHeightAsymmetry: 0.01,
                    torsoAngleDegrees: 0,
                    wristToFaceDistance: 0.01,
                    armVisibilityScore: 0.9,
                    stanceWidth: 0.2,
                    headToTorsoRatio: 0.28,
                    shouldersHighScore: 0.1,
                    bodySquarenessScore: 0.5,
                    bodyProfileScore: 0.5,
                    armsFlatAgainstBodyScore: 0.1,
                    minWristEdgeDistance: 0.3
                )
            )
        )

        let handIssue = issues.first { $0.type == "hand_near_face" }
        XCTAssertEqual(handIssue?.recipient, "Subject")
        XCTAssertEqual(handIssue?.instruction, "Move hand from face")
    }

    func testHiddenArmProducesSubjectPoseAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                poseAnalysis: PoseAnalysis(
                    confidence: 0.58,
                    visibleKeypointCount: 5,
                    shoulderLineAngleDegrees: nil,
                    shoulderHeightAsymmetry: nil,
                    torsoAngleDegrees: nil,
                    wristToFaceDistance: nil,
                    armVisibilityScore: 0.33,
                    stanceWidth: nil,
                    headToTorsoRatio: nil,
                    shouldersHighScore: nil,
                    bodySquarenessScore: nil,
                    bodyProfileScore: nil,
                    armsFlatAgainstBodyScore: nil,
                    minWristEdgeDistance: nil
                )
            )
        )

        let armIssue = issues.first { $0.type == "arm_hidden" }
        XCTAssertEqual(armIssue?.instruction, "Show both arms")
    }

    func testShouldersHighProducesRelaxShouldersAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                poseAnalysis: PoseAnalysis(
                    confidence: 0.64,
                    visibleKeypointCount: 8,
                    shoulderLineAngleDegrees: 0,
                    shoulderHeightAsymmetry: 0.01,
                    torsoAngleDegrees: 0,
                    wristToFaceDistance: nil,
                    armVisibilityScore: 0.9,
                    stanceWidth: nil,
                    headToTorsoRatio: 0.22,
                    shouldersHighScore: 0.8,
                    bodySquarenessScore: 0.5,
                    bodyProfileScore: 0.5,
                    armsFlatAgainstBodyScore: 0.1,
                    minWristEdgeDistance: 0.3
                )
            )
        )

        XCTAssertEqual(issues.first { $0.type == "shoulders_high" }?.instruction, "Relax shoulders")
    }

    func testFaceYawProducesFaceDirectionAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                faceAnalysis: FaceAnalysis(
                    confidence: 0.82,
                    landmarkPointCount: 28,
                    eyeVisibilityScore: 1,
                    yawEstimate: 0.55,
                    pitchEstimate: 0.3,
                    occlusionScore: 0.05
                )
            )
        )

        XCTAssertEqual(issues.first { $0.type == "face_too_profile" }?.instruction, "Turn face slightly left")
    }

    func testOccludedEyesProduceShowEyesAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                faceAnalysis: FaceAnalysis(
                    confidence: 0.76,
                    landmarkPointCount: 12,
                    eyeVisibilityScore: 0.5,
                    yawEstimate: 0.1,
                    pitchEstimate: 0.3,
                    occlusionScore: 0.54
                )
            )
        )

        XCTAssertEqual(issues.first { $0.type == "eyes_occluded" }?.instruction, "Show your eyes")
    }

    func testPosePackageChangesPoseAdviceVocabulary() {
        let pose = PoseAnalysis(
            confidence: 0.7,
            visibleKeypointCount: 8,
            shoulderLineAngleDegrees: 1,
            shoulderHeightAsymmetry: 0.01,
            torsoAngleDegrees: 0,
            wristToFaceDistance: nil,
            armVisibilityScore: 0.95,
            stanceWidth: 0.18,
            headToTorsoRatio: 0.3,
            shouldersHighScore: 0.1,
            bodySquarenessScore: 0.95,
            bodyProfileScore: 0.05,
            armsFlatAgainstBodyScore: 0.82,
            minWristEdgeDistance: 0.2
        )

        let feminineIssues = CoachingEngine().issues(
            for: measurements(poseAnalysis: pose),
            posePackage: .feminine
        )
        let masculineIssues = CoachingEngine().issues(
            for: measurements(poseAnalysis: pose),
            posePackage: .masculine
        )

        XCTAssertEqual(
            feminineIssues.first { $0.type == "arms_flat_against_body" }?.instruction,
            "Create space at the waist"
        )
        XCTAssertEqual(
            masculineIssues.first { $0.type == "body_too_square" }?.instruction,
            "Turn chin slightly, keep shoulders strong"
        )
    }

    func testGroupPortraitPackageProducesGroupAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                groupAnalysis: GroupAnalysis(
                    peopleCount: 4,
                    faceCount: 2,
                    groupBounds: CGRect(x: 0.02, y: 0.12, width: 0.92, height: 0.7),
                    faceVisibilityRatio: 0.5,
                    edgeCrowdingScore: 0.67,
                    spacingScore: 2.1
                )
            ),
            posePackage: .groupPortrait
        )

        XCTAssertEqual(issues.first { $0.type == "group_faces_missing" }?.instruction, "Make every face visible")
        XCTAssertEqual(issues.first { $0.type == "group_edge_crowded" }?.instruction, "Leave space at the edges")
    }

    private func cameraCapabilities(
        exposureBias: Double = 0,
        duration: Double = 1.0 / 125.0,
        iso: Double = 100
    ) -> CameraControlCapabilities {
        CameraControlCapabilities(
            isAvailable: true,
            cameraName: "Test Camera",
            lensName: "Wide",
            supportsExposureBias: true,
            minimumExposureBias: -2,
            maximumExposureBias: 2,
            currentExposureBias: exposureBias,
            supportsFocusLock: true,
            supportsExposureLock: true,
            isFocusExposureLocked: false,
            currentISO: iso,
            currentExposureDurationSeconds: duration
        )
    }

    private func advice(_ instruction: String) -> Advice {
        Advice(type: "test", recipient: "Photographer", instruction: instruction, tone: .warning)
    }

    private func meanRGBDifference(_ lhs: UIImage, _ rhs: UIImage) -> Double {
        guard let left = rgbaBytes(lhs), let right = rgbaBytes(rhs), left.count == right.count else {
            return 0
        }
        var total = 0.0
        var componentCount = 0
        for pixel in stride(from: 0, to: left.count, by: 4) {
            for component in 0..<3 {
                total += Double(abs(Int(left[pixel + component]) - Int(right[pixel + component])))
                componentCount += 1
            }
        }
        return componentCount == 0 ? 0 : total / Double(componentCount)
    }

    private func rgbaBytes(_ image: UIImage) -> [UInt8]? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = bytes.withUnsafeMutableBytes { storage -> Bool in
            guard let baseAddress = storage.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return rendered ? bytes : nil
    }

    private func measurements(
        personBox: DetectionBox? = DetectionBox(
            rect: CGRect(x: 0.32, y: 0.08, width: 0.3, height: 0.62),
            confidence: 0.88,
            label: "person"
        ),
        faceBox: DetectionBox? = DetectionBox(
            rect: CGRect(x: 0.41, y: 0.13, width: 0.1, height: 0.13),
            confidence: 0.82,
            label: "face"
        ),
        horizonAngleDegrees: Double? = nil,
        horizonConfidence: Double = 0,
        faceLuminance: Double? = 120,
        backgroundLuminance: Double? = 130,
        cameraMotion: Double = 0.02,
        cameraStable: Bool = true,
        groupAnalysis: GroupAnalysis? = nil,
        faceAnalysis: FaceAnalysis? = nil,
        poseAnalysis: PoseAnalysis? = nil,
        salientObjectBox: DetectionBox? = nil,
        subjectMotion: Double = 0,
        skyOrOpenAreaRatio: Double = 0.42
    ) -> Measurements {
        Measurements(
            personBox: personBox,
            faceBox: faceBox,
            groupAnalysis: groupAnalysis,
            faceAnalysis: faceAnalysis,
            poseKeypoints: [:],
            poseAnalysis: poseAnalysis,
            faceLuminance: faceLuminance,
            backgroundLuminance: backgroundLuminance,
            horizonAngleDegrees: horizonAngleDegrees,
            horizonY: horizonAngleDegrees == nil ? nil : 0.5,
            horizonConfidence: horizonConfidence,
            cameraRollDegrees: 0,
            cameraMotion: cameraMotion,
            cameraStable: cameraStable,
            skyOrOpenAreaRatio: skyOrOpenAreaRatio,
            timestamp: Date(),
            salientObjectBox: salientObjectBox,
            subjectMotion: subjectMotion
        )
    }
}
