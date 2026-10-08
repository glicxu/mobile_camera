@preconcurrency import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

private enum ManualPreviewTool: String, CaseIterable, Identifiable {
    case focus
    case depth
    case exposure

    var id: String { rawValue }
    var title: String {
        switch self {
        case .focus: return "Focus"
        case .depth: return "Depth"
        case .exposure: return "Exposure"
        }
    }
    var symbol: String {
        switch self {
        case .focus: return "scope"
        case .depth: return "camera.aperture"
        case .exposure: return "timer"
        }
    }
}

private enum CameraTutorialStep: Int, CaseIterable, Identifiable {
    case choose
    case posture
    case landscape
    case coach
    case style
    case capture
    case review

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .choose: return "Choose your shot"
        case .posture: return "Choose a posture package"
        case .landscape: return "Choose a landscape package"
        case .coach: return "Follow the coaching light"
        case .style: return "Style before capture"
        case .capture: return "Take the photo"
        case .review: return "Review and return"
        }
    }

    var detail: String {
        switch self {
        case .choose:
            return "Leave Situation on Auto for everyday photos, or choose Portrait, Landscape, Food, Group, Action, or Close-up when you want specific guidance."
        case .posture:
            return "For Portrait, People, or Group photos, tap Posture. Choose a package, then select a reference pose. Dali shows its recommended camera angle, lighting, and live coaching cues."
        case .landscape:
            return "Choose the Landscape situation, then tap Landscape. Pick a scene package and a composition. Dali guides the angle, light, horizon, and placement while you frame the photo."
        case .coach:
            return "Dali gives one visual instruction at a time. Green means the framing looks good; amber means a small adjustment needs your attention."
        case .style:
            return "Open Controls to choose a named Filter or Beautifier. Auto chooses for the scene, Custom exposes fine-tuning, and Off keeps the natural camera image."
        case .capture:
            return "Tap the shutter for one photo. Shutter Controls also provides a timer and your voice phrase. Hold the shutter for a burst by default."
        case .review:
            return "Tap the lower-left thumbnail to review. Swipe through photos, compare Before and After, then tap Back to Camera when you are ready to shoot again."
        }
    }

    var symbol: String {
        switch self {
        case .choose: return "viewfinder"
        case .posture: return "figure.stand"
        case .landscape: return "mountain.2"
        case .coach: return "arrow.up.and.down.and.arrow.left.and.right"
        case .style: return "camera.filters"
        case .capture: return "camera.fill"
        case .review: return "photo.on.rectangle.angled"
        }
    }

    var accent: Color {
        switch self {
        case .choose, .posture, .style, .review: return .teal
        case .landscape: return .blue
        case .coach: return .orange
        case .capture: return .yellow
        }
    }

    var tips: [String] {
        switch self {
        case .choose:
            return ["Auto recognizes the scene", "Choose a situation for specialized guidance"]
        case .posture:
            return ["11 posture packages", "Tap a photo to select the pose"]
        case .landscape:
            return ["4 landscape packages", "Choose among 24 compositions"]
        case .coach:
            return ["Green: ready", "Amber: adjust framing"]
        case .style:
            return ["Filters control color", "Beautifier controls people or scenery"]
        case .capture:
            return ["Tap: one photo", "Hold: burst"]
        case .review:
            return ["Swipe for previous photos", "Back to Camera resumes shooting"]
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @StateObject private var camera = CameraModel()
    @StateObject private var voiceShutter = VoiceShutterController()
    @AppStorage("hasSeenDaliTutor") private var hasSeenDaliTutor = false
    @AppStorage("voiceShutterEnabled") private var storedVoiceShutterEnabled = false
    @AppStorage("voiceShutterCustomPhrase") private var storedVoiceShutterCustomPhrase = ""
    @AppStorage("shutterTimerSeconds") private var storedShutterTimerSeconds = 0
    @AppStorage("shutterLongPressAction") private var storedShutterLongPressAction = ShutterLongPressAction.burst.rawValue
    @AppStorage("beautifyStrength") private var storedBeautifyStrength = 0
    @AppStorage("landscapePolishStrength") private var storedLandscapePolishStrength = 0
    @AppStorage("reviewTreatment") private var storedReviewTreatment = ReviewTreatment.generalEnhance.rawValue
    @AppStorage("beautifyLevelVersion") private var storedBeautifyLevelVersion = 0
    @AppStorage("beautifyLandscapeSkyEnabled") private var storedBeautifyLandscapeSkyEnabled = true
    @AppStorage("beautifyLandscapeColorEnabled") private var storedBeautifyLandscapeColorEnabled = true
    @AppStorage("beautifyFaceBrightnessEnabled") private var storedBeautifyFaceBrightnessEnabled = true
    @AppStorage("beautifySkinSmoothingEnabled") private var storedBeautifySkinSmoothingEnabled = true
    @AppStorage("beautifyBlemishReductionEnabled") private var storedBeautifyBlemishReductionEnabled = true
    @AppStorage("beautifyEyeEnlargementEnabled") private var storedBeautifyEyeEnlargementEnabled = true
    @AppStorage("beautifyLipPlumpingEnabled") private var storedBeautifyLipPlumpingEnabled = true
    @AppStorage("enhanceStrength") private var storedEnhanceStrength = 0
    @AppStorage("enhanceAutoToneEnabled") private var storedEnhanceAutoToneEnabled = true
    @AppStorage("beautifyWarmthEnabled") private var storedEnhanceWarmthEnabled = true
    @AppStorage("enhanceVibranceEnabled") private var storedEnhanceVibranceEnabled = true
    @AppStorage("beautifyClarityEnabled") private var storedEnhanceClarityEnabled = true
    @AppStorage("enhanceNoiseReductionEnabled") private var storedEnhanceNoiseReductionEnabled = true
    @AppStorage("beautifySubjectEmphasisEnabled") private var storedEnhanceSubjectEmphasisEnabled = true
    @AppStorage("photoFilterChoice") private var storedPhotoFilterChoice = PhotoFilterChoice.auto.rawValue
    @AppStorage("filterApplicationMode") private var storedFilterApplicationMode = EffectApplicationMode.auto.rawValue
    @AppStorage("photoFilterExposure") private var storedPhotoFilterExposure = 0
    @AppStorage("photoFilterWarmth") private var storedPhotoFilterWarmth = 0
    @AppStorage("photoFilterColor") private var storedPhotoFilterColor = 0
    @AppStorage("photoFilterContrast") private var storedPhotoFilterContrast = 0
    @AppStorage("photoFilterSoftness") private var storedPhotoFilterSoftness = 0
    @AppStorage("photoFilterDetail") private var storedPhotoFilterDetail = 0
    @AppStorage("photoFilterBlueSky") private var storedPhotoFilterBlueSky = 0
    @AppStorage("capturePolishChoice") private var storedCapturePolishChoice = CapturePolishChoice.off.rawValue
    @AppStorage("beautifierApplicationMode") private var storedBeautifierApplicationMode = EffectApplicationMode.off.rawValue
    @AppStorage("capturePolishStrength") private var storedCapturePolishStrength = 3
    @AppStorage("portraitBeautifierPreset") private var storedPortraitBeautifierPreset = PortraitBeautifierPreset.polished.rawValue
    @AppStorage("portraitBeautifierStrength") private var storedPortraitBeautifierStrength = 3
    @AppStorage("portraitBeautifierBrightness") private var storedPortraitBeautifierBrightness = true
    @AppStorage("portraitBeautifierSmoothing") private var storedPortraitBeautifierSmoothing = true
    @AppStorage("portraitBeautifierBlemishes") private var storedPortraitBeautifierBlemishes = true
    @AppStorage("portraitBeautifierEyes") private var storedPortraitBeautifierEyes = true
    @AppStorage("portraitBeautifierLips") private var storedPortraitBeautifierLips = false
    @AppStorage("landscapeBeautifierPreset") private var storedLandscapeBeautifierPreset = LandscapeBeautifierPreset.vivid.rawValue
    @AppStorage("landscapeBeautifierStrength") private var storedLandscapeBeautifierStrength = 3
    @AppStorage("landscapeBeautifierSky") private var storedLandscapeBeautifierSky = true
    @AppStorage("landscapeBeautifierColor") private var storedLandscapeBeautifierColor = true
    @State private var showTutor = false
    @State private var tutorialPage = 0
    @State private var showAppSettings = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingFolderImporter = false
    @State private var showCameraControls = false
    @State private var shutterControlsExpanded = false
    @State private var filterControlsExpanded = false
    @State private var customFilterSettingsExpanded = false
    @State private var capturePolishExpanded = false
    @State private var customBeautifierSettingsExpanded = false
    @State private var advancedControlsExpanded = false
    @State private var autoAssistanceEnabled = false
    @State private var proExposureEnabled = false
    @State private var focusExposureMode: FocusExposureMode = .auto
    @State private var dismissedAssistedRecommendation: AssistedRecommendationKind?
    @State private var proExposureProgram: ProExposureProgram = .manual
    @State private var manualShutterSeconds = 1.0 / 125.0
    @State private var manualShutterAuto = true
    @State private var manualISO = 100.0
    @State private var manualAperture = 1.8
    @State private var linkedISOEnabled = false
    @State private var linkedExposureBaseProduct = 100.0 / 125.0
    @State private var proExposureAdjustment = 0.0
    @State private var meteringIndicatorPoint: CGPoint?
    @State private var digitalDepthOfFocus = 0
    @State private var selectedManualPreviewTool: ManualPreviewTool?
    @State private var manualControlsVisible = false
    @State private var meteringIndicatorTarget: TapMeteringTarget = .focusAndExposure
    @State private var meteringIndicatorTask: Task<Void, Never>?
    @State private var shutterCountdownTask: Task<Void, Never>?
    @State private var shutterCountdownRemaining: Int?
    @State private var burstCaptureTask: Task<Void, Never>?
    @State private var burstPhotoCount = 0
    @State private var suppressNextShutterTap = false
    @State private var reviewPhotos: [ReviewPhoto] = []
    @State private var reviewPhotoIndex = 0
    @State private var reviewPhotoLoadID = UUID()
    @State private var isLoadingPhotoLibrary = false
    @State private var reviewVariant: ReviewVariant = .original
    @State private var reviewComparisonMode: ReviewComparisonMode = .before
    @State private var showFullScreenReviewImage = false
    @State private var startReviewComparison = false
    @State private var shootingMode: PhotographicSituation = .auto
    @State private var automaticSituation: PhotographicSituation = .personScene
    @State private var situationClassifier = SituationClassifier()
    @State private var selectedAngle: CameraAngleChoice = .eyeLevel
    @State private var coachingEnabled = true
    @State private var sharedPhoto: SharedPhoto?
    @State private var showDiscardConfirmation = false
    @State private var showPoseChooser = false
    @State private var showLandscapeChooser = false
    @State private var showFoodChooser = false
    @State private var guideCollection: GuidedPoseCollectionID = .masculine
    @State private var selectedPosePackage: GuidedPoseCollectionID?
    @State private var chosenGuidePose: GuidedPose?
    @State private var examplePose: GuidedPose?
    @State private var chosenLandscapeRecipe: LandscapeCompositionRecipe?
    @State private var landscapeExampleRecipe: LandscapeCompositionRecipe?
    @State private var selectedLandscapePackage: LandscapeCompositionPackageID?
    @State private var chosenFoodRecipe: FoodCompositionRecipe?
    @State private var foodExampleRecipe: FoodCompositionRecipe?
    @State private var chosenCameraPosition: GuidedCameraPosition?
    @State private var guideMoveRight = false

    var body: some View {
        ZStack {
            if let reviewImage = camera.reviewImage {
                reviewSlideshowView(original: reviewImage)
            } else {
                liveCameraView
            }

            if camera.permissionDenied, camera.reviewImage == nil {
                permissionView
            }

            if camera.debugEnabled, camera.reviewImage == nil {
                floatingDebugPanel
            }

        }
        .background(Color.black)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            voiceShutter.onTakePhoto = { requestPhotoCapture() }
            voiceShutter.setCustomPhrase(storedVoiceShutterCustomPhrase)
            syncVoiceShutterState()
            if storedVoiceShutterEnabled { voiceShutter.setEnabled(true) }
            loadStoredEnhanceSettings()
            loadStoredBeautifySettings()
            syncPhotoFilter()
            syncCapturePolish()
            if !hasSeenDaliTutor {
                showTutor = true
                hasSeenDaliTutor = true
            } else if !loadReviewFixtureForUITests() {
                camera.start()
            }
        }
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await loadReviewPhotos(from: items)
                selectedPhotoItems = []
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !showTutor {
                camera.start()
            } else if phase == .background {
                camera.stop()
            }
        }
        .onChange(of: shutterCountdownBlocked) { _, blocked in
            if blocked {
                cancelShutterCountdown()
                stopBurstCapture()
            }
        }
        .onChange(of: voiceShutterCanListen) { _, _ in
            syncVoiceShutterState()
        }
        .onChange(of: voiceShutter.isEnabled) { _, enabled in
            storedVoiceShutterEnabled = enabled
        }
        .onChange(of: storedVoiceShutterCustomPhrase) { _, phrase in
            voiceShutter.setCustomPhrase(phrase)
        }
        .sheet(item: $sharedPhoto) { photo in
            PhotoShareSheet(image: photo.image)
        }
        .sheet(isPresented: $showPoseChooser) {
            postureMontage
        }
        .sheet(isPresented: $showLandscapeChooser) {
            landscapeCompositionChooser
        }
        .sheet(isPresented: $showFoodChooser) {
            foodCompositionChooser
        }
        .sheet(item: $examplePose) { pose in
            postureExampleSheet(for: pose)
        }
        .sheet(item: $landscapeExampleRecipe) { recipe in
            landscapeCompositionExampleSheet(for: recipe)
        }
        .sheet(item: $foodExampleRecipe) { recipe in
            foodCompositionExampleSheet(for: recipe)
        }
        .sheet(isPresented: $showTutor) {
            tutorCard
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showTutor) { _, showing in
            if showing {
                tutorialPage = 0
                camera.stop()
            } else {
                camera.start()
            }
        }
        .onChange(of: shootingMode) { _, _ in
            showPoseChooser = false
            showLandscapeChooser = false
            showFoodChooser = false
            if !activeSituation.supportsPoseGuidance { camera.beginGuidance(pose: nil, position: nil) }
        }
        .onChange(of: activeSituation) { _, situation in
            syncPhotoFilter()
            syncCapturePolish()
            guard let firstAngle = situation.angleChoices.first else { return }
            selectedAngle = firstAngle
            chosenGuidePose = nil
            chosenCameraPosition = nil
            showPoseChooser = false
            showLandscapeChooser = false
            showFoodChooser = false
            if situation != .landscape { chosenLandscapeRecipe = nil }
            if situation != .food { chosenFoodRecipe = nil }
            camera.beginGuidance(pose: nil, position: nil)
        }
        .onChange(of: camera.measurements.timestamp) { _, _ in
            guard coachingEnabled, shootingMode == .auto,
                  !camera.isCapturing, !camera.guidedSession.isActive else { return }
            automaticSituation = situationClassifier.update(with: camera.measurements)
        }
        .onChange(of: assistedRecommendationCandidate) { _, candidate in
            if let dismissedAssistedRecommendation,
               candidate?.kind != dismissedAssistedRecommendation {
                self.dismissedAssistedRecommendation = nil
            }
        }
        .confirmationDialog("Discard the unsaved original?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
            Button("Discard photo", role: .destructive) {
                camera.discardUnsavedCapture()
                if camera.reviewImage == nil { camera.start() }
            }
            Button("Keep photo", role: .cancel) {}
        } message: {
            Text("Only discard it if you no longer need it or have already shared a copy.")
        }
        .onChange(of: camera.advice) { _, advice in
            guard UIAccessibility.isVoiceOverRunning, camera.reviewImage == nil,
                  activeSituation.showsPersonOverlay, coachingEnabled,
                  !showTutor, !showPoseChooser, !showLandscapeChooser, !showFoodChooser,
                  !showAppSettings else { return }
            UIAccessibility.post(notification: .announcement, argument: "\(advice.recipient). \(advice.instruction)")
        }
        .onChange(of: camera.exportStatus) { _, status in
            if UIAccessibility.isVoiceOverRunning, let status {
                UIAccessibility.post(notification: .announcement, argument: status)
            }
        }
        .onChange(of: camera.selectedPosePackage) { _, _ in
            camera.refreshStillPhotoAdvice()
        }
        .onChange(of: camera.beautifySettings) { oldSettings, newSettings in
            persistBeautifySettings()
            if oldSettings.strength == newSettings.strength {
                camera.refreshBeautify()
            }
        }
        .onChange(of: camera.enhanceSettings) { oldSettings, newSettings in
            persistEnhanceSettings()
            if oldSettings.strength == newSettings.strength {
                camera.refreshEnhance()
            }
        }
        .onChange(of: camera.landscapePolishStrength) { _, strength in
            storedLandscapePolishStrength = strength
        }
        .onChange(of: camera.reviewTreatment) { _, treatment in
            storedReviewTreatment = treatment.rawValue
        }
        .onChange(of: storedPhotoFilterChoice) { _, choice in
            if choice == PhotoFilterChoice.custom.rawValue {
                customFilterSettingsExpanded = true
            }
            syncPhotoFilter()
        }
        .onChange(of: storedFilterApplicationMode) { _, _ in
            syncPhotoFilter()
        }
        .onChange(of: storedCapturePolishChoice) { _, choice in
            if choice != CapturePolishChoice.off.rawValue, storedCapturePolishStrength < 1 {
                storedCapturePolishStrength = 3
            }
            syncCapturePolish()
        }
        .onChange(of: storedBeautifierApplicationMode) { _, _ in
            syncCapturePolish()
        }
        .onChange(of: storedCapturePolishStrength) { _, _ in
            syncCapturePolish()
        }
        .onChange(of: availableReviewVariants) { _, variants in
            let processedVariant = activeProcessedReviewVariant
            if processedVariant != .original, variants.contains(processedVariant) {
                reviewVariant = processedVariant
            } else if !variants.contains(reviewVariant) {
                reviewVariant = .original
            }
        }
        .fileImporter(
            isPresented: $showingFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await loadReviewPhotos(fromFolder: url)
                }
            case .failure:
                camera.captureStatus = "Could not open folder"
            }
        }
        .onDisappear {
            cancelShutterCountdown()
            stopBurstCapture()
            meteringIndicatorTask?.cancel()
            camera.stop()
            voiceShutter.pauseListening(reason: "Paused while Dali is not visible")
        }
        .sheet(isPresented: $showCameraControls) {
            cameraControlSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAppSettings) {
            appSettingsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showFullScreenReviewImage, onDismiss: { startReviewComparison = false }) {
            if let reviewImage = camera.reviewImage {
                ZoomableReviewImageView(
                    image: reviewComparisonMode == .before
                        ? reviewImage
                        : currentReviewDisplayImage(original: reviewImage),
                    originalImage: reviewImage,
                    title: reviewVariantTitle,
                    subtitle: reviewImageSubtitle,
                    startComparing: startReviewComparison,
                    isPresented: $showFullScreenReviewImage
                )
            }
        }
    }

    private var liveCameraView: some View {
        GeometryReader { proxy in
            if proxy.size.width > proxy.size.height {
                HStack(spacing: 12) {
                    viewfinder
                    VStack(spacing: 8) {
                        topBar
                        lowerCameraControls
                    }
                    .frame(width: min(360, proxy.size.width * 0.44))
                }
                .padding(12)
            } else {
                VStack(spacing: 8) {
                    topBar
                    viewfinder
                    lowerCameraControls
                        .frame(height: coachingEnabled ? min(max(proxy.size.height * 0.42, 310), 430) : 84)
                }
                .padding(12)
            }
        }
    }

    private func loadReviewFixtureForUITests() -> Bool {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["DALI_UI_REVIEW"] == "1" else { return false }
        // A deterministic review fixture keeps UI tests independent of camera hardware.
        let colors: [(UIColor, UIColor)] = [
            (.systemTeal, .systemOrange),
            (.systemIndigo, .systemYellow),
            (.systemGreen, .systemPink)
        ]
        reviewPhotos = colors.enumerated().compactMap { index, colors in
            let image = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800)).image { context in
                colors.0.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
                colors.1.setFill()
                context.fill(CGRect(x: 180, y: 180, width: 240, height: 440))
            }
            guard let data = image.pngData() else { return nil }
            return ReviewPhoto(data: data, title: "Captured fixture \(index + 1)")
        }
        guard let first = reviewPhotos.first, let data = first.data else { return false }
        reviewPhotoIndex = 0
        camera.analyzeStillPhoto(data: data)
        return true
        #else
        return false
        #endif
    }

    private var viewfinder: some View {
        ZStack {
            CameraPreview(
                session: camera.session,
                mirrored: camera.isFrontCamera,
                onRotationChange: camera.updatePreviewRotation,
                onTap: handlePreviewTap
            )
            if focusExposureMode == .manual, digitalDepthOfFocus > 0 {
                DigitalDepthOfFocusOverlay(
                    measurements: camera.measurements,
                    focusPoint: camera.digitalDepthFocusPoint,
                    level: digitalDepthOfFocus,
                    contentAspectRatio: camera.previewAspectRatio
                )
            }
            if coachingEnabled && activeSituation.showsPersonOverlay {
                OverlayView(
                    advice: camera.advice,
                    measurements: camera.measurements,
                    issues: camera.issues,
                    debugEnabled: camera.debugEnabled,
                    contentAspectRatio: camera.previewAspectRatio,
                    guidedAction: camera.guidedAction
                )
                .accessibilityHidden(true)
            }
            if let meteringIndicatorPoint {
                meteringIndicator(at: meteringIndicatorPoint, target: meteringIndicatorTarget)
            }
            if !camera.isDaliProUnlocked {
                Image("DaliCamWatermark")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 150)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(14)
                    .opacity(0.86)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Dali Cam watermark preview")
            }
            if let remaining = shutterCountdownRemaining {
                VStack(spacing: 14) {
                    Image(systemName: "timer")
                        .font(.title.bold())
                    Text("\(remaining)")
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Button("Cancel timer") { cancelShutterCountdown() }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .accessibilityIdentifier("cancelShutterTimer")
                }
                .padding(28)
                .foregroundStyle(.white)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("shutterCountdown")
            }
            if isBurstCapturing {
                VStack(spacing: 6) {
                    Label("BURST", systemImage: "square.stack.3d.up.fill")
                        .font(.headline.bold())
                    Text("\(burstPhotoCount)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(.red.opacity(0.82), in: Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Burst capture, \(burstPhotoCount) photos")
                    .accessibilityIdentifier("burstCaptureIndicator")
            }
            if focusExposureMode == .manual,
               manualControlsVisible,
               shutterCountdownRemaining == nil,
               !isBurstCapturing {
                manualPreviewControls
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityLabel("Camera preview")
        .accessibilityHint(focusExposureMode == .manual ? "Tap to choose the manual focus point" : "Tap to focus and set exposure")
        .overlay(alignment: .topTrailing) {
            meteringLockIndicators
                .padding(10)
        }
    }

    private var manualPreviewControls: some View {
        ZStack {
            if selectedManualPreviewTool != nil {
                manualPreviewEditor
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 78)
                    .padding(.bottom, 10)
            }

            manualPreviewToolRail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("manualPreviewControls")
    }

    private var manualPreviewToolRail: some View {
        VStack(spacing: 7) {
            Text("M")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 48, height: 24)
                .background(.red.opacity(0.82), in: Capsule())

            ForEach(ManualPreviewTool.allCases) { tool in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedManualPreviewTool = selectedManualPreviewTool == tool ? nil : tool
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tool.symbol)
                            .font(.system(size: 19, weight: .semibold))
                        Text(tool.title)
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 50)
                    .background(
                        selectedManualPreviewTool == tool ? Color.teal.opacity(0.90) : Color.black.opacity(0.72),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(selectedManualPreviewTool == tool ? 0.75 : 0.25))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool.title)
                .accessibilityValue(selectedManualPreviewTool == tool ? "Open" : "Closed")
                .accessibilityIdentifier("manualTool\(tool.rawValue.capitalized)")
            }

            Button {
                selectedManualPreviewTool = nil
                focusExposureMode = .auto
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "a.circle.fill")
                        .font(.system(size: 19, weight: .semibold))
                    Text("Auto")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(width: 58, height: 50)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.25)) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("returnToAutoFromPreview")
        }
    }

    @ViewBuilder
    private var manualPreviewEditor: some View {
        let capabilities = camera.cameraControlCapabilities
        if let selectedManualPreviewTool {
            Group {
                switch selectedManualPreviewTool {
                case .focus:
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Focus point", systemImage: "scope")
                            .font(.headline)
                        Text(camera.digitalDepthFocusPoint == nil
                             ? "Tap a point in the preview to focus there."
                             : "Focus point selected. Tap elsewhere to move it.")
                            .foregroundStyle(camera.digitalDepthFocusPoint == nil ? .yellow : .green)
                            .accessibilityIdentifier("manualFocusPrompt")
                    }

                case .depth:
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Background blur", systemImage: "camera.aperture")
                                .font(.headline)
                            Spacer()
                            Text(digitalDepthOfFocus == 0 ? "Off" : "\(digitalDepthOfFocus)")
                                .font(.headline.monospacedDigit())
                        }
                        Slider(value: digitalDepthOfFocusBinding, in: 0...5, step: 1)
                            .accessibilityLabel("Depth of focus")
                            .accessibilityIdentifier("digitalDepthOfFocus")
                        Text("Tap the subject first for the best separation.")
                            .foregroundStyle(.secondary)
                    }

                case .exposure:
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Exposure", systemImage: "timer")
                            .font(.headline)

                        if capabilities.supportsCustomExposure,
                           capabilities.minimumExposureDurationSeconds > 0,
                           capabilities.maximumExposureDurationSeconds > capabilities.minimumExposureDurationSeconds {
                            if availableProExposurePrograms(capabilities).count > 1 {
                                Picker("Exposure mode", selection: $proExposureProgram) {
                                    ForEach(availableProExposurePrograms(capabilities)) { program in
                                        Text(program.title).tag(program)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: proExposureProgram) { _, program in
                                    handlePreviewExposureProgramChange(program)
                                }
                                .accessibilityIdentifier("previewExposureProgram")
                            }

                            if proExposureProgram == .aperturePriority {
                                LabeledContent("Exposure time", value: "Auto")
                                if let minimum = capabilities.minimumLensAperture,
                                   let maximum = capabilities.maximumLensAperture,
                                   maximum > minimum {
                                    HStack {
                                        Text("Av")
                                        Slider(value: $manualAperture, in: minimum...maximum)
                                            .onChange(of: manualAperture) { _, _ in applyProExposure() }
                                        Text(String(format: "f/%.1f", manualAperture))
                                            .monospacedDigit()
                                    }
                                }
                            } else {
                                Toggle("Exposure time · Auto", isOn: manualShutterAutoBinding)
                                    .accessibilityIdentifier("manualShutterAuto")

                                if !manualShutterAuto {
                                    HStack(spacing: 8) {
                                        Text("Tv")
                                        Slider(value: manualShutterStopBinding, in: shutterStopRange, step: 1.0 / 3.0)
                                            .accessibilityIdentifier("previewShutterSlider")
                                        Text(shutterDurationLabel(manualShutterSeconds))
                                            .font(.subheadline.bold().monospacedDigit())
                                            .frame(minWidth: 54, alignment: .trailing)
                                    }

                                    if proExposureProgram == .manual,
                                       capabilities.maximumISO > capabilities.minimumISO,
                                       capabilities.minimumISO > 0 {
                                        HStack(spacing: 8) {
                                            Text("ISO")
                                            Slider(value: manualISOStopBinding, in: isoStopRange, step: 0.1)
                                                .accessibilityIdentifier("previewISOSlider")
                                            Text("\(Int(manualISO.rounded()))")
                                                .font(.subheadline.bold().monospacedDigit())
                                                .frame(minWidth: 44, alignment: .trailing)
                                        }
                                    }
                                }
                            }
                        } else {
                            Label("Unavailable on this lens", systemImage: "minus.circle")
                                .foregroundStyle(.secondary)
                        }

                        if capabilities.maximumExposureBias > capabilities.minimumExposureBias {
                            Divider()
                            exposureAdjustmentControl(capabilities)
                            Text("The camera preview changes live while you drag. No Apply step is needed.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.white)
            .padding(11)
            .frame(maxWidth: 340)
            .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.28)) }
        }
    }

    private var liveAdvicePanel: some View {
        ScrollView {
            VStack(spacing: 8) {
                if camera.hasUnsavedCapture { captureRecoveryControls }
                if let status = camera.exportStatus {
                    Text(status).font(.subheadline).foregroundStyle(.white)
                }
                if let status = camera.captureStatus {
                    Text(status).font(.subheadline).foregroundStyle(.white)
                }
                switch activeSituation {
                case .portrait, .personScene, .group, .action:
                    if camera.guidedSession.isActive, camera.guidedSession.pose != nil {
                        activePoseCard
                    } else {
                        situationGuidanceCard
                    }
                    if camera.guidedSession.isActive {
                        guidedControls
                    }
                case .closeUp:
                    situationGuidanceCard
                case .food:
                    if chosenFoodRecipe != nil {
                        activeFoodCompositionCard
                    }
                    situationGuidanceCard
                case .landscape:
                    if chosenLandscapeRecipe != nil {
                        activeLandscapeCompositionCard
                    }
                    landscapeGuidanceCard
                case .auto:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var lowerCameraControls: some View {
        VStack(spacing: 8) {
            if coachingEnabled {
                coachingSelectionRow
                liveAdvicePanel
            }
            controls
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var coachingSelectionRow: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(PhotographicSituation.allCases) { mode in
                    Button {
                        shootingMode = mode
                    } label: {
                        HStack {
                            Label(mode.title, systemImage: mode.symbol)
                            if shootingMode == mode {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                selectionControlLabel(
                    title: "Situation",
                    value: shootingMode == .auto ? "Auto" : shootingMode.title,
                    symbol: shootingMode == .auto ? "wand.and.stars" : shootingMode.symbol
                )
            }
            .accessibilityLabel("Situation, \(shootingMode == .auto ? "Auto" : shootingMode.title)")
            .accessibilityIdentifier("situationMenu")

            Menu {
                Section("Quick choice") {
                    Button {
                        setBothCaptureEffects(to: .auto)
                    } label: {
                        Label("Both Auto", systemImage: "wand.and.stars")
                    }
                    .accessibilityIdentifier("quickEffectsAuto")

                    Button {
                        setBothCaptureEffects(to: .off)
                    } label: {
                        Label("Both Off", systemImage: "circle.slash")
                    }
                    .accessibilityIdentifier("quickEffectsOff")
                }

                Section("Filters") {
                    ForEach(EffectApplicationMode.allCases) { mode in
                        Button {
                            storedFilterApplicationMode = mode.rawValue
                        } label: {
                            HStack {
                                Text(mode.title)
                                if selectedFilterApplicationMode == mode {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .accessibilityIdentifier("quickFilterMode_\(mode.rawValue)")
                    }
                }

                Section("Beautifier") {
                    ForEach(EffectApplicationMode.allCases) { mode in
                        Button {
                            storedBeautifierApplicationMode = mode.rawValue
                        } label: {
                            HStack {
                                Text(mode.title)
                                if selectedBeautifierApplicationMode == mode {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .accessibilityIdentifier("quickBeautifierMode_\(mode.rawValue)")
                    }
                }
            } label: {
                selectionControlLabel(
                    title: "Effects",
                    value: captureEffectsDisplayValue,
                    symbol: "wand.and.stars"
                )
            }
            .accessibilityLabel("Effects, Filters \(selectedFilterApplicationMode.title), Beautifier \(selectedBeautifierApplicationMode.title)")
            .accessibilityIdentifier("effectsMenu")

            if activeSituation.showsPersonOverlay {
                Button {
                    selectedPosePackage = nil
                    showPoseChooser = true
                } label: {
                    selectionControlLabel(
                        title: "Posture",
                        value: chosenGuidePose?.title ?? "Natural",
                        symbol: "figure.stand"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Posture, \(chosenGuidePose?.title ?? "Natural")")
                .accessibilityIdentifier("postureMenu")
            }

            if activeSituation == .landscape {
                Button {
                    selectedLandscapePackage = nil
                    showLandscapeChooser = true
                } label: {
                    selectionControlLabel(
                        title: "Landscape",
                        value: chosenLandscapeRecipe?.title ?? "Natural",
                        symbol: "mountain.2"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Landscape, \(chosenLandscapeRecipe?.title ?? "Natural")")
                .accessibilityIdentifier("landscapeMenu")
            }

            if activeSituation == .food {
                Button {
                    showFoodChooser = true
                } label: {
                    selectionControlLabel(
                        title: "Food",
                        value: chosenFoodRecipe?.title ?? "Natural",
                        symbol: "fork.knife"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Food, \(chosenFoodRecipe?.title ?? "Natural")")
                .accessibilityIdentifier("foodMenu")
            }
        }
    }

    private func selectionControlLabel(title: String, value: String, symbol: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(.caption2.bold())
            .foregroundStyle(.teal)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .padding(.horizontal, 4)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private var activeSituation: PhotographicSituation {
        shootingMode == .auto ? automaticSituation : shootingMode
    }

    private var selectedShutterLongPressAction: ShutterLongPressAction {
        ShutterLongPressAction(rawValue: storedShutterLongPressAction) ?? .burst
    }

    private var shutterLongPressActionBinding: Binding<ShutterLongPressAction> {
        Binding(
            get: { selectedShutterLongPressAction },
            set: { storedShutterLongPressAction = $0.rawValue }
        )
    }

    private var selectedPhotoFilterChoice: PhotoFilterChoice {
        PhotoFilterChoice(rawValue: storedPhotoFilterChoice) ?? .auto
    }

    private var selectedFilterApplicationMode: EffectApplicationMode {
        EffectApplicationMode(rawValue: storedFilterApplicationMode) ?? .auto
    }

    private var customPhotoFilterChoice: PhotoFilterChoice {
        switch selectedPhotoFilterChoice {
        case .auto, .none:
            return .natural
        default:
            return selectedPhotoFilterChoice
        }
    }

    private var resolvedPhotoFilter: PhotoFilterChoice {
        switch selectedFilterApplicationMode {
        case .auto: return PhotoFilterChoice.auto.resolved(for: activeSituation)
        case .custom: return customPhotoFilterChoice
        case .off: return .none
        }
    }

    private var photoFilterDisplayValue: String {
        switch selectedFilterApplicationMode {
        case .auto: return "Auto · \(resolvedPhotoFilter.title)"
        case .custom: return "Custom · \(resolvedPhotoFilter.title)"
        case .off: return "Off"
        }
    }

    private var captureEffectsDisplayValue: String {
        if selectedFilterApplicationMode == selectedBeautifierApplicationMode {
            return "Both \(selectedFilterApplicationMode.title)"
        }
        return "F \(selectedFilterApplicationMode.title) · B \(selectedBeautifierApplicationMode.title)"
    }

    private func setBothCaptureEffects(to mode: EffectApplicationMode) {
        storedFilterApplicationMode = mode.rawValue
        storedBeautifierApplicationMode = mode.rawValue
    }

    private var photoFilterPresetBinding: Binding<PhotoFilterChoice> {
        Binding(
            get: { customPhotoFilterChoice },
            set: { storedPhotoFilterChoice = $0.rawValue }
        )
    }

    private var filterApplicationModeBinding: Binding<EffectApplicationMode> {
        Binding(
            get: { selectedFilterApplicationMode },
            set: { storedFilterApplicationMode = $0.rawValue }
        )
    }

    private var selectedCapturePolishChoice: CapturePolishChoice {
        CapturePolishChoice(rawValue: storedCapturePolishChoice) ?? .off
    }

    private var selectedBeautifierApplicationMode: EffectApplicationMode {
        EffectApplicationMode(rawValue: storedBeautifierApplicationMode) ?? .off
    }

    private var customCapturePolishChoice: CapturePolishChoice {
        selectedCapturePolishChoice == .off ? .portraitPolish : selectedCapturePolishChoice
    }

    private var resolvedCapturePolishChoice: CapturePolishChoice {
        switch selectedBeautifierApplicationMode {
        case .off:
            return .off
        case .custom:
            return customCapturePolishChoice
        case .auto:
            switch activeSituation {
            case .portrait, .group, .personScene:
                return .portraitPolish
            case .landscape:
                return .landscapePolish
            case .auto, .action, .closeUp, .food:
                return .generalEnhance
            }
        }
    }

    private var capturePolishChoiceBinding: Binding<CapturePolishChoice> {
        Binding(
            get: { customCapturePolishChoice },
            set: { storedCapturePolishChoice = $0.rawValue }
        )
    }

    private var beautifierApplicationModeBinding: Binding<EffectApplicationMode> {
        Binding(
            get: { selectedBeautifierApplicationMode },
            set: { storedBeautifierApplicationMode = $0.rawValue }
        )
    }

    private var selectedPortraitBeautifierPreset: PortraitBeautifierPreset {
        PortraitBeautifierPreset(rawValue: storedPortraitBeautifierPreset) ?? .polished
    }

    private var selectedLandscapeBeautifierPreset: LandscapeBeautifierPreset {
        LandscapeBeautifierPreset(rawValue: storedLandscapeBeautifierPreset) ?? .vivid
    }

    private var portraitBeautifierPresetBinding: Binding<PortraitBeautifierPreset> {
        Binding(
            get: { selectedPortraitBeautifierPreset },
            set: { preset in
                storedPortraitBeautifierPreset = preset.rawValue
                if preset == .custom { customBeautifierSettingsExpanded = true }
                syncCapturePolish()
            }
        )
    }

    private var landscapeBeautifierPresetBinding: Binding<LandscapeBeautifierPreset> {
        Binding(
            get: { selectedLandscapeBeautifierPreset },
            set: { preset in
                storedLandscapeBeautifierPreset = preset.rawValue
                if preset == .custom { customBeautifierSettingsExpanded = true }
                syncCapturePolish()
            }
        )
    }

    private var customPortraitBeautifierSettings: BeautifySettings {
        BeautifySettings(
            strength: storedPortraitBeautifierStrength,
            landscapeSkyEnabled: false,
            landscapeColorEnabled: false,
            faceBrightnessEnabled: storedPortraitBeautifierBrightness,
            skinSmoothingEnabled: storedPortraitBeautifierSmoothing,
            blemishReductionEnabled: storedPortraitBeautifierBlemishes,
            eyeEnlargementEnabled: storedPortraitBeautifierEyes,
            lipPlumpingEnabled: storedPortraitBeautifierLips
        )
    }

    private var customLandscapeBeautifierSettings: BeautifySettings {
        BeautifySettings(
            strength: storedLandscapeBeautifierStrength,
            landscapeSkyEnabled: storedLandscapeBeautifierSky,
            landscapeColorEnabled: storedLandscapeBeautifierColor,
            faceBrightnessEnabled: false,
            skinSmoothingEnabled: false,
            blemishReductionEnabled: false,
            eyeEnlargementEnabled: false,
            lipPlumpingEnabled: false
        )
    }

    private var activePortraitBeautifierSettings: BeautifySettings {
        selectedPortraitBeautifierPreset == .custom
            ? customPortraitBeautifierSettings
            : selectedPortraitBeautifierPreset.defaultSettings
    }

    private var activeLandscapeBeautifierSettings: BeautifySettings {
        selectedLandscapeBeautifierPreset == .custom
            ? customLandscapeBeautifierSettings
            : selectedLandscapeBeautifierPreset.defaultSettings
    }

    private var capturePortraitBeautifierSettings: BeautifySettings {
        selectedBeautifierApplicationMode == .auto
            ? PortraitBeautifierPreset.polished.defaultSettings
            : activePortraitBeautifierSettings
    }

    private var captureLandscapeBeautifierSettings: BeautifySettings {
        selectedBeautifierApplicationMode == .auto
            ? LandscapeBeautifierPreset.vivid.defaultSettings
            : activeLandscapeBeautifierSettings
    }

    private var portraitBeautifierStrengthBinding: Binding<Double> {
        Binding(
            get: { Double(activePortraitBeautifierSettings.strength) },
            set: { value in
                var settings = activePortraitBeautifierSettings
                settings.strength = max(1, min(5, Int(value.rounded())))
                storeCustomPortraitBeautifierSettings(settings)
                storedPortraitBeautifierPreset = PortraitBeautifierPreset.custom.rawValue
                syncCapturePolish()
            }
        )
    }

    private var landscapeBeautifierStrengthBinding: Binding<Double> {
        Binding(
            get: { Double(activeLandscapeBeautifierSettings.strength) },
            set: { value in
                var settings = activeLandscapeBeautifierSettings
                settings.strength = max(1, min(5, Int(value.rounded())))
                storeCustomLandscapeBeautifierSettings(settings)
                storedLandscapeBeautifierPreset = LandscapeBeautifierPreset.custom.rawValue
                syncCapturePolish()
            }
        )
    }

    private func portraitBeautifierToggleBinding(
        _ keyPath: WritableKeyPath<BeautifySettings, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { activePortraitBeautifierSettings[keyPath: keyPath] },
            set: { enabled in
                var settings = activePortraitBeautifierSettings
                settings[keyPath: keyPath] = enabled
                storeCustomPortraitBeautifierSettings(settings)
                storedPortraitBeautifierPreset = PortraitBeautifierPreset.custom.rawValue
                syncCapturePolish()
            }
        )
    }

    private func landscapeBeautifierToggleBinding(
        _ keyPath: WritableKeyPath<BeautifySettings, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { activeLandscapeBeautifierSettings[keyPath: keyPath] },
            set: { enabled in
                var settings = activeLandscapeBeautifierSettings
                settings[keyPath: keyPath] = enabled
                storeCustomLandscapeBeautifierSettings(settings)
                storedLandscapeBeautifierPreset = LandscapeBeautifierPreset.custom.rawValue
                syncCapturePolish()
            }
        )
    }

    private func storeCustomPortraitBeautifierSettings(_ settings: BeautifySettings) {
        storedPortraitBeautifierStrength = settings.strength
        storedPortraitBeautifierBrightness = settings.faceBrightnessEnabled
        storedPortraitBeautifierSmoothing = settings.skinSmoothingEnabled
        storedPortraitBeautifierBlemishes = settings.blemishReductionEnabled
        storedPortraitBeautifierEyes = settings.eyeEnlargementEnabled
        storedPortraitBeautifierLips = settings.lipPlumpingEnabled
    }

    private func storeCustomLandscapeBeautifierSettings(_ settings: BeautifySettings) {
        storedLandscapeBeautifierStrength = settings.strength
        storedLandscapeBeautifierSky = settings.landscapeSkyEnabled
        storedLandscapeBeautifierColor = settings.landscapeColorEnabled
    }

    private var customPhotoFilterSettings: PhotoFilterSettings {
        PhotoFilterSettings(
            exposure: storedPhotoFilterExposure,
            warmth: storedPhotoFilterWarmth,
            color: storedPhotoFilterColor,
            contrast: storedPhotoFilterContrast,
            softness: storedPhotoFilterSoftness,
            detail: storedPhotoFilterDetail,
            blueSky: storedPhotoFilterBlueSky
        )
    }

    private var activePhotoFilterSettings: PhotoFilterSettings {
        resolvedPhotoFilter == .custom
            ? customPhotoFilterSettings
            : resolvedPhotoFilter.defaultSettings
    }

    private func photoFilterAdjustmentBinding(
        _ keyPath: WritableKeyPath<PhotoFilterSettings, Int>,
        range: ClosedRange<Int>
    ) -> Binding<Double> {
        Binding(
            get: { Double(activePhotoFilterSettings[keyPath: keyPath]) },
            set: { value in
                var settings = activePhotoFilterSettings
                settings[keyPath: keyPath] = max(range.lowerBound, min(range.upperBound, Int(value.rounded())))
                storeCustomPhotoFilterSettings(settings)
                storedPhotoFilterChoice = PhotoFilterChoice.custom.rawValue
                storedFilterApplicationMode = EffectApplicationMode.custom.rawValue
                camera.setPhotoFilter(settings: settings)
            }
        )
    }

    private func storeCustomPhotoFilterSettings(_ settings: PhotoFilterSettings) {
        storedPhotoFilterExposure = settings.exposure
        storedPhotoFilterWarmth = settings.warmth
        storedPhotoFilterColor = settings.color
        storedPhotoFilterContrast = settings.contrast
        storedPhotoFilterSoftness = settings.softness
        storedPhotoFilterDetail = settings.detail
        storedPhotoFilterBlueSky = settings.blueSky
    }

    private var photoFilterDescription: String {
        if selectedFilterApplicationMode == .auto {
            return "Auto chooses one named preset for the scene. It currently uses \(resolvedPhotoFilter.title) for \(activeSituation.title.lowercased())."
        }
        if selectedFilterApplicationMode == .off || !activePhotoFilterSettings.isActive {
            return "Off finalizes new photos without a filter."
        }
        if resolvedPhotoFilter == .custom {
            return "Custom uses your saved individual settings below."
        }
        return "\(resolvedPhotoFilter.title) is one complete preset: a saved combination of the individual settings below."
    }

    private func syncPhotoFilter() {
        camera.setPhotoFilter(settings: activePhotoFilterSettings)
    }

    private func syncCapturePolish() {
        camera.setCapturePolish(
            choice: resolvedCapturePolishChoice,
            strength: storedCapturePolishStrength,
            portraitSettings: capturePortraitBeautifierSettings,
            landscapeSettings: captureLandscapeBeautifierSettings
        )
    }

    private func selectPosture(_ pose: GuidedPose?) {
        chosenGuidePose = pose
        guideCollection = pose?.package ?? guideCollection
        if let pose {
            let recommendedAngle = pose.recommendedCameraAngle
            selectedAngle = recommendedAngle
            chosenCameraPosition = recommendedAngle.guidedPosition
        } else {
            chosenCameraPosition = nil
        }
        camera.beginGuidance(pose: pose, position: chosenCameraPosition, moveRight: guideMoveRight)
    }

    private var postureMontage: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    Button {
                        selectPosture(nil)
                        showPoseChooser = false
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "leaf.fill")
                                .font(.title2)
                                .foregroundStyle(.teal)
                                .frame(width: 46, height: 46)
                                .background(.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Natural")
                                    .font(.headline)
                                Text("No posture coaching")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if chosenGuidePose == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.teal)
                            }
                        }
                        .padding(12)
                        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(chosenGuidePose == nil ? .teal : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("naturalPostureOption")

                    if let selectedPosePackage {
                        postureMontageSection(for: selectedPosePackage)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose a package")
                                .font(.title2.bold())
                            Text("Start with the kind of portrait, then choose a pose.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(GuidedPoseCollectionID.allCases) { package in
                            posturePackageCard(for: package)
                        }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(selectedPosePackage?.title ?? "Posture packages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedPosePackage != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            selectedPosePackage = nil
                        } label: {
                            Label("Packages", systemImage: "chevron.left")
                        }
                        .accessibilityIdentifier("backToPosturePackages")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showPoseChooser = false }
                }
            }
            .accessibilityIdentifier("postureMontage")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func posturePackageCard(for package: GuidedPoseCollectionID) -> some View {
        let poses = GuidedPose.allCases.filter { $0.package == package }

        return Button {
            selectedPosePackage = package
            guideCollection = package
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(Array(poses.prefix(3))) { pose in
                        Image(pose.exampleAssetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 38, height: 86)
                            .clipped()
                    }
                }
                .frame(width: 126, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 3) {
                    Text(package.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(poses.count) poses")
                        .font(.subheadline.bold())
                        .foregroundStyle(.teal)
                    Text(posturePackageDescription(package))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                if chosenGuidePose?.package == package {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.teal)
                }
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 17))
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(chosenGuidePose?.package == package ? .teal : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(package.title), \(poses.count) poses, \(posturePackageDescription(package))")
        .accessibilityIdentifier("posturePackage_\(package.rawValue)")
    }

    private func posturePackageDescription(_ package: GuidedPoseCollectionID) -> String {
        switch package {
        case .masculine: return "relaxed and structured solo poses"
        case .feminine: return "soft and expressive solo poses"
        case .professional: return "headshots, profiles, and workplace portraits"
        case .couples: return "coordinated two-person poses"
        case .weddingEngagement: return "rings, ceremony moments, dance, and celebration"
        case .friendsGroups: return "natural poses for three or more people"
        case .family: return "warm poses across ages and generations"
        case .graduation: return "diploma, cap, gown, and celebration poses"
        case .maternity: return "comfort-first solo and husband poses"
        case .kids: return "short, playful, grounded child and sibling poses"
        case .newborn: return "caregiver-supported and safe back-position photos"
        }
    }

    private func postureMontageSection(for package: GuidedPoseCollectionID) -> some View {
        let poses = GuidedPose.allCases.filter { $0.package == package }
        let columns = [GridItem(.adaptive(minimum: 145, maximum: 230), spacing: 12)]

        return VStack(alignment: .leading, spacing: 12) {
            Text(package.title)
                .font(.title3.bold())

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(poses) { pose in
                    Button {
                        selectPosture(pose)
                        showPoseChooser = false
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                Image(pose.exampleAssetName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(0.82, contentMode: .fit)
                                    .clipped()

                                if chosenGuidePose == pose {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white, .teal)
                                        .padding(8)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text(pose.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Text(pose.category.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Label(pose.recommendedCameraAngle.title, systemImage: pose.recommendedCameraAngle.symbol)
                                .font(.caption2.bold())
                                .foregroundStyle(.teal)
                                .lineLimit(1)

                            Label(pose.recommendedLighting.title, systemImage: pose.recommendedLighting.symbol)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(chosenGuidePose == pose ? .teal : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(pose.title), \(pose.category.title), \(pose.setting.title)")
                    .accessibilityIdentifier("postureOption_\(pose.rawValue)")
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text("Dali Cam")
                .font(.headline.bold())
                .foregroundStyle(.teal)
                .accessibilityIdentifier("cameraBrandName")

            Spacer()

            Button {
                if focusExposureMode == .manual {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        manualControlsVisible.toggle()
                        if !manualControlsVisible { selectedManualPreviewTool = nil }
                    }
                } else {
                    focusExposureMode = .manual
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            manualControlsVisible = true
                        }
                    }
                }
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "m.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text("Manual")
                        .font(.system(size: 8, weight: .bold))
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(manualControlsVisible ? .black : (focusExposureMode == .manual ? .teal : .white))
            .background(manualControlsVisible ? .teal : .black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(manualControlsVisible ? "Hide manual controls" : "Show manual controls")
            .accessibilityIdentifier("manualControlsButton")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    coachingEnabled.toggle()
                    showPoseChooser = false
                    if coachingEnabled {
                        camera.refreshStillPhotoAdvice()
                    } else {
                        camera.beginGuidance(pose: nil, position: nil)
                    }
                }
            } label: {
                Image(systemName: coachingEnabled ? "lightbulb.fill" : "lightbulb.slash")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(coachingEnabled ? .black : .white)
            .background(coachingEnabled ? .teal : .black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(coachingEnabled ? "Turn coaching off" : "Turn coaching on")
            .accessibilityIdentifier("coachingToggle")

            Button {
                showAppSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("App settings")
            .accessibilityIdentifier("appSettingsButton")

            Button {
                camera.switchCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            .disabled(camera.reviewImage != nil || camera.isCapturing || camera.isAnalyzingPhoto)
            .accessibilityLabel("Switch camera")
        }
    }

    private var cameraControlSheet: some View {
        let capabilities = camera.cameraControlCapabilities

        return NavigationStack {
            Form {
                basicCameraControlsSection
                photoFilterControlsSection
                capturePolishControlsSection
                advancedCameraControlsSection(capabilities)
            }
            .navigationTitle("Camera controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showCameraControls = false }
                }
            }
        }
    }

    private var appSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("About") {
                    LabeledContent("App", value: "Dali Camera")
                    LabeledContent("Version", value: appVersionLabel)
                    Text("Live photography guidance, camera controls, capture effects, and photo enhancement.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        showAppSettings = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showTutor = true
                        }
                    } label: {
                        Label("Quick camera tutorial", systemImage: "play.rectangle")
                    }
                    .accessibilityIdentifier("cameraTutorialButton")
                }

                Section("Language") {
                    LabeledContent {
                        Text("System default")
                    } label: {
                        Label("Language choice", systemImage: "globe")
                    }
                    Label("Additional languages coming soon", systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Display") {
                    LabeledContent {
                        Text("System appearance")
                    } label: {
                        Label("Display option", systemImage: "circle.lefthalf.filled")
                    }
                    Label("Light and dark appearance choices coming soon", systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Purchase") {
                    LabeledContent {
                        Text("Coming soon")
                    } label: {
                        Label("Dali Pro", systemImage: "crown")
                    }
                    Text("Dali Pro will remove the signature watermark from captured photos and unlock premium camera features.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LabeledContent {
                        Text("Coming soon")
                    } label: {
                        Label("Restore purchases", systemImage: "arrow.clockwise")
                    }
                }
            }
            .navigationTitle("App Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showAppSettings = false }
                }
            }
            .accessibilityIdentifier("appSettingsSheet")
        }
    }

    private var appVersionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var basicCameraControlsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $shutterControlsExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Photo timer", systemImage: "timer")
                    .font(.headline)

                Picker("Photo timer", selection: $storedShutterTimerSeconds) {
                    ForEach(ShutterTimerDelay.allCases) { delay in
                        Text(delay.title).tag(delay.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("shutterTimerPicker")
            }

            Toggle(
                "Voice shutter",
                isOn: Binding(
                    get: { voiceShutter.isEnabled },
                    set: { voiceShutter.setEnabled($0) }
                )
            )
            .accessibilityIdentifier("voiceShutterToggle")

            Label(
                voiceShutter.statusText,
                systemImage: voiceShutter.isListening ? "waveform.circle.fill" : "mic.circle"
            )
            .font(.footnote)
            .foregroundStyle(voiceShutter.isListening ? .green : .secondary)
            .accessibilityIdentifier("voiceShutterStatus")

            if voiceShutter.isEnabled {
                TextField("Your shutter word or phrase", text: $storedVoiceShutterCustomPhrase)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("voiceShutterCustomPhrase")

                Text(voiceShutterCommandHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("voiceShutterCommands")
            }

            if voiceShutter.permissionDenied {
                Button("Open Settings") { openSettings() }
                    .accessibilityIdentifier("voiceShutterOpenSettings")
            }

            Picker("Long-press shutter", selection: shutterLongPressActionBinding) {
                ForEach(ShutterLongPressAction.allCases) { action in
                    Text(action.title).tag(action)
                }
            }
            .accessibilityIdentifier("shutterLongPressAction")

            Text(selectedShutterLongPressAction.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Choose when a photo is taken, which spoken phrase triggers it, and what holding the shutter button does.")
                .font(.caption)
                .foregroundStyle(.secondary)
            } label: {
                Label("Shutter Controls", systemImage: "camera.shutter.button")
                    .font(.headline)
            }
            .accessibilityIdentifier("shutterControlsGroup")
        }
    }

    private var voiceShutterCommandHelp: String {
        let customPhrase = storedVoiceShutterCustomPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        if customPhrase.isEmpty {
            return "Add your own shutter word, or say “Cheese,” “Take photo,” “Take a picture,” “Capture photo,” or “Snap a photo.”"
        }
        return "Say “\(customPhrase),” or use a built-in command such as “Cheese” or “Take photo.”"
    }

    private var photoFilterControlsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $filterControlsExpanded) {
            Text("Auto chooses for the scene, Custom lets you select and fine-tune a preset, and Off applies nothing.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Application", selection: filterApplicationModeBinding) {
                ForEach(EffectApplicationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("filterApplicationMode")

            Text(photoFilterDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            if selectedFilterApplicationMode == .custom {
                Picker("Filter preset", selection: photoFilterPresetBinding) {
                    ForEach(PhotoFilterChoice.namedPresets) { choice in
                        Label(choice.title, systemImage: choice.symbol).tag(choice)
                    }
                    Label("Custom", systemImage: PhotoFilterChoice.custom.symbol)
                        .tag(PhotoFilterChoice.custom)
                }
                .accessibilityIdentifier("photoFilterPicker")

                DisclosureGroup(isExpanded: $customFilterSettingsExpanded) {
                    Text("Moving any slider copies the current preset into Custom, then changes that individual setting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    photoFilterAdjustmentRow("Exposure", keyPath: \.exposure, range: -5...5, symbol: "sun.max", accessibilityID: "photoFilterExposure")
                    photoFilterAdjustmentRow("Warmth", keyPath: \.warmth, range: -5...5, symbol: "thermometer.sun", accessibilityID: "photoFilterWarmth")
                    photoFilterAdjustmentRow("Color", keyPath: \.color, range: 0...5, symbol: "paintpalette", accessibilityID: "photoFilterColor")
                    photoFilterAdjustmentRow("Contrast", keyPath: \.contrast, range: -5...5, symbol: "circle.lefthalf.filled", accessibilityID: "photoFilterContrast")
                    photoFilterAdjustmentRow("Softness", keyPath: \.softness, range: 0...5, symbol: "cloud", accessibilityID: "photoFilterSoftness")
                    photoFilterAdjustmentRow("Detail", keyPath: \.detail, range: 0...5, symbol: "camera.macro", accessibilityID: "photoFilterDetail")
                    photoFilterAdjustmentRow("Blue sky", keyPath: \.blueSky, range: 0...5, symbol: "cloud.sun", accessibilityID: "photoFilterBlueSky")
                } label: {
                    Label("Individual settings", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("customFilterSettings")
            }
            } label: {
                Label("Filters", systemImage: "camera.filters")
                    .font(.headline)
            }
            .accessibilityIdentifier("filterControlsGroup")
        }
    }

    private func photoFilterAdjustmentRow(
        _ title: String,
        keyPath: WritableKeyPath<PhotoFilterSettings, Int>,
        range: ClosedRange<Int>,
        symbol: String,
        accessibilityID: String
    ) -> some View {
        let value = activePhotoFilterSettings[keyPath: keyPath]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Text(range.lowerBound < 0 ? String(format: "%+d", value) : "\(value)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: photoFilterAdjustmentBinding(keyPath, range: range),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .accessibilityLabel(title)
            .accessibilityValue("Level \(value)")
            .accessibilityIdentifier(accessibilityID)
        }
    }

    private var capturePolishControlsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $capturePolishExpanded) {
                Text("Auto chooses for the scene, Custom lets you select and fine-tune a beautifier, and Off applies nothing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Application", selection: beautifierApplicationModeBinding) {
                    ForEach(EffectApplicationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("beautifierApplicationMode")

                if selectedBeautifierApplicationMode == .auto {
                    Text("Auto currently uses \(resolvedCapturePolishChoice.title) for \(activeSituation.title.lowercased()).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if selectedBeautifierApplicationMode == .off {
                    Text("Off finalizes new photos without a beautifier.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Beautifier type", selection: capturePolishChoiceBinding) {
                        ForEach(CapturePolishChoice.allCases.filter { $0 != .off }) { choice in
                            Label(choice.title, systemImage: choice.symbol).tag(choice)
                        }
                    }
                    .accessibilityIdentifier("capturePolishPicker")

                    switch customCapturePolishChoice {
                    case .off:
                        EmptyView()

                case .generalEnhance:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Enhancement level")
                            Spacer()
                            Text("\(storedCapturePolishStrength) · \(CapturePolishChoice.levelName(storedCapturePolishStrength))")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(storedCapturePolishStrength) },
                                set: { storedCapturePolishStrength = Int($0.rounded()) }
                            ),
                            in: 1...5,
                            step: 1
                        )
                        .accessibilityLabel("Enhancement level")
                        .accessibilityIdentifier("capturePolishStrength")
                    }

                    Text(capturePolishDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                case .portraitPolish:
                    Picker("Portrait preset", selection: portraitBeautifierPresetBinding) {
                        ForEach(PortraitBeautifierPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .accessibilityIdentifier("portraitBeautifierPreset")

                    Text("\(selectedPortraitBeautifierPreset.title) combines the portrait settings below. Changing any individual setting creates Custom.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    DisclosureGroup(isExpanded: $customBeautifierSettingsExpanded) {
                        beautifierLevelRow(
                            title: "Portrait level",
                            settings: activePortraitBeautifierSettings,
                            value: portraitBeautifierStrengthBinding,
                            accessibilityID: "portraitBeautifierStrength"
                        )
                        Toggle("Brighten and even skin", isOn: portraitBeautifierToggleBinding(\.faceBrightnessEnabled))
                        Toggle("Smooth skin", isOn: portraitBeautifierToggleBinding(\.skinSmoothingEnabled))
                        Toggle("Reduce blemishes", isOn: portraitBeautifierToggleBinding(\.blemishReductionEnabled))
                        Toggle("Enlarge eyes", isOn: portraitBeautifierToggleBinding(\.eyeEnlargementEnabled))
                        Toggle("Plump lips", isOn: portraitBeautifierToggleBinding(\.lipPlumpingEnabled))
                    } label: {
                        Label("Portrait individual settings", systemImage: "person.crop.circle")
                    }
                    .accessibilityIdentifier("portraitBeautifierSettings")

                case .landscapePolish:
                    Picker("Landscape preset", selection: landscapeBeautifierPresetBinding) {
                        ForEach(LandscapeBeautifierPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .accessibilityIdentifier("landscapeBeautifierPreset")

                    Text("\(selectedLandscapeBeautifierPreset.title) combines the landscape settings below. Changing any individual setting creates Custom.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    DisclosureGroup(isExpanded: $customBeautifierSettingsExpanded) {
                        beautifierLevelRow(
                            title: "Landscape level",
                            settings: activeLandscapeBeautifierSettings,
                            value: landscapeBeautifierStrengthBinding,
                            accessibilityID: "landscapeBeautifierStrength"
                        )
                        Toggle("Blue sky & cloud detail", isOn: landscapeBeautifierToggleBinding(\.landscapeSkyEnabled))
                        Toggle("Rich landscape color", isOn: landscapeBeautifierToggleBinding(\.landscapeColorEnabled))
                    } label: {
                        Label("Landscape individual settings", systemImage: "mountain.2")
                    }
                    .accessibilityIdentifier("landscapeBeautifierSettings")
                    }
                }
            } label: {
                Label("Beautifier", systemImage: "wand.and.stars.inverse")
                    .font(.headline)
            }
            .accessibilityIdentifier("capturePolishGroup")
        }
    }

    private func beautifierLevelRow(
        title: String,
        settings: BeautifySettings,
        value: Binding<Double>,
        accessibilityID: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(settings.strength) · \(settings.levelName)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 1...5, step: 1)
                .accessibilityLabel(title)
                .accessibilityValue("Level \(settings.strength), \(settings.levelName)")
                .accessibilityIdentifier(accessibilityID)
        }
    }

    private var capturePolishDescription: String {
        switch resolvedCapturePolishChoice {
        case .off:
            return "No beautifier is applied."
        case .generalEnhance:
            return "Improves overall tone, color, clarity, and noise using the General Enhance options."
        case .portraitPolish:
            return "Applies the enabled face and skin options when a face is detected."
        case .landscapePolish:
            return "Applies the enabled landscape color, blue-sky, and cloud options."
        }
    }

    private func advancedCameraControlsSection(_ capabilities: CameraControlCapabilities) -> some View {
        Section {
            DisclosureGroup(isExpanded: $advancedControlsExpanded) {
            Text("Auto keeps focus and exposure under camera control. Manual closes this panel and places focus, depth, and exposure controls directly over the live preview.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Mode", selection: $focusExposureMode) {
                ForEach(FocusExposureMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("focusExposureMode")
            .onChange(of: focusExposureMode) { _, mode in
                dismissedAssistedRecommendation = nil
                autoAssistanceEnabled = false
                if mode == .manual {
                    selectedManualPreviewTool = nil
                    manualControlsVisible = false
                    manualShutterAuto = true
                    proExposureEnabled = false
                    camera.resetExposureToAuto()
                    syncProExposureValues()
                    camera.setDigitalDepthBlur(level: digitalDepthOfFocus)
                    DispatchQueue.main.async { showCameraControls = false }
                } else {
                    selectedManualPreviewTool = nil
                    manualControlsVisible = false
                    proExposureEnabled = false
                    proExposureAdjustment = 0
                    camera.setDigitalDepthBlur(level: 0)
                    camera.setDigitalDepthFocusPoint(nil)
                    meteringIndicatorTask?.cancel()
                    meteringIndicatorPoint = nil
                    camera.resetCameraControlsToAuto()
                }
            }

            if capabilities.isAvailable {
                Divider()
                LabeledContent("Camera", value: capabilities.cameraName)
                LabeledContent("Lens", value: capabilities.lensName)
                if let duration = capabilities.currentExposureDurationSeconds {
                    LabeledContent("Tv", value: shutterDurationLabel(duration))
                }
                if let aperture = capabilities.currentLensAperture {
                    LabeledContent("Av", value: String(format: "f/%.1f", aperture))
                }
                if let iso = capabilities.currentISO {
                    LabeledContent("ISO", value: "\(Int(iso.rounded()))")
                }

                if focusExposureMode == .auto {
                    Label("Continuous auto focus and exposure", systemImage: "a.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("focusExposureAutoStatus")
                } else {
                    Label("Manual controls are active on the preview", systemImage: "rectangle.on.rectangle")
                        .foregroundStyle(.teal)

                    Text("Tap the live image for focus, then adjust digital depth of focus and exposure while seeing the result.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Return Focus and Exposure to Auto") {
                        focusExposureMode = .auto
                        proExposureEnabled = false
                        camera.resetCameraControlsToAuto()
                    }
                    .accessibilityIdentifier("resetCameraControls")
                }
            } else {
                Label("Focus and Exposure controls require an iPhone", systemImage: "iphone.gen3")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("cameraControlsUnavailable")
            }
            } label: {
                Label("Focus and Exposure", systemImage: "viewfinder.circle")
                    .font(.headline)
            }
            .accessibilityIdentifier("focusExposureControlsGroup")
        }
    }

    private var exposureBiasBinding: Binding<Double> {
        Binding(
            get: { camera.cameraControlCapabilities.currentExposureBias },
            set: { camera.setExposureBias($0) }
        )
    }

    @ViewBuilder
    private func proExposureControls(_ capabilities: CameraControlCapabilities) -> some View {
        if capabilities.supportsCustomExposure,
           capabilities.minimumExposureDurationSeconds > 0,
           capabilities.maximumExposureDurationSeconds > capabilities.minimumExposureDurationSeconds,
           capabilities.minimumISO > 0,
           capabilities.maximumISO > capabilities.minimumISO {
                Divider()
                Label("Exposure", systemImage: "camera.aperture")
                    .font(.headline)

                if availableProExposurePrograms(capabilities).count > 1 {
                    Picker("Exposure program", selection: $proExposureProgram) {
                        ForEach(availableProExposurePrograms(capabilities)) { program in
                            Text(program.title).tag(program)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: proExposureProgram) { _, program in
                        if program != .manual { linkedISOEnabled = false }
                        proExposureAdjustment = 0
                        camera.setExposureBias(0)
                        applyProExposure()
                    }
                    .accessibilityIdentifier("proExposureProgram")
                }

                exposureMeter(capabilities.currentExposureTargetOffset)

                if proExposureProgram != .aperturePriority {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Tv · Shutter time")
                            Spacer()
                            Text(shutterDurationLabel(manualShutterSeconds))
                                .font(.headline.monospacedDigit())
                        }
                        Slider(value: manualShutterStopBinding, in: shutterStopRange, step: 1.0 / 3.0)
                            .accessibilityIdentifier("manualShutterSlider")
                    }
                }

                if proExposureProgram == .manual {
                    Toggle("Linked ISO", isOn: $linkedISOEnabled)
                        .onChange(of: linkedISOEnabled) { _, enabled in
                            proExposureAdjustment = 0
                            if enabled {
                                linkedExposureBaseProduct = manualShutterSeconds * manualISO
                            }
                            applyProExposure()
                        }
                        .accessibilityIdentifier("linkedISOToggle")

                    if linkedISOEnabled {
                        LabeledContent("ISO", value: "Linked · \(Int(manualISO.rounded()))")
                        exposureAdjustmentControl(capabilities)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("ISO")
                                Spacer()
                                Text("\(Int(manualISO.rounded()))")
                                    .font(.headline.monospacedDigit())
                            }
                            Slider(value: manualISOStopBinding, in: isoStopRange, step: 0.1)
                                .accessibilityIdentifier("manualISOSlider")
                        }
                    }
                } else {
                    LabeledContent("ISO", value: "Auto")
                    exposureAdjustmentControl(capabilities)
                }

                if proExposureProgram == .aperturePriority,
                   let minimum = capabilities.minimumLensAperture,
                   let maximum = capabilities.maximumLensAperture,
                   maximum > minimum {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Av · Aperture")
                            Spacer()
                            Text(String(format: "f/%.1f", manualAperture))
                                .font(.headline.monospacedDigit())
                        }
                        Slider(value: $manualAperture, in: minimum...maximum)
                            .onChange(of: manualAperture) { _, _ in applyProExposure() }
                            .accessibilityIdentifier("manualApertureSlider")
                    }
                } else if let aperture = capabilities.currentLensAperture {
                    LabeledContent("Av · Aperture", value: String(format: "f/%.1f · Fixed", aperture))
                        .accessibilityIdentifier("fixedApertureValue")
                }

                Text(proExposureProgram == .manual
                     ? "Manual keeps Tv and ISO independent. Linked ISO compensates when Tv changes; the meter shows remaining under- or overexposure."
                     : "The selected priority stays fixed while the camera automatically balances the remaining exposure values.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
        } else {
            Label("Manual exposure is unavailable on this camera", systemImage: "minus.circle")
                .foregroundStyle(.secondary)
        }
    }

    private func availableProExposurePrograms(_ capabilities: CameraControlCapabilities) -> [ProExposureProgram] {
        var programs: [ProExposureProgram] = [.manual]
        if capabilities.supportsShutterPriority { programs.append(.shutterPriority) }
        if capabilities.supportsAperturePriority { programs.append(.aperturePriority) }
        return programs
    }

    private var shutterStopRange: ClosedRange<Double> {
        let capabilities = camera.cameraControlCapabilities
        return log2(capabilities.minimumExposureDurationSeconds)...log2(capabilities.maximumExposureDurationSeconds)
    }

    private var isoStopRange: ClosedRange<Double> {
        let capabilities = camera.cameraControlCapabilities
        return log2(capabilities.minimumISO)...log2(capabilities.maximumISO)
    }

    private var manualShutterStopBinding: Binding<Double> {
        Binding(
            get: { log2(manualShutterSeconds) },
            set: {
                manualShutterAuto = false
                proExposureEnabled = true
                manualShutterSeconds = pow(2, $0)
                if linkedISOEnabled {
                    updateLinkedISO()
                } else if proExposureProgram == .manual {
                    proExposureAdjustment = 0
                    linkedExposureBaseProduct = manualShutterSeconds * manualISO
                }
                applyProExposure()
            }
        )
    }

    private var manualShutterAutoBinding: Binding<Bool> {
        Binding(
            get: { manualShutterAuto },
            set: { isAuto in
                manualShutterAuto = isAuto
                if isAuto {
                    proExposureEnabled = false
                    proExposureAdjustment = 0
                    camera.resetExposureToAuto()
                } else {
                    proExposureEnabled = true
                    syncProExposureValues()
                    applyProExposure()
                }
            }
        )
    }

    private var digitalDepthOfFocusBinding: Binding<Double> {
        Binding(
            get: { Double(digitalDepthOfFocus) },
            set: { value in
                digitalDepthOfFocus = Int(value.rounded())
                camera.setDigitalDepthBlur(level: digitalDepthOfFocus)
            }
        )
    }

    private func handlePreviewExposureProgramChange(_ program: ProExposureProgram) {
        if program != .manual { linkedISOEnabled = false }
        proExposureAdjustment = 0
        camera.setExposureBias(0)
        if program == .aperturePriority {
            manualShutterAuto = true
        } else {
            manualShutterAuto = false
        }
        proExposureEnabled = true
        applyProExposure()
    }

    private var manualISOStopBinding: Binding<Double> {
        Binding(
            get: { log2(manualISO) },
            set: {
                manualISO = pow(2, $0)
                proExposureAdjustment = 0
                linkedExposureBaseProduct = manualShutterSeconds * manualISO
                applyProExposure()
            }
        )
    }

    private func syncProExposureValues() {
        let capabilities = camera.cameraControlCapabilities
        if let duration = capabilities.currentExposureDurationSeconds {
            manualShutterSeconds = capabilities.clampedExposureDuration(duration)
        }
        if let iso = capabilities.currentISO {
            manualISO = capabilities.clampedISO(iso)
        }
        if let aperture = capabilities.currentLensAperture {
            manualAperture = capabilities.clampedLensAperture(aperture)
        }
        linkedExposureBaseProduct = manualShutterSeconds * manualISO
        proExposureAdjustment = 0
        let available = availableProExposurePrograms(capabilities)
        if !available.contains(proExposureProgram) { proExposureProgram = .manual }
    }

    private func applyProExposure() {
        guard proExposureEnabled else { return }
        camera.setProExposure(
            program: proExposureProgram,
            shutterSeconds: manualShutterSeconds,
            iso: manualISO,
            aperture: manualAperture
        )
    }

    private func updateLinkedISO() {
        guard linkedISOEnabled, proExposureProgram == .manual else { return }
        manualISO = camera.cameraControlCapabilities.linkedISO(
            baseExposureProduct: linkedExposureBaseProduct,
            shutterSeconds: manualShutterSeconds,
            adjustmentEV: proExposureAdjustment
        )
    }

    @ViewBuilder
    private func exposureAdjustmentControl(_ capabilities: CameraControlCapabilities) -> some View {
        let minimumAdjustment = max(-2, capabilities.minimumExposureBias)
        let maximumAdjustment = min(2, capabilities.maximumExposureBias)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Under / over exposure", systemImage: "plusminus.circle")
                Spacer()
                Text(String(format: "%+.1f EV", proExposureAdjustment))
                    .font(.headline.monospacedDigit())
            }

            HStack(spacing: 8) {
                Image(systemName: "sun.min.fill")
                    .accessibilityLabel("Underexpose")

                Slider(
                    value: liveExposureAdjustmentBinding,
                    in: minimumAdjustment...maximumAdjustment,
                    step: 0.1
                )
                .accessibilityLabel("Under or over exposure")
                .accessibilityValue(String(format: "%+.1f EV", proExposureAdjustment))

                Image(systemName: "sun.max.fill")
                    .accessibilityLabel("Overexpose")
            }

            HStack {
                Text("Under")
                Spacer()
                Button("Reset to 0") {
                    resetLiveExposureAdjustment()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!exposureAdjustmentNeedsReset)
                .accessibilityIdentifier("resetExposureAdjustment")
                Spacer()
                Text("Over")
            }
            .font(.caption2)
        }
        .accessibilityIdentifier("proExposureAdjustment")
    }

    private var liveExposureAdjustmentBinding: Binding<Double> {
        Binding(
            get: { proExposureAdjustment },
            set: { adjustment in
                proExposureAdjustment = adjustment
                applyLiveExposureAdjustment(adjustment)
            }
        )
    }

    private var exposureAdjustmentNeedsReset: Bool {
        if abs(proExposureAdjustment) >= 0.01 { return true }
        let usesCameraBias = !proExposureEnabled || proExposureProgram != .manual || manualShutterAuto
        return usesCameraBias && abs(camera.cameraControlCapabilities.currentExposureBias) >= 0.01
    }

    private func resetLiveExposureAdjustment() {
        proExposureAdjustment = 0
        applyLiveExposureAdjustment(0)
    }

    private func applyLiveExposureAdjustment(_ adjustment: Double) {
        if proExposureProgram == .manual, !manualShutterAuto, proExposureEnabled {
            manualISO = camera.cameraControlCapabilities.linkedISO(
                baseExposureProduct: linkedExposureBaseProduct,
                shutterSeconds: manualShutterSeconds,
                adjustmentEV: adjustment
            )
            applyProExposure()
        } else {
            camera.setExposureBias(adjustment)
        }
    }

    private func exposureMeter(_ offset: Double) -> some View {
        let clampedOffset = min(3, max(-3, offset))
        let status = if abs(offset) < 0.25 {
            "Balanced"
        } else if offset < 0 {
            "Underexposed"
        } else {
            "Overexposed"
        }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Exposure meter")
                Spacer()
                Text(String(format: "%+.1f EV · %@", offset, status))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(abs(offset) < 0.25 ? .green : .orange)
            }
            Gauge(value: clampedOffset, in: -3...3) {
                Text("Exposure")
            } currentValueLabel: {
                EmptyView()
            } minimumValueLabel: {
                Text("−")
            } maximumValueLabel: {
                Text("+")
            }
            .gaugeStyle(.linearCapacity)
            .accessibilityIdentifier("proExposureMeter")
        }
    }

    private var focusLockBinding: Binding<Bool> {
        Binding(
            get: { camera.cameraControlCapabilities.isFocusLocked },
            set: { camera.setFocusLocked($0) }
        )
    }

    private var exposureLockBinding: Binding<Bool> {
        Binding(
            get: { camera.cameraControlCapabilities.isExposureLocked },
            set: { camera.setExposureLocked($0) }
        )
    }

    private func availableTapMeteringTargets(_ capabilities: CameraControlCapabilities) -> [TapMeteringTarget] {
        if capabilities.supportsFocusPoint && capabilities.supportsExposurePoint {
            return TapMeteringTarget.allCases
        }
        if capabilities.supportsFocusPoint { return [.focus] }
        if capabilities.supportsExposurePoint { return [.exposure] }
        return []
    }

    private func handlePreviewTap(previewPoint: CGPoint, devicePoint: CGPoint) {
        guard camera.reviewImage == nil, shutterCountdownRemaining == nil else { return }
        let available = availableTapMeteringTargets(camera.cameraControlCapabilities)
        guard !available.isEmpty else { return }
        let target: TapMeteringTarget
        if focusExposureMode == .manual, available.contains(.focus) {
            target = .focus
            camera.setDigitalDepthFocusPoint(previewPoint)
        } else {
            target = available.contains(.focusAndExposure) ? .focusAndExposure : available[0]
        }
        camera.setMeteringPoint(devicePoint, target: target)
        meteringIndicatorTask?.cancel()
        meteringIndicatorTarget = target
        withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
            meteringIndicatorPoint = previewPoint
        }
        if focusExposureMode != .manual {
            meteringIndicatorTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) { meteringIndicatorPoint = nil }
            }
        }
    }

    private func meteringIndicator(at point: CGPoint, target: TapMeteringTarget) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                if target.includesFocus {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(.teal, lineWidth: 3)
                        .frame(width: 72, height: 72)
                }
                if target.includesExposure {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: target.includesFocus ? 20 : 34, weight: .bold))
                        .foregroundStyle(.yellow)
                        .padding(target.includesFocus ? 3 : 14)
                        .background(.black.opacity(0.55), in: Circle())
                }
            }
            .shadow(color: .black.opacity(0.7), radius: 5)
            .position(x: point.x * proxy.size.width, y: point.y * proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var meteringLockIndicators: some View {
        let capabilities = camera.cameraControlCapabilities
        if capabilities.isFocusLocked || capabilities.isExposureLocked || camera.isManualExposureEnabled {
            HStack(spacing: 6) {
                if capabilities.isFocusLocked {
                    Label("AF-L", systemImage: "viewfinder")
                        .accessibilityLabel("Focus locked")
                }
                if capabilities.isExposureLocked || camera.isManualExposureEnabled {
                    Label(camera.isManualExposureEnabled ? "M" : "AE-L", systemImage: "sun.max.fill")
                        .accessibilityLabel(camera.isManualExposureEnabled ? "Manual exposure" : "Exposure locked")
                }
            }
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.black.opacity(0.68), in: Capsule())
        }
    }

    private var assistedRecommendationCandidate: AssistedRecommendation? {
        guard autoAssistanceEnabled else { return nil }
        return AssistedRecommendationEngine().recommendation(
            measurements: camera.measurements,
            capabilities: camera.cameraControlCapabilities,
            shutterTimerSeconds: storedShutterTimerSeconds,
            recentCaptureCount: camera.recentCaptureCount
        )
    }

    private var activeAssistedRecommendation: AssistedRecommendation? {
        guard let candidate = assistedRecommendationCandidate,
              candidate.kind != dismissedAssistedRecommendation else { return nil }
        return candidate
    }

    @ViewBuilder
    private func assistedRecommendationCard(_ recommendation: AssistedRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(recommendation.goal, systemImage: "wand.and.stars")
                .font(.headline)
                .foregroundStyle(.teal)
            Text(recommendation.setting)
                .font(.title3.bold().monospacedDigit())
            Text(recommendation.reason)
                .font(.subheadline)
            Text("Tradeoff: \(recommendation.tradeoff)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Apply") { applyAssistedRecommendation(recommendation) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("applyAssistedRecommendation")
                Button("Dismiss") { dismissedAssistedRecommendation = recommendation.kind }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("dismissAssistedRecommendation")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("assistedRecommendationCard")
    }

    private func applyAssistedRecommendation(_ recommendation: AssistedRecommendation) {
        dismissedAssistedRecommendation = recommendation.kind
        switch recommendation.action {
        case .setExposureBias(let bias):
            camera.setExposureBias(bias)
        case .setShutterTimer(let seconds):
            storedShutterTimerSeconds = seconds
        case .lockFocusAndExposure:
            camera.setFocusExposureLocked(true)
        }
    }

    private func capabilityRow(_ title: String, supported: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Label(supported ? "Supported" : "Unavailable", systemImage: supported ? "checkmark.circle.fill" : "minus.circle")
                .font(.caption.bold())
                .foregroundStyle(supported ? .green : .secondary)
        }
    }

    private func shutterDurationLabel(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        if seconds >= 1 { return String(format: "%.1f s", seconds) }
        return "1/\(max(1, Int((1 / seconds).rounded()))) s"
    }

    private var voiceShutterCanListen: Bool {
        scenePhase == .active
            && camera.cameraReady
            && !camera.permissionDenied
            && camera.reviewImage == nil
            && !camera.isCapturing
            && !isBurstCapturing
            && shutterCountdownRemaining == nil
            && !showTutor
            && !showPoseChooser
            && !showLandscapeChooser
            && !showFoodChooser
            && examplePose == nil
            && landscapeExampleRecipe == nil
            && foodExampleRecipe == nil
            && sharedPhoto == nil
            && !showAppSettings
            && !showCameraControls
            && !showFullScreenReviewImage
            && !showingFolderImporter
    }

    private func syncVoiceShutterState() {
        guard voiceShutterCanListen else {
            let reason: String
            if scenePhase != .active {
                reason = "Paused while Dali is in the background"
            } else if camera.reviewImage != nil {
                reason = "Paused during photo review"
            } else if camera.isCapturing {
                reason = "Paused while taking the photo"
            } else if shutterCountdownRemaining != nil {
                reason = "Paused during the shutter countdown"
            } else if !camera.cameraReady || camera.permissionDenied {
                reason = "Paused until the camera is ready"
            } else {
                reason = "Paused while a menu is open"
            }
            voiceShutter.pauseListening(reason: reason)
            return
        }
        voiceShutter.resumeIfEnabled()
    }

    private var shutterCountdownBlocked: Bool {
        scenePhase != .active
            || camera.reviewImage != nil
            || showTutor
            || showPoseChooser
            || showLandscapeChooser
            || showFoodChooser
            || examplePose != nil
            || landscapeExampleRecipe != nil
            || foodExampleRecipe != nil
            || sharedPhoto != nil
            || showAppSettings
            || showCameraControls
            || showFullScreenReviewImage
            || showingFolderImporter
    }

    @MainActor
    @discardableResult
    private func requestPhotoCapture() -> Bool {
        guard shutterCountdownTask == nil, camera.canCapturePhoto else { return false }
        guard storedShutterTimerSeconds > 0 else { return camera.capturePhoto() }

        let delay = storedShutterTimerSeconds
        shutterCountdownTask = Task { @MainActor in
            for remaining in stride(from: delay, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                shutterCountdownRemaining = remaining
                camera.captureStatus = "Shutter in \(remaining) second\(remaining == 1 ? "" : "s")…"
                UIImpactFeedbackGenerator(style: remaining == 1 ? .heavy : .light).impactOccurred()
                if UIAccessibility.isVoiceOverRunning {
                    UIAccessibility.post(notification: .announcement, argument: "\(remaining)")
                }
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
            }

            guard !Task.isCancelled else { return }
            shutterCountdownTask = nil
            shutterCountdownRemaining = nil
            if !camera.capturePhoto() {
                camera.captureStatus = "Camera is not ready. Please try again."
            }
        }
        return true
    }

    private var isBurstCapturing: Bool {
        burstCaptureTask != nil
    }

    @MainActor
    private func handleShutterTap() {
        if suppressNextShutterTap {
            suppressNextShutterTap = false
            return
        }
        requestPhotoCapture()
    }

    @MainActor
    private func performShutterLongPress() {
        suppressNextShutterTap = true
        switch selectedShutterLongPressAction {
        case .burst:
            startBurstCapture()
        case .timer:
            requestPhotoCapture()
        case .disabled:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    @MainActor
    private func shutterPressingChanged(_ pressing: Bool) {
        guard !pressing else { return }
        stopBurstCapture()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            suppressNextShutterTap = false
        }
    }

    @MainActor
    private func startBurstCapture() {
        guard burstCaptureTask == nil, shutterCountdownTask == nil, camera.canCapturePhoto else { return }
        burstPhotoCount = 0
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        burstCaptureTask = Task { @MainActor in
            while !Task.isCancelled, burstPhotoCount < 20 {
                if camera.canCapturePhoto, camera.capturePhoto() {
                    burstPhotoCount += 1
                    camera.captureStatus = "Burst · \(burstPhotoCount)"
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

                do {
                    try await Task.sleep(for: .milliseconds(60))
                } catch {
                    return
                }
            }

            guard !Task.isCancelled else { return }
            burstCaptureTask = nil
            camera.captureStatus = "Burst complete · \(burstPhotoCount) photos"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    @MainActor
    private func stopBurstCapture() {
        guard let task = burstCaptureTask else { return }
        task.cancel()
        burstCaptureTask = nil
        if burstPhotoCount > 0 {
            camera.captureStatus = "Burst · \(burstPhotoCount) photo\(burstPhotoCount == 1 ? "" : "s")"
        }
    }

    @MainActor
    private func cancelShutterCountdown() {
        guard shutterCountdownTask != nil || shutterCountdownRemaining != nil else { return }
        shutterCountdownTask?.cancel()
        shutterCountdownTask = nil
        shutterCountdownRemaining = nil
        if camera.captureStatus?.hasPrefix("Shutter in ") == true {
            camera.captureStatus = nil
        }
    }

    private func loadStoredBeautifySettings() {
        let migratedLevel: Int
        if storedBeautifyLevelVersion < 1 {
            migratedLevel = Int((Double(max(0, min(10, storedBeautifyStrength))) / 2).rounded())
            storedBeautifyStrength = migratedLevel
            storedBeautifyLevelVersion = 1
        } else {
            migratedLevel = max(0, min(5, storedBeautifyStrength))
        }

        camera.beautifySettings = BeautifySettings(
            strength: migratedLevel,
            landscapeSkyEnabled: storedBeautifyLandscapeSkyEnabled,
            landscapeColorEnabled: storedBeautifyLandscapeColorEnabled,
            faceBrightnessEnabled: storedBeautifyFaceBrightnessEnabled,
            skinSmoothingEnabled: storedBeautifySkinSmoothingEnabled,
            blemishReductionEnabled: storedBeautifyBlemishReductionEnabled,
            eyeEnlargementEnabled: storedBeautifyEyeEnlargementEnabled,
            lipPlumpingEnabled: storedBeautifyLipPlumpingEnabled
        )
        camera.landscapePolishStrength = max(0, min(5, storedLandscapePolishStrength))
        camera.reviewTreatment = ReviewTreatment(rawValue: storedReviewTreatment) ?? .generalEnhance
    }

    private func loadStoredEnhanceSettings() {
        camera.enhanceSettings = EnhanceSettings(
            strength: max(0, min(5, storedEnhanceStrength)),
            autoToneEnabled: storedEnhanceAutoToneEnabled,
            warmthEnabled: storedEnhanceWarmthEnabled,
            vibranceEnabled: storedEnhanceVibranceEnabled,
            clarityEnabled: storedEnhanceClarityEnabled,
            noiseReductionEnabled: storedEnhanceNoiseReductionEnabled,
            subjectEmphasisEnabled: storedEnhanceSubjectEmphasisEnabled
        )
    }

    private func persistBeautifySettings() {
        storedBeautifyStrength = camera.beautifySettings.strength
        storedBeautifyLevelVersion = 1
        storedBeautifyLandscapeSkyEnabled = camera.beautifySettings.landscapeSkyEnabled
        storedBeautifyLandscapeColorEnabled = camera.beautifySettings.landscapeColorEnabled
        storedBeautifyFaceBrightnessEnabled = camera.beautifySettings.faceBrightnessEnabled
        storedBeautifySkinSmoothingEnabled = camera.beautifySettings.skinSmoothingEnabled
        storedBeautifyBlemishReductionEnabled = camera.beautifySettings.blemishReductionEnabled
        storedBeautifyEyeEnlargementEnabled = camera.beautifySettings.eyeEnlargementEnabled
        storedBeautifyLipPlumpingEnabled = camera.beautifySettings.lipPlumpingEnabled
        storedLandscapePolishStrength = camera.landscapePolishStrength
    }

    private func persistEnhanceSettings() {
        storedEnhanceStrength = camera.enhanceSettings.strength
        storedEnhanceAutoToneEnabled = camera.enhanceSettings.autoToneEnabled
        storedEnhanceWarmthEnabled = camera.enhanceSettings.warmthEnabled
        storedEnhanceVibranceEnabled = camera.enhanceSettings.vibranceEnabled
        storedEnhanceClarityEnabled = camera.enhanceSettings.clarityEnabled
        storedEnhanceNoiseReductionEnabled = camera.enhanceSettings.noiseReductionEnabled
        storedEnhanceSubjectEmphasisEnabled = camera.enhanceSettings.subjectEmphasisEnabled
    }

    private func reviewSlideshowView(original: UIImage) -> some View {
        GeometryReader { proxy in
            let processedImage = currentReviewDisplayImage(original: original)
            let image = reviewComparisonMode == .before ? original : processedImage
            let imageHeight = max(280, proxy.size.height * 0.52)

            ScrollView {
                VStack(spacing: 0) {
                    reviewSlideshowTopBar
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    reviewComparisonPicker
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)

                    if camera.debugEnabled {
                        posePackagePicker
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }

                    reviewImagePane(
                        image: image,
                        originalImage: original,
                        title: reviewVariantTitle,
                        subtitle: reviewImageSubtitle,
                        showOverlay: false,
                        showSplitComparison: reviewComparisonMode == .split
                    )
                    .frame(maxWidth: .infinity, minHeight: imageHeight, maxHeight: imageHeight)

                    VStack(spacing: 12) {
                        reviewActions(original: original)
                        Button {
                            returnToCameraMode()
                        } label: {
                            Label("Back to Camera", systemImage: "camera.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.teal)
                        .accessibilityIdentifier("backToCameraButton")
                        selectedTreatmentControls
                        if camera.hasUnsavedCapture { captureRecoveryControls }
                    }
                    .padding(12)
                    if camera.debugEnabled {
                        detailedAnalysisPanel
                            .frame(height: 420)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .background(Color.black)
    }

    private func returnToCameraMode() {
        reviewPhotos = []
        reviewPhotoIndex = 0
        reviewVariant = .original
        reviewComparisonMode = .before
        camera.clearStillPhoto()
        camera.start()
    }

    private var reviewSlideshowTopBar: some View {
        HStack(spacing: 8) {
            Button {
                returnToCameraMode()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "camera.viewfinder")
                    Text("Camera")
                        .font(.system(size: 9, weight: .bold))
                }
                .frame(width: 54, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(.teal, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Back to camera")

            Button {
                showPreviousReviewPhoto()
            } label: {
                Image(systemName: "chevron.left")
                    .accessibilityLabel("Previous photo")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canNavigateReviewPhotos ? .white : .white.opacity(0.32))
            .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
            .disabled(!canNavigateReviewPhotos)

            VStack(spacing: 2) {
                Text(reviewPhotoCountText)
                    .font(.caption.bold())
                    .foregroundStyle(.teal)
                    .lineLimit(1)
                Text(reviewStatusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Button {
                showNextReviewPhoto()
            } label: {
                Image(systemName: "chevron.right")
                    .accessibilityLabel("Next photo")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canNavigateReviewPhotos ? .white : .white.opacity(0.32))
            .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
            .disabled(!canNavigateReviewPhotos)

            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 20, matching: .images) {
                Image(systemName: "photo.on.rectangle.angled")
                    .accessibilityLabel("Choose photos from library")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(.teal, in: RoundedRectangle(cornerRadius: 8))

            if camera.debugEnabled {
                Button {
                    showingFolderImporter = true
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(.teal, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .font(.headline)
        .background(.black)
    }

    private var reviewComparisonPicker: some View {
        Picker("Photo comparison", selection: $reviewComparisonMode) {
            ForEach(ReviewComparisonMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("reviewComparisonPicker")
    }

    @ViewBuilder
    private var selectedTreatmentControls: some View {
        switch camera.reviewTreatment {
        case .generalEnhance:
            enhanceControls
        case .portraitPolish, .landscapePolish:
            beautifyControls
        }
    }

    private var posePackagePicker: some View {
        Picker("Pose package", selection: $camera.selectedPosePackage) {
            ForEach(PosePackageID.allCases) { package in
                Text(package.title).tag(package)
            }
        }
        .pickerStyle(.segmented)
    }

    private func reviewImagePane(
        image: UIImage,
        originalImage: UIImage,
        title: String,
        subtitle: String?,
        showOverlay: Bool,
        showSplitComparison: Bool
    ) -> some View {
        ZStack(alignment: .topLeading) {
            Color.black

            GeometryReader { proxy in
                ZStack {
                    Image(uiImage: showSplitComparison ? originalImage : image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if showSplitComparison {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .mask(alignment: .trailing) {
                                Rectangle()
                                    .frame(width: proxy.size.width / 2)
                            }

                        Rectangle()
                            .fill(.white.opacity(0.9))
                            .frame(width: 2)

                        HStack {
                            Text("BEFORE")
                            Spacer()
                            Text("AFTER")
                        }
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    startReviewComparison = showSplitComparison
                    showFullScreenReviewImage = true
                }
                .gesture(
                    DragGesture(minimumDistance: 36)
                        .onEnded { value in
                            guard canNavigateReviewPhotos else { return }
                            if value.translation.width <= -60 {
                                showNextReviewPhoto()
                            } else if value.translation.width >= 60 {
                                showPreviousReviewPhoto()
                            }
                        }
                )
                .accessibilityHint(canNavigateReviewPhotos ? "Swipe left or right for another photo" : "Double-tap for full screen")
                .accessibilityIdentifier("reviewImagePane")
            }

            if showOverlay {
                OverlayView(
                    advice: camera.advice,
                    measurements: camera.measurements,
                    issues: camera.issues,
                    debugEnabled: true,
                    contentAspectRatio: image.size.width / max(1, image.size.height)
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.72))
                if let subtitle {
                    Text(subtitle)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
            .padding(.top, 10)
            .padding(.leading, 12)

            Button {
                showFullScreenReviewImage = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .accessibilityLabel("Open full-screen photo")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
            .padding(.top, 10)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .topTrailing)
        }
    }

    private var availableReviewVariants: [ReviewVariant] {
        var variants: [ReviewVariant] = [.original]
        if camera.reframedImage != nil {
            variants.append(.reframed)
        }
        if camera.leveledImage != nil {
            variants.append(.leveled)
        }
        if camera.enhancedImage != nil {
            variants.append(.enhanced)
        }
        if camera.beautifiedImage != nil {
            variants.append(.beautified)
        }
        if camera.tiltedImage != nil {
            variants.append(.tilted)
        }
        return variants
    }

    private var canNavigateReviewPhotos: Bool {
        reviewPhotos.count > 1
    }

    private var reviewPhotoCountText: String {
        if reviewPhotos.isEmpty {
            return "Captured photo"
        }
        return "Photo \(reviewPhotoIndex + 1) of \(reviewPhotos.count)"
    }

    private var reviewStatusText: String {
        camera.captureStatus ?? "Analysis"
    }

    private var reviewImageSubtitle: String? {
        guard !reviewPhotos.isEmpty else { return "Current capture" }
        return reviewPhotos[reviewPhotoIndex].title
    }

    private var reviewVariantTitle: String {
        reviewVariant == .beautified ? camera.reviewTreatment.title : reviewVariant.title
    }

    private func currentReviewDisplayImage(original: UIImage) -> UIImage {
        switch reviewVariant {
        case .original:
            return original
        case .reframed:
            return camera.reframedImage ?? original
        case .leveled:
            return camera.leveledImage ?? original
        case .enhanced:
            return camera.enhancedImage ?? original
        case .beautified:
            return camera.beautifiedImage ?? original
        case .tilted:
            return camera.tiltedImage ?? original
        }
    }

    private func loadReviewPhotos(from items: [PhotosPickerItem]) async {
        var loadedPhotos: [ReviewPhoto] = []

        for (index, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self),
               UIImage(data: data) != nil {
                loadedPhotos.append(ReviewPhoto(data: data, title: "Selected \(index + 1)"))
            }
        }

        if let first = loadedPhotos.first, let data = first.data {
            camera.stop()
            reviewPhotos = loadedPhotos
            reviewPhotoIndex = 0
            reviewVariant = .original
            reviewComparisonMode = .before
            camera.analyzeStillPhoto(data: data)
        } else {
            camera.captureStatus = "Could not load photos"
        }
    }

    private func loadReviewPhotos(fromFolder url: URL) async {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let imageURLs = folderImageURLs(in: url)
        var loadedPhotos: [ReviewPhoto] = []

        for imageURL in imageURLs.prefix(50) {
            if let data = try? Data(contentsOf: imageURL),
               UIImage(data: data) != nil {
                loadedPhotos.append(ReviewPhoto(data: data, title: imageURL.lastPathComponent))
            }
        }

        if let first = loadedPhotos.first, let data = first.data {
            camera.stop()
            reviewPhotos = loadedPhotos
            reviewPhotoIndex = 0
            reviewVariant = .original
            reviewComparisonMode = .before
            camera.analyzeStillPhoto(data: data)
        } else {
            camera.captureStatus = "No images found in folder"
        }
    }

    private func folderImageURLs(in folderURL: URL) -> [URL] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { url in
                let values = try? url.resourceValues(forKeys: keys)
                guard values?.isRegularFile == true else { return false }
                return supportedImageExtensions.contains(url.pathExtension.lowercased())
            }
            .sorted { first, second in
                first.lastPathComponent.localizedStandardCompare(second.lastPathComponent) == .orderedAscending
            }
    }

    private func showPreviousReviewPhoto() {
        guard canNavigateReviewPhotos else { return }
        reviewPhotoIndex = (reviewPhotoIndex - 1 + reviewPhotos.count) % reviewPhotos.count
        analyzeCurrentReviewPhoto()
    }

    private func openSystemPhotoLibrary() {
        guard !isLoadingPhotoLibrary else { return }
        isLoadingPhotoLibrary = true
        camera.captureStatus = "Opening Photos…"

        Task { @MainActor in
            let status = await photoLibraryAuthorizationStatus()
            guard status == .authorized || status == .limited else {
                isLoadingPhotoLibrary = false
                camera.captureStatus = "Photos access is needed. Enable it in Settings, or use the photo picker."
                if camera.latestPhotoThumbnail != nil { openCapturedPhotoHistory() }
                return
            }

            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let assets = PHAsset.fetchAssets(with: .image, options: options)
            var libraryPhotos: [ReviewPhoto] = []
            libraryPhotos.reserveCapacity(assets.count)
            assets.enumerateObjects { asset, index, _ in
                let title = asset.creationDate?.formatted(date: .abbreviated, time: .shortened)
                    ?? "Library photo \(index + 1)"
                libraryPhotos.append(
                    ReviewPhoto(assetIdentifier: asset.localIdentifier, title: title)
                )
            }

            guard !libraryPhotos.isEmpty else {
                isLoadingPhotoLibrary = false
                camera.captureStatus = status == .limited
                    ? "No selected Photos are available. Add photos in Settings or use the photo picker."
                    : "No photos found in the library."
                if camera.latestPhotoThumbnail != nil { openCapturedPhotoHistory() }
                return
            }

            camera.stop()
            reviewPhotos = libraryPhotos
            reviewPhotoIndex = 0
            reviewVariant = .original
            reviewComparisonMode = .before
            isLoadingPhotoLibrary = false
            analyzeCurrentReviewPhoto()
        }
    }

    private func photoLibraryAuthorizationStatus() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else { return current }
        return await Self.requestPhotoLibraryAuthorizationFromSystem()
    }

    /// Photos invokes this completion on an arbitrary queue. Building the
    /// callback outside MainActor isolation avoids a Swift 6 executor trap.
    nonisolated private static func requestPhotoLibraryAuthorizationFromSystem() async -> PHAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func photoData(for assetIdentifier: String) async -> Data? {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = results.firstObject else { return nil }
        return await Self.requestPhotoDataFromSystem(for: asset)
    }

    /// PHImageManager also owns its callback queue, so keep its completion
    /// nonisolated and return to the caller's actor only after it completes.
    nonisolated private static func requestPhotoDataFromSystem(for asset: PHAsset) async -> Data? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.version = .current

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func openCapturedPhotoHistory() {
        let capturedPhotos = camera.capturedPhotoHistory()
        guard let latest = capturedPhotos.first else {
            camera.captureStatus = "The captured photo could not be loaded."
            return
        }

        reviewPhotos = capturedPhotos.map { photo in
            ReviewPhoto(
                data: photo.data,
                title: photo.capturedAt.formatted(date: .abbreviated, time: .shortened)
            )
        }
        reviewPhotoIndex = 0
        reviewVariant = .original
        reviewComparisonMode = .before
        camera.analyzeStillPhoto(data: latest.data)
    }

    private func showNextReviewPhoto() {
        guard canNavigateReviewPhotos else { return }
        reviewPhotoIndex = (reviewPhotoIndex + 1) % reviewPhotos.count
        analyzeCurrentReviewPhoto()
    }

    private func analyzeCurrentReviewPhoto() {
        guard reviewPhotos.indices.contains(reviewPhotoIndex) else { return }
        let index = reviewPhotoIndex
        let loadID = UUID()
        reviewPhotoLoadID = loadID
        reviewVariant = .original
        reviewComparisonMode = .before
        if let data = reviewPhotos[index].data {
            camera.analyzeStillPhoto(data: data)
            return
        }

        guard let assetIdentifier = reviewPhotos[index].assetIdentifier else {
            camera.captureStatus = "This photo could not be loaded."
            return
        }

        camera.captureStatus = "Loading photo…"
        Task { @MainActor in
            guard let data = await photoData(for: assetIdentifier), UIImage(data: data) != nil else {
                guard reviewPhotoLoadID == loadID else { return }
                camera.captureStatus = "This photo could not be loaded from Photos."
                return
            }
            guard reviewPhotoLoadID == loadID,
                  reviewPhotos.indices.contains(index),
                  reviewPhotoIndex == index else { return }
            camera.analyzeStillPhoto(data: data)
        }
    }

    private var beautifyStrengthBinding: Binding<Double> {
        Binding(
            get: { Double(camera.beautifySettings.strength) },
            set: {
                let level = Int($0.rounded())
                camera.setBeautifyStrength(level)
                reviewVariant = activeProcessedReviewVariant
                reviewComparisonMode = .after
            }
        )
    }

    private var landscapePolishStrengthBinding: Binding<Double> {
        Binding(
            get: { Double(camera.landscapePolishStrength) },
            set: {
                camera.setLandscapePolishStrength(Int($0.rounded()))
                reviewVariant = activeProcessedReviewVariant
                reviewComparisonMode = .after
            }
        )
    }

    private var activePolishStrengthBinding: Binding<Double> {
        camera.reviewTreatment == .landscapePolish
            ? landscapePolishStrengthBinding
            : beautifyStrengthBinding
    }

    private var activePolishStrength: Int {
        camera.reviewTreatment == .landscapePolish
            ? camera.landscapePolishStrength
            : camera.beautifySettings.strength
    }

    private var activePolishLevelName: String {
        var settings = camera.beautifySettings
        settings.strength = activePolishStrength
        return settings.levelName
    }

    private var landscapePolishLevelName: String {
        var settings = camera.beautifySettings
        settings.strength = camera.landscapePolishStrength
        return settings.levelName
    }

    private var enhanceStrengthBinding: Binding<Double> {
        Binding(
            get: { Double(camera.enhanceSettings.strength) },
            set: {
                camera.setEnhanceStrength(Int($0.rounded()))
                reviewVariant = activeProcessedReviewVariant
                reviewComparisonMode = .after
            }
        )
    }

    private var activeProcessedReviewVariant: ReviewVariant {
        switch camera.reviewTreatment {
        case .generalEnhance:
            return camera.enhancedImage == nil ? .original : .enhanced
        case .portraitPolish, .landscapePolish:
            return camera.beautifiedImage == nil ? .original : .beautified
        }
    }

    private var enhanceControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    reviewTreatmentMenu
                    Text(enhanceStatusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Text("\(camera.enhanceSettings.strength) · \(camera.enhanceSettings.levelName)")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 36)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            Slider(value: enhanceStrengthBinding, in: 0...5, step: 1)
                .accessibilityLabel("Enhance level")
                .accessibilityValue("\(camera.enhanceSettings.levelName), level \(camera.enhanceSettings.strength) of 5")
                .tint(.orange)

            HStack(spacing: 8) {
                Button {
                    camera.setEnhanceStrength(0)
                    reviewVariant = activeProcessedReviewVariant
                    reviewComparisonMode = .after
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.caption.bold())
                        .frame(minHeight: 44)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                Spacer()

                Label("Updates automatically", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }

            if camera.debugEnabled {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(enhanceDebugChips, id: \.self) { chip in
                        metricChip(chip)
                    }
                }
            }
        }
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private var enhanceStatusText: String {
        guard camera.enhanceSettings.strength > 0 else {
            return "Original image unchanged"
        }
        return "\(camera.enhanceSettings.levelName) · Whole-photo enhancement"
    }

    private var beautifyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.teal)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    reviewTreatmentMenu
                    Text(beautifyStatusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Text("\(activePolishStrength) · \(activePolishLevelName)")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 36)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            Slider(value: activePolishStrengthBinding, in: 0...5, step: 1)
                .accessibilityLabel("\(camera.reviewTreatment.title) level")
                .accessibilityValue("\(activePolishLevelName), level \(activePolishStrength) of 5")
                .tint(.teal)

            HStack(spacing: 8) {
                Button {
                    if camera.reviewTreatment == .landscapePolish {
                        camera.setLandscapePolishStrength(0)
                    } else {
                        camera.setBeautifyStrength(0)
                    }
                    reviewVariant = activeProcessedReviewVariant
                    reviewComparisonMode = .after
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.caption.bold())
                        .frame(minHeight: 44)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                Spacer()

                Label("Updates automatically", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }

            if camera.debugEnabled {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(beautifyDebugChips, id: \.self) { chip in
                        metricChip(chip)
                    }
                }
            }
        }
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private var beautifyStatusText: String {
        guard activePolishStrength > 0 else {
            return "Original image unchanged"
        }

        guard let result = camera.beautifyResult else {
            return "Ready"
        }

        switch camera.reviewTreatment {
        case .portraitPolish:
            return result.faceDetected
                ? "\(activePolishLevelName) · Face-aware portrait polish"
                : "No face detected"
        case .landscapePolish:
            if result.skyApplied && result.landscapeColorApplied {
                return "\(activePolishLevelName) · Rich color + sky detail"
            }
            if result.skyApplied {
                return "\(activePolishLevelName) · Blue sky + cloud detail"
            }
            return "\(activePolishLevelName) · Rich landscape color"
        case .generalEnhance:
            return "General enhancement selected"
        }
    }

    private var reviewTreatmentMenu: some View {
        Menu {
            ForEach(ReviewTreatment.allCases) { treatment in
                Button {
                    camera.setReviewTreatment(treatment)
                    reviewVariant = activeProcessedReviewVariant
                    reviewComparisonMode = .after
                } label: {
                    if camera.reviewTreatment == treatment {
                        Label(treatment.title, systemImage: "checkmark")
                    } else {
                        Text(treatment.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(camera.reviewTreatment.title)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.bold())
            }
            .font(.headline.bold())
            .foregroundStyle(.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Photo treatment")
        .accessibilityValue(camera.reviewTreatment.title)
        .accessibilityHint("Choose Portrait Polish, Landscape Polish, or General Enhance")
        .accessibilityIdentifier("reviewTreatmentMenu")
    }

    private var detailedAnalysisPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                analysisSection(title: "Pose Package") {
                    HStack(spacing: 8) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.teal)
                            .frame(width: 28, height: 28)
                        Text(camera.selectedPosePackage.title)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(10)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }

                analysisSection(title: "Enhance") {
                    enhanceControls
                }

                analysisSection(title: "Beautify") {
                    beautifyControls
                }

                analysisSection(title: "Issues") {
                    if camera.issues.isEmpty {
                        Text("No issues detected")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        VStack(spacing: 9) {
                            ForEach(Array(camera.issues.enumerated()), id: \.offset) { _, issue in
                                analysisIssueRow(issue)
                            }
                        }
                    }
                }

                analysisSection(title: "Metrics") {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(reviewMetricChips, id: \.self) { chip in
                            metricChip(chip)
                        }
                    }
                }

                analysisSection(title: "Frame Debug") {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(reviewDebugChips, id: \.self) { chip in
                            metricChip(chip)
                        }
                    }
                }

                analysisSection(title: "Pose Points") {
                    if camera.measurements.poseKeypoints.isEmpty {
                        Text("No pose points")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(camera.measurements.poseKeypoints.keys.sorted()), id: \.self) { key in
                                if let point = camera.measurements.poseKeypoints[key] {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(shortJointName(key))
                                            .font(.caption.monospaced().weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.82))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                        Spacer(minLength: 8)
                                        Text("\(format(Double(point.point.x))), \(format(Double(point.point.y))) · \(format(Double(point.confidence)))")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.white.opacity(0.58))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .background(Color(red: 0.08, green: 0.1, blue: 0.12))
    }

    private func analysisSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.bold())
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.58))
            content()
        }
    }

    private func analysisIssueRow(_ issue: PhotoIssue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(issue.recipient)
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(toneColor(issue.tone), in: RoundedRectangle(cornerRadius: 6))

                Text(issue.instruction)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Text("\(issue.type) · conf \(format(issue.confidence)) · priority \(format(issue.priority))")
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if !issue.reasonData.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(reasonChips(for: issue), id: \.self) { chip in
                        metricChip(chip)
                    }
                }
            }
        }
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(toneColor(issue.tone).opacity(0.55), lineWidth: 1)
        }
    }

    private func metricChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced().weight(.semibold))
            .foregroundStyle(.white.opacity(0.86))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }

    private var noSuggestionPage: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.teal)
                Text("No change suggested")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
        }
    }

    private var tutorCard: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TabView(selection: $tutorialPage) {
                    ForEach(CameraTutorialStep.allCases) { step in
                        tutorialPageView(step)
                            .tag(step.rawValue)
                            .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 7) {
                    ForEach(CameraTutorialStep.allCases) { step in
                        Capsule()
                            .fill(step.rawValue == tutorialPage ? Color.teal : Color.secondary.opacity(0.28))
                            .frame(width: step.rawValue == tutorialPage ? 24 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: tutorialPage)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tutorial step \(tutorialPage + 1) of \(CameraTutorialStep.allCases.count)")

                HStack(spacing: 12) {
                    if tutorialPage > 0 {
                        Button("Back") {
                            withAnimation { tutorialPage -= 1 }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Button(tutorialPage == CameraTutorialStep.allCases.count - 1 ? "Start taking photos" : "Next") {
                        if tutorialPage == CameraTutorialStep.allCases.count - 1 {
                            showTutor = false
                        } else {
                            withAnimation { tutorialPage += 1 }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(
                        tutorialPage == CameraTutorialStep.allCases.count - 1
                            ? "tutorialStartButton"
                            : "tutorialNextButton"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .navigationTitle("Quick Camera Tutorial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Skip") { showTutor = false }
                }
            }
        }
    }

    private func tutorialPageView(_ step: CameraTutorialStep) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 4)

                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [step.accent.opacity(0.32), Color.black.opacity(0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(step.accent.opacity(0.7), lineWidth: 1)

                    tutorialIllustration(step)
                }
                .frame(maxWidth: 420, minHeight: 220, maxHeight: 270)
                .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(step.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(step.detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 8) {
                    ForEach(step.tips, id: \.self) { tip in
                        Label(tip, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(step.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(step.rawValue + 1). \(step.title). \(step.detail)")
    }

    @ViewBuilder
    private func tutorialIllustration(_ step: CameraTutorialStep) -> some View {
        switch step {
        case .posture:
            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    tutorialPackageTile("person.crop.rectangle.stack", label: "Portrait", color: .teal)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.72))
                    tutorialPackageTile("figure.stand", label: "Posture", color: .yellow)
                }
                HStack(spacing: 9) {
                    Label("Choose package", systemImage: "square.grid.2x2")
                    Image(systemName: "chevron.right")
                    Label("Choose pose", systemImage: "photo")
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
            }
        case .landscape:
            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    tutorialPackageTile("mountain.2", label: "Landscape", color: .blue)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.72))
                    tutorialPackageTile("rectangle.3.group", label: "Composition", color: .green)
                }
                HStack(spacing: 9) {
                    Label("Choose scene", systemImage: "square.grid.2x2")
                    Image(systemName: "chevron.right")
                    Label("Frame photo", systemImage: "viewfinder")
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
            }
        case .coach:
            VStack(spacing: 18) {
                HStack(spacing: 24) {
                    tutorialStatusLight(color: .green, label: "Ready")
                    tutorialStatusLight(color: .orange, label: "Adjust")
                }
                Image(systemName: step.symbol)
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.white)
            }
        case .style:
            HStack(spacing: 28) {
                tutorialFeatureSymbol("camera.filters", label: "Filters", color: .teal)
                tutorialFeatureSymbol("wand.and.stars", label: "Beautifier", color: .yellow)
            }
        case .capture:
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(.white).frame(width: 90, height: 90)
                    Circle().stroke(.black.opacity(0.4), lineWidth: 4).frame(width: 72, height: 72)
                }
                HStack(spacing: 20) {
                    Label("Timer", systemImage: "timer")
                    Label("Voice", systemImage: "waveform")
                    Label("Burst", systemImage: "square.stack.3d.up.fill")
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
            }
        case .review:
            HStack(spacing: 18) {
                Image(systemName: "chevron.left")
                Image(systemName: step.symbol)
                    .font(.system(size: 72, weight: .light))
                Image(systemName: "chevron.right")
            }
            .font(.title.bold())
            .foregroundStyle(.white)
        case .choose:
            ZStack {
                Image(systemName: step.symbol)
                    .font(.system(size: 122, weight: .thin))
                    .foregroundStyle(.white)
                Image(systemName: "person.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.yellow)
            }
        }
    }

    private func tutorialStatusLight(color: Color, label: String) -> some View {
        VStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .shadow(color: color.opacity(0.8), radius: 8)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }

    private func tutorialFeatureSymbol(_ symbol: String, label: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 58, weight: .light))
                .foregroundStyle(color)
            Text(label)
                .font(.headline)
                .foregroundStyle(.white)
        }
    }

    private func tutorialPackageTile(_ symbol: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .light))
            Text(label)
                .font(.caption.bold())
        }
        .foregroundStyle(color)
        .frame(width: 112, height: 96)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.75), lineWidth: 1)
        }
    }

    private var situationGuidanceCard: some View {
        let guidance = situationGuidance

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: guidance.symbol)
                        .accessibilityHidden(true)
                    Text(shootingMode == .auto ? "Auto · \(activeSituation.title)" : activeSituation.title)
                }
                Spacer(minLength: 8)
                coachingStatusLED(guidance.tone)
            }
            .font(.caption.bold())
            .textCase(.uppercase)
            .foregroundStyle(coachingColor(guidance.tone))
            Text(guidance.title)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(guidance.instruction)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(coachingColor(guidance.tone).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(coachingColor(guidance.tone).opacity(0.9), lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("situationGuidanceCard")
        .padding(.bottom, 8)
    }

    private var situationGuidance: CoachingGuidance {
        switch activeSituation {
        case .portrait, .personScene:
            let detail: String
            switch camera.advice.recipient {
            case "Photographer": detail = "Adjust the camera position or framing."
            case "Subject": detail = "Ask the subject to make this adjustment."
            default: detail = "Dali is analyzing the live camera view."
            }
            return CoachingGuidance(
                title: camera.advice.instruction,
                instruction: detail,
                symbol: camera.advice.directionSymbol ?? activeSituation.symbol,
                tone: camera.advice.tone
            )
        case .group:
            guard let group = camera.measurements.groupAnalysis else {
                return CoachingGuidance("Bring everyone into frame", "Step back until every person is visible.", "person.3", .warning)
            }
            if group.faceVisibilityRatio < 0.8 {
                return CoachingGuidance("Make every face visible", "Ask the group to adjust so no face is blocked.", "person.3", .warning)
            }
            if group.edgeCrowdingScore > 0.35 {
                return CoachingGuidance("Leave space at the edges", "Step back slightly so nobody is cut off.", "arrow.down.right.and.arrow.up.left", .warning)
            }
            if let spacing = group.spacingScore, spacing > 1.8 {
                return CoachingGuidance("Bring the group closer", "Reduce the gaps between people.", "arrow.left.and.right", .warning)
            }
            return CoachingGuidance("Group looks ready", "Keep every face visible and take the photo.", "checkmark.circle", .ready)
        case .action:
            guard let person = camera.measurements.personBox else {
                return CoachingGuidance("Find the moving subject", "Frame the subject before following the action.", "figure.run", .warning)
            }
            if person.rect.minX < 0.06 || person.rect.maxX > 0.94 {
                return CoachingGuidance("Give the subject more room", "Keep space around them so movement stays in frame.", "arrow.left.and.right", .warning)
            }
            if camera.measurements.cameraMotion > 0.5 {
                return CoachingGuidance("Track more smoothly", "Follow the subject steadily before pressing the shutter.", "viewfinder", .warning)
            }
            if camera.measurements.subjectMotion >= 0.16 {
                return CoachingGuidance("Keep following the action", "Track the subject and take the photo as the moment develops.", "figure.run", .waiting)
            }
            return CoachingGuidance("Action frame looks ready", "Leave room for movement and take the photo at the peak moment.", "checkmark.circle", .ready)
        case .closeUp:
            if camera.measurements.cameraMotion > 0.22 {
                return CoachingGuidance("Steady the close-up", "Hold the phone still so the detail stays sharp.", "viewfinder", .warning)
            }
            if let object = camera.measurements.salientObjectBox {
                let area = object.rect.width * object.rect.height
                if area < 0.18 {
                    return CoachingGuidance("Move closer to the detail", "Fill more of the frame while keeping the subject sharp.", "plus.magnifyingglass", .warning)
                }
                if area > 0.72 || object.rect.minX < 0.025 || object.rect.maxX > 0.975 {
                    return CoachingGuidance("Give the detail more space", "Step back slightly so its edges are not cut off.", "minus.magnifyingglass", .warning)
                }
            } else {
                return CoachingGuidance("Choose one clear detail", "Center the object you want Dali to evaluate.", "viewfinder", .warning)
            }
            if abs(camera.measurements.cameraRollDegrees) > 3 {
                return CoachingGuidance("Align the subject", "Rotate the phone slightly to straighten the composition.", "level", .warning)
            }
            return CoachingGuidance("Close-up looks ready", "Keep the background simple and take the photo.", "checkmark.circle", .ready)
        case .food:
            if camera.measurements.cameraMotion > 0.22 {
                return CoachingGuidance("Steady the food photo", "Brace the phone before refining the composition.", "camera.aperture", .warning)
            }
            guard camera.measurements.salientObjectBox != nil else {
                return CoachingGuidance("Choose the hero dish", "Make one plate or detail the clear center of attention.", "fork.knife", .warning)
            }
            return CoachingGuidance("Food frame looks ready", "Keep the frame edges clean and take the photo.", "checkmark.circle", .ready)
        case .landscape:
            return landscapeGuidance
        case .auto:
            return CoachingGuidance("Checking the scene", "Hold the camera steady while Dali chooses a situation.", "wand.and.stars", .waiting)
        }
    }

    private var adviceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(camera.advice.recipient)
                .font(.caption.bold())
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.72))
            Text(camera.advice.instruction)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(toneColor(camera.advice.tone).opacity(0.7), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .padding(.bottom, 8)
    }

    private var landscapeCompositionChooser: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
                        chosenLandscapeRecipe = nil
                        showLandscapeChooser = false
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "leaf.fill")
                                .font(.title2)
                                .foregroundStyle(.teal)
                                .frame(width: 46, height: 46)
                                .background(.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Natural")
                                    .font(.headline)
                                Text("No composition recipe; horizon guidance stays on")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if chosenLandscapeRecipe == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.teal)
                            }
                        }
                        .padding(12)
                        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(chosenLandscapeRecipe == nil ? .teal : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("naturalLandscapeOption")

                    if let selectedLandscapePackage {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(selectedLandscapePackage.title, systemImage: selectedLandscapePackage.symbol)
                                .font(.title2.bold())
                            Text(selectedLandscapePackage.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 12)], spacing: 12) {
                            ForEach(LandscapeCompositionRecipe.allCases.filter { $0.package == selectedLandscapePackage }) { recipe in
                                landscapeRecipeCard(for: recipe)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose a landscape package")
                                .font(.title2.bold())
                            Text("Start with the scene, then choose a composition.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(LandscapeCompositionPackageID.allCases) { package in
                            landscapePackageCard(for: package)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(selectedLandscapePackage?.title ?? "Landscape packages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedLandscapePackage != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            selectedLandscapePackage = nil
                        } label: {
                            Label("Packages", systemImage: "chevron.left")
                        }
                        .accessibilityIdentifier("backToLandscapePackages")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showLandscapeChooser = false }
                }
            }
            .accessibilityIdentifier("landscapeCompositionChooser")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func landscapePackageCard(for package: LandscapeCompositionPackageID) -> some View {
        let recipes = LandscapeCompositionRecipe.allCases.filter { $0.package == package }

        return Button {
            selectedLandscapePackage = package
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    ForEach(Array(recipes.prefix(3))) { recipe in
                        Image(recipe.exampleAssetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 38, height: 86)
                            .clipped()
                    }
                }
                .frame(width: 124, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 4) {
                    Label(package.title, systemImage: package.symbol)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(package.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    Text("\(recipes.count) compositions")
                        .font(.caption.bold())
                        .foregroundStyle(.teal)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("landscapePackage_\(package.id)")
    }

    private func landscapeRecipeCard(for recipe: LandscapeCompositionRecipe) -> some View {
        Button {
            chosenLandscapeRecipe = recipe
            selectedAngle = recipe.recommendedCameraAngle
            showLandscapeChooser = false
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Image(recipe.exampleAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(recipe.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Label(recipe.recommendedCameraAngle.title, systemImage: recipe.recommendedCameraAngle.symbol)
                    .font(.caption2.bold())
                    .foregroundStyle(.teal)
                    .lineLimit(1)
                Label(recipe.recommendedLight.title, systemImage: recipe.recommendedLight.symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(8)
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(chosenLandscapeRecipe == recipe ? .teal : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(recipe.title). Recommended angle: \(recipe.recommendedCameraAngle.title). Best light: \(recipe.recommendedLight.title).")
        .accessibilityIdentifier("landscapeOption_\(recipe.id)")
    }

    private var activeLandscapeCompositionCard: some View {
        Group {
            if let recipe = chosenLandscapeRecipe {
                HStack(spacing: 12) {
                    Image(recipe.exampleAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 86, height: 96)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(recipe.title)
                            .font(.caption.bold())
                            .textCase(.uppercase)
                            .foregroundStyle(.teal)
                        Text(recipe.instruction)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Label("Recommended angle: \(recipe.recommendedCameraAngle.title)", systemImage: recipe.recommendedCameraAngle.symbol)
                            .font(.caption.bold())
                            .foregroundStyle(.teal)
                        Label("Best light: \(recipe.recommendedLight.title)", systemImage: recipe.recommendedLight.symbol)
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.teal.opacity(0.65), lineWidth: 1)
                }
                .contentShape(Rectangle())
                .onTapGesture { landscapeExampleRecipe = recipe }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Landscape composition, \(recipe.title). Tap for the full example and safety note.")
                .accessibilityAction(named: "Show composition example") { landscapeExampleRecipe = recipe }
            }
        }
        .accessibilityIdentifier("activeLandscapeCard")
    }

    private func landscapeCompositionExampleSheet(for recipe: LandscapeCompositionRecipe) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(recipe.exampleAssetName)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Example photo for \(recipe.title)")
                        .accessibilityIdentifier("landscapeExamplePhoto")

                    Text(recipe.instruction)
                        .font(.title3.bold())

                    Label("Recommended camera angle: \(recipe.recommendedCameraAngle.title)", systemImage: recipe.recommendedCameraAngle.symbol)
                        .font(.headline)
                        .foregroundStyle(.teal)

                    VStack(alignment: .leading, spacing: 5) {
                        Label("Best light: \(recipe.recommendedLight.title)", systemImage: recipe.recommendedLight.symbol)
                            .font(.headline)
                        Text(recipe.recommendedLight.instruction)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Label("Stay safe", systemImage: "exclamationmark.shield.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Text(recipe.safetyNote)
                    }
                    .padding(12)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("landscapeSafetyNote")
                }
                .padding()
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { landscapeExampleRecipe = nil }
                }
            }
        }
    }

    private var foodCompositionChooser: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
                        chosenFoodRecipe = nil
                        showFoodChooser = false
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "leaf.fill")
                                .font(.title2)
                                .foregroundStyle(.teal)
                                .frame(width: 46, height: 46)
                                .background(.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Natural")
                                    .font(.headline)
                                Text("No food recipe; live stability and framing guidance stays on")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if chosenFoodRecipe == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.teal)
                            }
                        }
                        .padding(12)
                        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(chosenFoodRecipe == nil ? .teal : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("naturalFoodOption")

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Food", systemImage: "fork.knife")
                            .font(.title2.bold())
                        Text("Plates, flat lays, table stories, ingredients, texture, and action details")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 12)], spacing: 12) {
                        ForEach(FoodCompositionRecipe.allCases) { recipe in
                            foodRecipeCard(for: recipe)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Food package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showFoodChooser = false }
                }
            }
            .accessibilityIdentifier("foodCompositionChooser")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func foodRecipeCard(for recipe: FoodCompositionRecipe) -> some View {
        Button {
            chosenFoodRecipe = recipe
            selectedAngle = recipe.recommendedCameraAngle
            showFoodChooser = false
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Image(recipe.exampleAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(recipe.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Label(recipe.recommendedCameraAngle.title, systemImage: recipe.recommendedCameraAngle.symbol)
                    .font(.caption2.bold())
                    .foregroundStyle(.teal)
                    .lineLimit(1)
                Label(recipe.recommendedLight.title, systemImage: recipe.recommendedLight.symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(8)
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(chosenFoodRecipe == recipe ? .teal : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(recipe.title). Recommended angle: \(recipe.recommendedCameraAngle.title). Best light: \(recipe.recommendedLight.title).")
        .accessibilityIdentifier("foodOption_\(recipe.id)")
    }

    private var activeFoodCompositionCard: some View {
        Group {
            if let recipe = chosenFoodRecipe {
                HStack(spacing: 12) {
                    Image(recipe.exampleAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 86, height: 96)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(recipe.title)
                            .font(.caption.bold())
                            .textCase(.uppercase)
                            .foregroundStyle(.teal)
                        Text(recipe.instruction)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Label("Recommended angle: \(recipe.recommendedCameraAngle.title)", systemImage: recipe.recommendedCameraAngle.symbol)
                            .font(.caption.bold())
                            .foregroundStyle(.teal)
                        Label("Best light: \(recipe.recommendedLight.title)", systemImage: recipe.recommendedLight.symbol)
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.teal.opacity(0.65), lineWidth: 1)
                }
                .contentShape(Rectangle())
                .onTapGesture { foodExampleRecipe = recipe }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Food composition, \(recipe.title). Tap for the full example and safety note.")
                .accessibilityAction(named: "Show food example") { foodExampleRecipe = recipe }
            }
        }
        .accessibilityIdentifier("activeFoodCard")
    }

    private func foodCompositionExampleSheet(for recipe: FoodCompositionRecipe) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(recipe.exampleAssetName)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Example food photo for \(recipe.title)")
                        .accessibilityIdentifier("foodExamplePhoto")

                    Text(recipe.instruction)
                        .font(.title3.bold())

                    Label("Recommended camera angle: \(recipe.recommendedCameraAngle.title)", systemImage: recipe.recommendedCameraAngle.symbol)
                        .font(.headline)
                        .foregroundStyle(.teal)

                    VStack(alignment: .leading, spacing: 5) {
                        Label("Best light: \(recipe.recommendedLight.title)", systemImage: recipe.recommendedLight.symbol)
                            .font(.headline)
                        Text(recipe.recommendedLight.instruction)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Label("Work safely", systemImage: "exclamationmark.shield.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Text(recipe.safetyNote)
                    }
                    .padding(12)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("foodSafetyNote")
                }
                .padding()
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { foodExampleRecipe = nil }
                }
            }
        }
    }

    private var landscapeGuidanceCard: some View {
        let guidance = landscapeGuidance

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: guidance.symbol)
                        .accessibilityHidden(true)
                    Text(shootingMode == .auto ? "Auto · Landscape" : "Landscape guidance")
                }
                Spacer(minLength: 8)
                coachingStatusLED(guidance.tone)
            }
            .font(.caption.bold())
            .textCase(.uppercase)
            .foregroundStyle(coachingColor(guidance.tone))
            Text(guidance.title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(guidance.instruction)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(coachingColor(guidance.tone).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(coachingColor(guidance.tone).opacity(0.9), lineWidth: 2)
        }
        .accessibilityIdentifier("landscapeGuidanceCard")
    }

    private var landscapeGuidance: CoachingGuidance {
        let horizonTilt = camera.measurements.horizonAngleDegrees ?? camera.measurements.cameraRollDegrees
        if abs(horizonTilt) > 2.5 {
            return CoachingGuidance(
                "Level the horizon",
                horizonTilt > 0 ? "Rotate the phone slightly counterclockwise." : "Rotate the phone slightly clockwise.",
                "level",
                .warning
            )
        }
        if camera.measurements.horizonConfidence > 0.2 {
            return CoachingGuidance(
                "Horizon looks level",
                "Place the horizon away from the center, then include a foreground element for depth.",
                "checkmark.circle",
                .ready
            )
        }
        return CoachingGuidance(
            "Build depth in the scene",
            "Include a nearby subject, a middle distance, and the background before taking the photo.",
            "mountain.2",
            .warning
        )
    }

    private var guidedControls: some View {
        HStack(spacing: 8) {
            Text(camera.guidedSession.isComplete
                 ? "Sequence finished"
                 : "Step \(camera.guidedSession.stepIndex + 1) of \(camera.guidedSession.steps.count)")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.72))

            Spacer()

            Button("Natural") {
                selectPosture(nil)
            }

            if camera.guidedSession.currentStep != nil {
                Button("Next") { camera.advanceGuidance() }
                    .disabled(camera.guidedAction == nil)
            }
        }
        .font(.caption.bold())
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.teal)
        .padding(8)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 8)
    }

    private var inlinePosePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pose & instruction")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPoseChooser = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("Close poses and angles")
            }

            Picker("Collection", selection: $guideCollection) {
                ForEach(GuidedPoseCollectionID.allCases) { package in
                    Text(package.title).tag(package)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: guideCollection) { _, collection in
                if chosenGuidePose?.package != collection {
                    chosenGuidePose = GuidedPose.allCases.first { $0.package == collection }
                }
            }

            HStack {
                if let index = selectedGuidePoseIndex {
                    Text("Pose \(index + 1) of \(availableGuidePoses.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Label("Recommended: \(selectedAngle.title)", systemImage: selectedAngle.symbol)
                    .font(.caption.bold())
                    .foregroundStyle(.teal)
                    .accessibilityLabel("Recommended angle, \(selectedAngle.title)")
            }

            if let pose = chosenGuidePose {
                HStack(spacing: 12) {
                    Button {
                        selectAdjacentGuidePose(offset: -1)
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.teal)
                    .accessibilityLabel("Previous pose")

                    HStack(spacing: 10) {
                        PosePhotoThumbnail(pose: pose)
                            .frame(width: 82, height: 98)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(pose.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(.teal)
                            Text(pose.cues[0])
                                .font(.headline)
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                selectAdjacentGuidePose(offset: value.translation.width < 0 ? 1 : -1)
                            }
                    )
                    .accessibilityElement(children: .combine)

                    Button {
                        selectAdjacentGuidePose(offset: 1)
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.teal)
                    .accessibilityLabel("Next pose")
                }
                Text("Swipe the pose, or use the arrow buttons.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let position = chosenCameraPosition,
                      let step = position.steps(moveRight: guideMoveRight).first {
                Label(step.instruction, systemImage: step.action.symbol)
                    .font(.headline)
                    .foregroundStyle(.white)
            } else {
                Text("Choose a pose to see it here while you take pictures.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            if chosenCameraPosition == .side {
                Toggle("Move to your right", isOn: $guideMoveRight)
                    .foregroundStyle(.white)
                    .tint(.teal)
            }

            HStack {
                Button("Use Natural") {
                    chosenGuidePose = nil
                    chosenCameraPosition = nil
                    camera.beginGuidance(pose: nil, position: nil)
                    showPoseChooser = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Start") {
                    camera.beginGuidance(pose: chosenGuidePose, position: chosenCameraPosition, moveRight: guideMoveRight)
                    showPoseChooser = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(chosenGuidePose == nil && chosenCameraPosition == nil)
            }
            .controlSize(.large)
            .tint(.teal)
        }
        .padding(10)
        .background(.black.opacity(0.84), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.teal.opacity(0.65), lineWidth: 1)
        }
    }

    private var availableGuidePoses: [GuidedPose] {
        GuidedPose.allCases.filter { $0.package == guideCollection }
    }

    private var selectedGuidePoseIndex: Int? {
        guard let chosenGuidePose else { return nil }
        return availableGuidePoses.firstIndex(of: chosenGuidePose)
    }

    private func selectAdjacentGuidePose(offset: Int) {
        guard !availableGuidePoses.isEmpty else { return }
        let currentIndex = selectedGuidePoseIndex ?? 0
        let nextIndex = (currentIndex + offset + availableGuidePoses.count) % availableGuidePoses.count
        withAnimation(.easeInOut(duration: 0.18)) {
            selectPosture(availableGuidePoses[nextIndex])
        }
    }

    private func selectAdjacentExamplePose(from pose: GuidedPose, offset: Int) {
        let poses = GuidedPose.allCases.filter { $0.package == pose.package }
        guard let currentIndex = poses.firstIndex(of: pose), !poses.isEmpty else { return }
        let nextIndex = (currentIndex + offset + poses.count) % poses.count
        let nextPose = poses[nextIndex]
        withAnimation(.easeInOut(duration: 0.18)) {
            selectPosture(nextPose)
            examplePose = nextPose
        }
    }

    private var activePoseCard: some View {
        HStack(spacing: 12) {
            if let pose = camera.guidedSession.pose {
                PosePhotoThumbnail(pose: pose)
                    .frame(width: 86, height: 96)
            }

            VStack(alignment: .leading, spacing: 5) {
                if let pose = camera.guidedSession.pose {
                    HStack(spacing: 8) {
                        Text(pose.title)
                            .font(.caption.bold())
                            .textCase(.uppercase)
                        Spacer(minLength: 8)
                        coachingStatusLED(camera.advice.tone)
                    }
                    .foregroundStyle(coachingColor(camera.advice.tone))

                    Text("\(pose.category.title) · \(pose.setting.title)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.65))

                    Text(pose.instruction)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    let angle = pose.recommendedCameraAngle
                    if camera.guidedSession.position == angle.guidedPosition {
                        Label("Recommended angle: \(angle.title)", systemImage: angle.symbol)
                            .font(.caption.bold())
                            .foregroundStyle(.teal)
                    }

                    Label("Lighting: \(pose.recommendedLighting.title)", systemImage: pose.recommendedLighting.symbol)
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(coachingColor(camera.advice.tone).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(coachingColor(camera.advice.tone).opacity(0.9), lineWidth: 2)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height),
                          abs(value.translation.width) > 44 else { return }
                    selectAdjacentGuidePose(offset: value.translation.width < 0 ? 1 : -1)
                }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                examplePose = camera.guidedSession.pose
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Posture, \(camera.guidedSession.pose?.title ?? "Natural"). Tap for a photo example. Swipe left or right for another posture.")
        .accessibilityAction(named: "Show photo example") {
            examplePose = camera.guidedSession.pose
        }
        .accessibilityIdentifier("activePostureCard")
    }

    private func postureExampleSheet(for pose: GuidedPose) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack(alignment: .bottom) {
                        Image(pose.exampleAssetName)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        Label("Swipe for another posture", systemImage: "arrow.left.and.right")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(.white)
                            .background(.black.opacity(0.68), in: Capsule())
                            .padding(.bottom, 12)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 24)
                            .onEnded { value in
                                guard abs(value.translation.width) > abs(value.translation.height),
                                      abs(value.translation.width) > 44 else { return }
                                selectAdjacentExamplePose(from: pose, offset: value.translation.width < 0 ? 1 : -1)
                            }
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Photo example of \(pose.title). Swipe left or right for another posture.")
                    .accessibilityAction(named: "Previous posture") {
                        selectAdjacentExamplePose(from: pose, offset: -1)
                    }
                    .accessibilityAction(named: "Next posture") {
                        selectAdjacentExamplePose(from: pose, offset: 1)
                    }
                    .accessibilityIdentifier("postureExamplePhoto")

                    Text(pose.instruction)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 14) {
                        Label(pose.category.title, systemImage: pose.category.symbol)
                        Label(pose.setting.title, systemImage: pose.setting.symbol)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.72))

                    Label("Recommended camera angle: \(pose.recommendedCameraAngle.title)", systemImage: pose.recommendedCameraAngle.symbol)
                        .font(.subheadline.bold())
                        .foregroundStyle(.teal)

                    VStack(alignment: .leading, spacing: 5) {
                        Label("Recommended lighting: \(pose.recommendedLighting.title)", systemImage: pose.recommendedLighting.symbol)
                            .font(.subheadline.bold())
                            .foregroundStyle(.yellow)
                        Text(pose.recommendedLighting.instruction)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
                .padding()
            }
            .background(Color.black)
            .foregroundStyle(.white)
            .navigationTitle(pose.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { examplePose = nil }
                }
            }
            .accessibilityIdentifier("postureExampleSheet")
        }
        .presentationDragIndicator(.visible)
    }

    private var reviewAnalysisCard: some View {
        let summary = lightingReviewSummary

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Image(systemName: summary.symbolName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(toneColor(summary.tone))
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.title)
                        .font(.caption.bold())
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.68))
                    Text(summary.detail)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 8)

                Text(lightingValueText)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.72)
            }

            if !camera.issues.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(Array(camera.issues.prefix(5).enumerated()), id: \.offset) { _, issue in
                        Text(issueChipText(issue))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(toneColor(issue.tone).opacity(0.22), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            Divider()
                .background(.white.opacity(0.18))

            VStack(alignment: .leading, spacing: 7) {
                Text(poseReviewTitle)
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.62))

                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(reviewMetricChips, id: \.self) { chip in
                        Text(chip)
                            .font(.caption.monospaced().weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(12)
        .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(toneColor(summary.tone).opacity(0.68), lineWidth: 1)
        }
        .padding(.bottom, 12)
    }

    private var lightingReviewSummary: LightingReviewSummary {
        if camera.measurements.faceBox == nil {
            return LightingReviewSummary(
                title: "Lighting unavailable",
                detail: "No face detected for backlight analysis",
                symbolName: "person.crop.circle.badge.exclamationmark",
                tone: .waiting
            )
        }

        if let issue = camera.issues.first(where: { $0.type == "subject_backlit" }) {
            return LightingReviewSummary(
                title: "Backlight detected",
                detail: issue.instruction,
                symbolName: "sun.max.fill",
                tone: issue.tone
            )
        }

        if let issue = camera.issues.first(where: { $0.type == "face_underexposed" }) {
            return LightingReviewSummary(
                title: "Face underexposed",
                detail: issue.instruction,
                symbolName: "light.min",
                tone: issue.tone
            )
        }

        return LightingReviewSummary(
            title: "Lighting OK",
            detail: "Face and background balance look acceptable",
            symbolName: "checkmark.circle.fill",
            tone: .ready
        )
    }

    private var lightingValueText: String {
        let face = camera.measurements.faceLuminance.map { String(format: "%.0f", $0) } ?? "--"
        let background = camera.measurements.backgroundLuminance.map { String(format: "%.0f", $0) } ?? "--"
        return "face \(face)\nbg \(background)"
    }

    private func poseMetricChips(for pose: PoseAnalysis) -> [String] {
        [
            "conf \(format(pose.confidence))",
            "pts \(pose.visibleKeypointCount)",
            pose.wristToFaceDistance.map { "hand-face \(format($0))" },
            "arms \(format(pose.armVisibilityScore))",
            pose.bodySquarenessScore.map { "square \(format($0))" },
            pose.bodyProfileScore.map { "profile \(format($0))" },
            pose.armsFlatAgainstBodyScore.map { "flat \(format($0))" },
            pose.minWristEdgeDistance.map { "hand-edge \(format($0))" },
            pose.shouldersHighScore.map { "shoulders \(format($0))" },
            pose.shoulderLineAngleDegrees.map { "shoulder \(format($0)) deg" },
            pose.torsoAngleDegrees.map { "torso \(format($0)) deg" }
        ].compactMap { $0 }
    }

    private var poseReviewTitle: String {
        if camera.measurements.poseAnalysis == nil {
            return "Pose unavailable"
        }

        if camera.issues.contains(where: isPostureIssue) {
            return "Pose findings"
        }

        return "Pose OK"
    }

    private var reviewMetricChips: [String] {
        var chips: [String] = []

        if let pose = camera.measurements.poseAnalysis {
            chips.append(contentsOf: poseMetricChips(for: pose))
        } else {
            chips.append("no skeleton")
        }

        if let group = camera.measurements.groupAnalysis {
            chips.append(contentsOf: groupMetricChips(for: group))
        }

        if let face = camera.measurements.faceAnalysis {
            chips.append(contentsOf: faceMetricChips(for: face))
        } else {
            chips.append("no face landmarks")
        }

        return chips
    }

    private func groupMetricChips(for group: GroupAnalysis) -> [String] {
        [
            "people \(group.peopleCount)",
            "faces \(group.faceCount)",
            "face-vis \(format(group.faceVisibilityRatio))",
            "edge \(format(group.edgeCrowdingScore))",
            group.spacingScore.map { "spacing \(format($0))" }
        ].compactMap { $0 }
    }

    private var beautifyDebugChips: [String] {
        guard let result = camera.beautifyResult else {
            return ["beautify ready"]
        }

        var chips = [
            "strength \(camera.beautifySettings.strength)",
            "face \(result.faceDetected ? "yes" : "no")",
            "person \(result.personDetected ? "yes" : "no")",
            "landscape \(result.landscapeApplied ? "yes" : "no")",
            "sky \(result.skyApplied ? "yes" : "no")"
        ]

        chips.append(contentsOf: result.debugValues
            .sorted { $0.key < $1.key }
            .map { "\($0.key) \(format($0.value))" })

        return chips
    }

    private var enhanceDebugChips: [String] {
        guard let result = camera.enhanceResult else {
            return ["enhance ready"]
        }

        var chips = ["level \(camera.enhanceSettings.strength)"]
        chips.append(contentsOf: result.debugValues
            .sorted { $0.key < $1.key }
            .map { "\($0.key) \(format($0.value))" })
        return chips
    }

    private var reviewDebugChips: [String] {
        var chips = [
            "package \(camera.selectedPosePackage.title)",
            "roll \(format(camera.measurements.cameraRollDegrees)) deg",
            "motion \(format(camera.measurements.cameraMotion))",
            "stable \(camera.measurements.cameraStable ? "yes" : "no")",
            "open \(format(camera.measurements.skyOrOpenAreaRatio))",
            "pose pts \(camera.measurements.poseKeypoints.count)",
            "people \(camera.measurements.groupAnalysis?.peopleCount ?? (camera.measurements.personBox == nil ? 0 : 1))",
            "faces \(camera.measurements.groupAnalysis?.faceCount ?? (camera.measurements.faceBox == nil ? 0 : 1))",
            "face \(camera.measurements.faceLuminance.map { format($0) } ?? "--")",
            "bg \(camera.measurements.backgroundLuminance.map { format($0) } ?? "--")"
        ]

        if let person = camera.measurements.personBox {
            chips.append("person \(format(Double(person.rect.width)))x\(format(Double(person.rect.height)))")
        } else {
            chips.append("person none")
        }

        if let face = camera.measurements.faceBox {
            chips.append("face box \(format(Double(face.rect.width)))x\(format(Double(face.rect.height)))")
        } else {
            chips.append("face box none")
        }

        if let horizon = camera.measurements.horizonAngleDegrees {
            chips.append("horizon \(format(horizon)) deg")
            chips.append("horizon conf \(format(camera.measurements.horizonConfidence))")
        } else {
            chips.append("horizon none")
        }

        if let reframeSuggestion = camera.reframeSuggestion {
            chips.append("crop \(reframeSuggestion.reason)")
            chips.append("crop conf \(format(reframeSuggestion.confidence))")
        } else {
            chips.append("crop none")
        }

        return chips
    }

    private func faceMetricChips(for face: FaceAnalysis) -> [String] {
        [
            "face-conf \(format(face.confidence))",
            "lm \(face.landmarkPointCount)",
            "eyes \(format(face.eyeVisibilityScore))",
            "occ \(format(face.occlusionScore))",
            face.yawEstimate.map { "yaw \(format($0))" },
            face.pitchEstimate.map { "pitch \(format($0))" }
        ].compactMap { $0 }
    }

    private func issueChipText(_ issue: PhotoIssue) -> String {
        guard let firstReason = issue.reasonData.sorted(by: { $0.key < $1.key }).first else {
            return "\(issue.type): \(issue.instruction)"
        }

        return "\(issue.type): \(issue.instruction) \(format(firstReason.value))"
    }

    private func reasonChips(for issue: PhotoIssue) -> [String] {
        issue.reasonData
            .sorted { $0.key < $1.key }
            .map { "\($0.key) \(format($0.value))" }
    }

    private func shortJointName(_ key: String) -> String {
        key
            .replacingOccurrences(of: "VNHumanBodyPoseObservationJointName(_rawValue: ", with: "")
            .replacingOccurrences(of: "VNHumanBodyPoseObservationJointName(rawValue: ", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "_joint", with: "")
    }

    private func isPostureIssue(_ issue: PhotoIssue) -> Bool {
        [
            "hand_near_face",
            "arm_hidden",
            "body_too_square",
            "body_too_profile",
            "arms_flat_against_body",
            "hand_cut_off",
            "shoulders_high",
            "face_occluded",
            "eyes_occluded",
            "face_too_profile",
            "face_turned_away",
            "chin_too_high",
            "chin_too_low",
            "group_faces_missing",
            "group_edge_crowded",
            "group_spacing_wide"
        ].contains(issue.type)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private var controls: some View {
        let thumbnail = camera.latestPhotoThumbnail

        return HStack {
            Button {
                openSystemPhotoLibrary()
            } label: {
                ZStack {
                    PhotoLibraryButtonLabel(thumbnail: thumbnail)
                    if isLoadingPhotoLibrary {
                        ProgressView()
                            .tint(.white)
                            .padding(6)
                            .background(.black.opacity(0.65), in: Circle())
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoadingPhotoLibrary)
            .accessibilityLabel("Open photo library")
            .accessibilityHint("Opens accessible Photos with swipe navigation")
            .accessibilityIdentifier("photoLibraryButton")

            Spacer()

            Button {
                handleShutterTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 76, height: 76)
                    Circle()
                        .stroke(.black.opacity(0.35), lineWidth: 3)
                        .frame(width: 60, height: 60)
                    if storedShutterTimerSeconds > 0 {
                        Text("\(storedShutterTimerSeconds)")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(.black)
                    }
                }
                .accessibilityLabel(
                    storedShutterTimerSeconds > 0
                        ? "Take photo, \(storedShutterTimerSeconds) second timer"
                        : "Take photo"
                )
                .accessibilityHint("Double-tap for one photo. Hold for \(selectedShutterLongPressAction.title.lowercased()).")
            }
            .buttonStyle(.plain)
            .onLongPressGesture(
                minimumDuration: 0.4,
                maximumDistance: 50,
                pressing: shutterPressingChanged,
                perform: performShutterLongPress
            )
            .disabled((!camera.canCapturePhoto && !isBurstCapturing) || shutterCountdownTask != nil)

            Spacer()

            Button {
                showCameraControls = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 2) {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 20, weight: .bold))
                        Text("Controls")
                            .font(.system(size: 9, weight: .bold))
                    }
                    if activeAssistedRecommendation != nil {
                        Circle()
                            .fill(.orange)
                            .frame(width: 9, height: 9)
                            .accessibilityHidden(true)
                    }
                }
                .foregroundStyle(focusExposureMode == .manual ? .teal : .white)
                .frame(width: 52, height: 52)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Camera controls")
            .accessibilityIdentifier("cameraControlButton")
        }
        .font(.headline)
    }

    private var permissionView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
            Text("Camera permission needed")
                .font(.title2.bold())
            Text("Enable camera access in Settings to test Dali coaching.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.72))
            Button("Open Settings") { openSettings() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
        .foregroundStyle(.white)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
        .padding(24)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private var captureRecoveryControls: some View {
        VStack(spacing: 8) {
            Text("Your original has not been saved to Photos.")
                .font(.subheadline.bold())
            HStack {
                Button("Retry save") { camera.retryCaptureSave() }
                Button("Share original") {
                    if let image = camera.latestPhotoThumbnail { sharedPhoto = SharedPhoto(image: image) }
                }
            }
            HStack {
                Button("Settings") { openSettings() }
                Button("Discard…", role: .destructive) { showDiscardConfirmation = true }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .foregroundStyle(.white)
        .padding(10)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
        .disabled(camera.isSaving)
    }

    private func reviewActions(original: UIImage) -> some View {
        VStack(spacing: 10) {
            if let status = camera.exportStatus {
                Text(status).font(.subheadline).foregroundStyle(.white)
            }
            ViewThatFits(in: .horizontal) {
                HStack { reviewActionButtons(original: original) }
                VStack { reviewActionButtons(original: original) }
            }
            if camera.canRetryExport {
                Button("Retry saving copy") { camera.retryExport() }
                Button("Open Settings") { openSettings() }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.teal)
    }

    @ViewBuilder
    private func reviewActionButtons(original: UIImage) -> some View {
        Button("Compare") {
            startReviewComparison = true
            showFullScreenReviewImage = true
        }
        .disabled(camera.isAnalyzingPhoto || reviewVariant == .original)
        Button("Save a copy") { camera.saveCopy(reviewOutputImage(original: original)) }
            .disabled(camera.isSaving || camera.isAnalyzingPhoto)
        Button("Share") { sharedPhoto = SharedPhoto(image: reviewOutputImage(original: original)) }
            .disabled(camera.isAnalyzingPhoto)
    }

    private func reviewOutputImage(original: UIImage) -> UIImage {
        reviewComparisonMode == .before ? original : currentReviewDisplayImage(original: original)
    }

    private var floatingDebugPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug")
                .font(.caption.bold())
                .foregroundStyle(.teal)
                .textCase(.uppercase)
            Text("roll \(camera.measurements.cameraRollDegrees, specifier: "%.1f") deg")
            Text("motion \(camera.measurements.cameraMotion, specifier: "%.2f") stable \(camera.measurements.cameraStable ? "yes" : "no")")
            Text("horizon \(camera.measurements.horizonAngleDegrees ?? 999, specifier: "%.1f") deg conf \(camera.measurements.horizonConfidence, specifier: "%.2f")")
            Text("open \(camera.measurements.skyOrOpenAreaRatio, specifier: "%.2f") pose \(camera.measurements.poseKeypoints.count)")
            Text("face \(camera.measurements.faceLuminance ?? -1, specifier: "%.0f") bg \(camera.measurements.backgroundLuminance ?? -1, specifier: "%.0f")")
            Text(camera.issues.isEmpty ? "issues none" : "issues \(camera.issues.map(\.type).joined(separator: ", "))")
                .lineLimit(4)
            if let logURL = camera.sessionLogURL {
                ShareLink(item: logURL) {
                    Label("Share Log", systemImage: "square.and.arrow.up")
                        .font(.caption.bold())
                        .frame(minHeight: 32)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(.teal, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .font(.caption.monospaced())
        .foregroundStyle(.white)
        .padding(10)
        .frame(maxWidth: 330, alignment: .leading)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 78)
        .padding(.trailing, 16)
        .zIndex(20)
    }

    private func toneColor(_ tone: AdviceTone) -> Color {
        switch tone {
        case .waiting:
            return .yellow
        case .ready:
            return .green
        case .warning:
            return .orange
        case .danger:
            return .red
        }
    }

    private func coachingColor(_ tone: AdviceTone) -> Color {
        switch tone {
        case .ready: return .green
        case .warning, .danger: return .orange
        case .waiting: return .yellow
        }
    }

    private func coachingStatusLED(_ tone: AdviceTone) -> some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.62))
                .frame(width: 24, height: 24)
            Circle()
                .fill(coachingColor(tone))
                .frame(width: 14, height: 14)
                .overlay { Circle().stroke(.white.opacity(0.9), lineWidth: 1.5) }
                .shadow(color: coachingColor(tone).opacity(0.95), radius: 5)
        }
        .accessibilityElement()
        .accessibilityLabel(tone.coachingStatusTitle)
    }
}

private struct CoachingGuidance {
    let title: String
    let instruction: String
    let symbol: String
    let tone: AdviceTone

    init(_ title: String, _ instruction: String, _ symbol: String, _ tone: AdviceTone) {
        self.title = title
        self.instruction = instruction
        self.symbol = symbol
        self.tone = tone
    }

    init(title: String, instruction: String, symbol: String, tone: AdviceTone) {
        self.title = title
        self.instruction = instruction
        self.symbol = symbol
        self.tone = tone
    }
}

private struct ReviewPhoto: Identifiable {
    let id = UUID()
    var data: Data?
    let assetIdentifier: String?
    let title: String

    init(data: Data, title: String) {
        self.data = data
        assetIdentifier = nil
        self.title = title
    }

    init(assetIdentifier: String, title: String) {
        data = nil
        self.assetIdentifier = assetIdentifier
        self.title = title
    }
}

private struct PosePhotoThumbnail: View {
    let pose: GuidedPose

    var body: some View {
        Image(pose.exampleAssetName)
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            }
            .accessibilityLabel("Photo example of \(pose.title)")
            .accessibilityIdentifier("activePostureThumbnail")
    }
}

private struct SharedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct PhotoShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct PhotoLibraryButtonLabel: View {
    let thumbnail: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.teal)

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.82), lineWidth: 2)
                    }
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: 52, height: 52)
        .accessibilityLabel("Choose photo")
    }
}

private struct ZoomableReviewImageView: View {
    let image: UIImage
    let originalImage: UIImage
    let title: String
    let subtitle: String?
    let startComparing: Bool
    @Binding var isPresented: Bool

    @State private var scale = 1.0
    @State private var lastScale = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var compareMode = false
    @State private var comparePosition = 0.5

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                zoomableImageArea(size: proxy.size)

                VStack {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.caption.bold())
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.72))
                            if let subtitle {
                                Text(subtitle)
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                        }

                        Spacer()

                        Button {
                            compareMode.toggle()
                            resetZoom()
                        } label: {
                            Image(systemName: compareMode ? "rectangle.split.1x2.fill" : "rectangle.split.1x2")
                                .accessibilityLabel(compareMode ? "Show selected photo" : "Compare with original")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))

                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .accessibilityLabel("Close photo")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                    Spacer()
                }

                VStack {
                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            resetZoom()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.caption.bold())
                                .frame(minHeight: 38)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))

                        Text("\(scale, specifier: "%.1f")x")
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(minWidth: 48, minHeight: 38)
                            .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))

                        if compareMode {
                            Slider(value: $comparePosition, in: 0.04...0.96)
                                .frame(maxWidth: 160)
                                .accessibilityLabel("Comparison split")
                            Text("\(title) | Original")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(minHeight: 38)
                                .padding(.horizontal, 10)
                                .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.bottom, 18)
                }
            }
        }
        .onAppear { compareMode = startComparing }
    }

    private func zoomableImageArea(size: CGSize) -> some View {
        ZStack {
            if compareMode {
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(width: size.width, height: size.height)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(width: size.width, height: size.height)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: size.width * comparePosition)
                    }

                Rectangle()
                    .fill(.white.opacity(0.82))
                    .frame(width: 2)
                    .offset(x: size.width * comparePosition - size.width / 2)
                    .gesture(compareGesture(width: size.width))
            } else {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(width: size.width, height: size.height)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo zoom")
        .accessibilityValue(Text("\(scale, specifier: "%.1f") times"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: scale = min(6, scale + 0.5)
            case .decrement: scale = max(1, scale - 0.5)
            @unknown default: break
            }
            lastScale = scale
            if scale <= 1.01 { resetZoom() }
        }
        .gesture(compareMode ? nil : zoomGesture)
        .simultaneousGesture(compareMode ? nil : panGesture)
        .onTapGesture(count: 2) {
            resetZoom()
        }
    }

    private func compareGesture(width: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                comparePosition = min(0.96, max(0.04, value.location.x / max(1, width)))
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(6, max(1, lastScale * value))
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 {
                    resetZoom()
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}

private let supportedImageExtensions = [
    "jpg",
    "jpeg",
    "png",
    "heic",
    "heif"
]

private enum ReviewComparisonMode: String, CaseIterable, Identifiable {
    case before
    case after
    case split

    var id: String { rawValue }

    var title: String {
        switch self {
        case .before: return "Before"
        case .after: return "After"
        case .split: return "Split"
        }
    }
}

private enum ReviewVariant: Hashable {
    case original
    case reframed
    case leveled
    case enhanced
    case beautified
    case tilted

    var title: String {
        switch self {
        case .original:
            return "Original"
        case .reframed:
            return "Reframed"
        case .leveled:
            return "Leveled"
        case .enhanced:
            return "Enhanced"
        case .beautified:
            return "Polished"
        case .tilted:
            return "Tilt Test"
        }
    }

}

private struct LightingReviewSummary {
    let title: String
    let detail: String
    let symbolName: String
    let tone: AdviceTone
}

private struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height
        } + CGFloat(max(0, rows.count - 1)) * lineSpacing

        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [FlowRow] {
        guard maxWidth > 0 else { return [] }

        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if nextWidth > maxWidth, !currentItems.isEmpty {
                rows.append(FlowRow(items: currentItems, height: currentHeight))
                currentItems = [FlowItem(index: index, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(FlowItem(index: index, size: size))
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(FlowRow(items: currentItems, height: currentHeight))
        }

        return rows
    }
}

private struct FlowRow {
    let items: [FlowItem]
    let height: CGFloat
}

private struct FlowItem {
    let index: Int
    let size: CGSize
}
