import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @StateObject private var camera = CameraModel()
    @StateObject private var voiceShutter = VoiceShutterController()
    @AppStorage("hasSeenDaliTutor") private var hasSeenDaliTutor = false
    @AppStorage("beautifyStrength") private var storedBeautifyStrength = 0
    @AppStorage("beautifyFaceBrightnessEnabled") private var storedBeautifyFaceBrightnessEnabled = true
    @AppStorage("beautifySkinSmoothingEnabled") private var storedBeautifySkinSmoothingEnabled = true
    @AppStorage("beautifyWarmthEnabled") private var storedBeautifyWarmthEnabled = true
    @AppStorage("beautifyClarityEnabled") private var storedBeautifyClarityEnabled = true
    @AppStorage("beautifySubjectEmphasisEnabled") private var storedBeautifySubjectEmphasisEnabled = true
    @State private var showTutor = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingFolderImporter = false
    @State private var showConfiguration = false
    @State private var showCameraControls = false
    @State private var cameraControlMode: CameraControlMode = .auto
    @State private var reviewPhotos: [ReviewPhoto] = []
    @State private var reviewPhotoIndex = 0
    @State private var reviewVariant: ReviewVariant = .original
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
    @State private var guideCollection: GuidedPoseCollectionID = .masculine
    @State private var selectedPosePackage: GuidedPoseCollectionID?
    @State private var chosenGuidePose: GuidedPose?
    @State private var examplePose: GuidedPose?
    @State private var chosenLandscapeRecipe: LandscapeCompositionRecipe?
    @State private var landscapeExampleRecipe: LandscapeCompositionRecipe?
    @State private var selectedLandscapePackage: LandscapeCompositionPackageID?
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
            voiceShutter.onTakePhoto = { camera.capturePhoto() }
            loadStoredBeautifySettings()
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
                if camera.reviewImage == nil { voiceShutter.resumeIfEnabled() }
            } else if phase == .background {
                camera.stop()
                voiceShutter.pauseListening()
            }
        }
        .onChange(of: camera.reviewImage) { _, image in
            if image == nil && scenePhase == .active && !showTutor {
                voiceShutter.resumeIfEnabled()
            } else {
                voiceShutter.pauseListening()
            }
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
        .sheet(item: $examplePose) { pose in
            postureExampleSheet(for: pose)
        }
        .sheet(item: $landscapeExampleRecipe) { recipe in
            landscapeCompositionExampleSheet(for: recipe)
        }
        .sheet(isPresented: $showTutor) { tutorCard }
        .onChange(of: showTutor) { _, showing in
            if showing {
                camera.stop()
                voiceShutter.pauseListening()
            } else {
                camera.start()
                if camera.reviewImage == nil { voiceShutter.resumeIfEnabled() }
            }
        }
        .onChange(of: shootingMode) { _, _ in
            showPoseChooser = false
            showLandscapeChooser = false
            if !activeSituation.supportsPoseGuidance { camera.beginGuidance(pose: nil, position: nil) }
        }
        .onChange(of: activeSituation) { _, situation in
            guard let firstAngle = situation.angleChoices.first else { return }
            selectedAngle = firstAngle
            chosenGuidePose = nil
            chosenCameraPosition = nil
            showPoseChooser = false
            showLandscapeChooser = false
            if situation != .landscape { chosenLandscapeRecipe = nil }
            camera.beginGuidance(pose: nil, position: nil)
        }
        .onChange(of: camera.measurements.timestamp) { _, _ in
            guard coachingEnabled, shootingMode == .auto,
                  !camera.isCapturing, !camera.guidedSession.isActive else { return }
            automaticSituation = situationClassifier.update(with: camera.measurements)
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
                  !showTutor, !showPoseChooser, !showLandscapeChooser, !showConfiguration else { return }
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
        .onChange(of: camera.beautifySettings) { _, _ in
            persistBeautifySettings()
            camera.refreshBeautify()
        }
        .onChange(of: availableReviewVariants) { _, variants in
            if !variants.contains(reviewVariant) { reviewVariant = .original }
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
            camera.stop()
            voiceShutter.pauseListening()
        }
        .sheet(isPresented: $showConfiguration) {
            configurationSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCameraControls) {
            cameraControlSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showFullScreenReviewImage, onDismiss: { startReviewComparison = false }) {
            if let reviewImage = camera.reviewImage {
                ZoomableReviewImageView(
                    image: currentReviewDisplayImage(original: reviewImage),
                    originalImage: reviewImage,
                    title: reviewVariant.title,
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
        let image = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 180, y: 180, width: 240, height: 440))
        }
        guard let data = image.pngData() else { return false }
        camera.analyzeStillPhoto(data: data)
        return true
        #else
        return false
        #endif
    }

    private var viewfinder: some View {
        ZStack {
            CameraPreview(session: camera.session, mirrored: camera.isFrontCamera, onRotationChange: camera.updatePreviewRotation)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityLabel("Camera preview")
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
            Text("Dali V1")
                .font(.headline.bold())
                .foregroundStyle(.teal)

            Spacer()

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
                showConfiguration = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Configure")

            Button {
                showTutor = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .accessibilityLabel("Help")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

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

    private var configurationSheet: some View {
        NavigationStack {
            Form {
                Section("Guidance") {
                    Picker("Pose package", selection: $camera.selectedPosePackage) {
                        ForEach(PosePackageID.allCases) { package in
                            Text(package.title).tag(package)
                        }
                    }

                    Toggle("Debug overlay", isOn: $camera.debugEnabled)
                }

                Section("Beautify") {
                    Text("Portrait polish applies in photo review. Captures are saved as originals; save a copy to keep an enhancement.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Portrait polish")
                            Spacer()
                            Text("\(camera.beautifySettings.strength)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: beautifyStrengthBinding, in: 0...10, step: 1)
                            .accessibilityLabel("Portrait polish strength")
                    }

                    Toggle("Face brightness", isOn: $camera.beautifySettings.faceBrightnessEnabled)
                    Toggle("Skin smoothing", isOn: $camera.beautifySettings.skinSmoothingEnabled)
                    Toggle("Warmth", isOn: $camera.beautifySettings.warmthEnabled)
                    Toggle("Face clarity", isOn: $camera.beautifySettings.clarityEnabled)
                    Toggle("Subject emphasis", isOn: $camera.beautifySettings.subjectEmphasisEnabled)
                }
            }
            .navigationTitle("Configure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showConfiguration = false
                    }
                }
            }
        }
    }

    private var cameraControlSheet: some View {
        let capabilities = camera.cameraControlCapabilities

        return NavigationStack {
            Form {
                Section {
                    Picker("Camera control", selection: $cameraControlMode) {
                        ForEach(CameraControlMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("cameraControlMode")
                    .onChange(of: cameraControlMode) { _, mode in
                        if mode == .auto { camera.resetCameraControlsToAuto() }
                    }
                } footer: {
                    Text(cameraControlMode == .auto
                         ? "The phone chooses camera settings."
                         : "Dali explains simple adjustments; you decide whether to use them.")
                }

                Section {
                    Toggle(
                        "Say “Cheese”",
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

                    if voiceShutter.permissionDenied {
                        Button("Open Settings") { openSettings() }
                    }
                } header: {
                    Text("Voice shutter")
                } footer: {
                    Text("Voice shutter listens only while the live camera is open. It pauses during photo review and when Dali is in the background.")
                }

                if capabilities.isAvailable {
                    Section("This camera") {
                        LabeledContent("Device", value: capabilities.cameraName)
                        LabeledContent("Active lens", value: capabilities.lensName)
                        if let duration = capabilities.currentExposureDurationSeconds {
                            LabeledContent("Shutter", value: shutterDurationLabel(duration))
                        }
                        if let iso = capabilities.currentISO {
                            LabeledContent("ISO", value: "\(Int(iso.rounded()))")
                        }
                    }

                    Section("Basic controls") {
                        if capabilities.supportsExposureBias {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Exposure compensation")
                                    Spacer()
                                    Text(String(format: "%+.1f EV", capabilities.currentExposureBias))
                                        .font(.headline.monospacedDigit())
                                }
                                Slider(
                                    value: exposureBiasBinding,
                                    in: capabilities.minimumExposureBias...capabilities.maximumExposureBias,
                                    step: 0.1
                                )
                                .disabled(cameraControlMode == .auto)
                                .accessibilityIdentifier("exposureBiasSlider")
                                Text("Negative values protect bright areas; positive values brighten the image.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if capabilities.supportsFocusLock || capabilities.supportsExposureLock {
                            Toggle("Lock focus and exposure", isOn: focusExposureLockBinding)
                                .disabled(cameraControlMode == .auto || !(capabilities.supportsFocusLock && capabilities.supportsExposureLock))
                                .accessibilityIdentifier("focusExposureLock")
                        }

                        Button("Return camera controls to Auto") {
                            cameraControlMode = .auto
                            camera.resetCameraControlsToAuto()
                        }
                        .accessibilityIdentifier("resetCameraControls")
                    }

                    Section("Available on this camera") {
                        capabilityRow("Exposure compensation", supported: capabilities.supportsExposureBias)
                        capabilityRow("Focus lock", supported: capabilities.supportsFocusLock)
                        capabilityRow("Exposure lock", supported: capabilities.supportsExposureLock)
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "Camera controls need an iPhone",
                            systemImage: "iphone.gen3",
                            description: Text("Dali reads the active camera's capabilities at runtime. Controls appear only when that camera supports them.")
                        )
                    }
                }

                Section("Placement test") {
                    Text("The Camera button is beside the shutter so it stays available even when coaching is turned off. We can move it after testing this layout on the phone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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

    private var exposureBiasBinding: Binding<Double> {
        Binding(
            get: { camera.cameraControlCapabilities.currentExposureBias },
            set: { camera.setExposureBias($0) }
        )
    }

    private var focusExposureLockBinding: Binding<Bool> {
        Binding(
            get: { camera.cameraControlCapabilities.isFocusExposureLocked },
            set: { camera.setFocusExposureLocked($0) }
        )
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

    private func loadStoredBeautifySettings() {
        camera.beautifySettings = BeautifySettings(
            strength: storedBeautifyStrength,
            faceBrightnessEnabled: storedBeautifyFaceBrightnessEnabled,
            skinSmoothingEnabled: storedBeautifySkinSmoothingEnabled,
            warmthEnabled: storedBeautifyWarmthEnabled,
            clarityEnabled: storedBeautifyClarityEnabled,
            subjectEmphasisEnabled: storedBeautifySubjectEmphasisEnabled
        )
    }

    private func persistBeautifySettings() {
        storedBeautifyStrength = camera.beautifySettings.strength
        storedBeautifyFaceBrightnessEnabled = camera.beautifySettings.faceBrightnessEnabled
        storedBeautifySkinSmoothingEnabled = camera.beautifySettings.skinSmoothingEnabled
        storedBeautifyWarmthEnabled = camera.beautifySettings.warmthEnabled
        storedBeautifyClarityEnabled = camera.beautifySettings.clarityEnabled
        storedBeautifySubjectEmphasisEnabled = camera.beautifySettings.subjectEmphasisEnabled
    }

    private func reviewSlideshowView(original: UIImage) -> some View {
        GeometryReader { proxy in
            let image = currentReviewDisplayImage(original: original)
            let imageHeight = max(280, proxy.size.height * 0.52)

            ScrollView {
                VStack(spacing: 0) {
                    reviewSlideshowTopBar
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    reviewModePicker
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)

                    if camera.debugEnabled {
                        posePackagePicker
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }

                    reviewImagePane(
                        image: image,
                        title: reviewVariant.title,
                        subtitle: reviewImageSubtitle,
                        showOverlay: false
                    )
                    .frame(maxWidth: .infinity, minHeight: imageHeight, maxHeight: imageHeight)

                    VStack(spacing: 12) {
                        reviewActions(original: original)
                        beautifyControls
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

    private var reviewSlideshowTopBar: some View {
        HStack(spacing: 8) {
            Button {
                reviewPhotos = []
                reviewPhotoIndex = 0
                reviewVariant = .original
                camera.clearStillPhoto()
                camera.start()
            } label: {
                Image(systemName: "camera.viewfinder")
                    .frame(width: 44, height: 44)
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

    private var reviewModePicker: some View {
        HStack(spacing: 8) {
            Picker("Review image", selection: $reviewVariant) {
                ForEach(availableReviewVariants, id: \.self) { variant in
                    Text(variant.title).tag(variant)
                }
            }
            .pickerStyle(.segmented)

            if camera.debugEnabled {
                Button {
                    camera.simulateTilt(degrees: -7)
                    reviewVariant = .tilted
                } label: {
                    Image(systemName: "rotate.left")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))

                Button {
                    camera.simulateTilt(degrees: 7)
                    reviewVariant = .tilted
                } label: {
                    Image(systemName: "rotate.right")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
            }
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

    private func reviewImagePane(image: UIImage, title: String, subtitle: String?, showOverlay: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            Color.black

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    showFullScreenReviewImage = true
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

    private func currentReviewDisplayImage(original: UIImage) -> UIImage {
        switch reviewVariant {
        case .original:
            return original
        case .reframed:
            return camera.reframedImage ?? original
        case .leveled:
            return camera.leveledImage ?? original
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

        if let first = loadedPhotos.first {
            camera.stop()
            reviewPhotos = loadedPhotos
            reviewPhotoIndex = 0
            reviewVariant = .original
            camera.analyzeStillPhoto(data: first.data)
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

        if let first = loadedPhotos.first {
            camera.stop()
            reviewPhotos = loadedPhotos
            reviewPhotoIndex = 0
            reviewVariant = .original
            camera.analyzeStillPhoto(data: first.data)
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

    private func showNextReviewPhoto() {
        guard canNavigateReviewPhotos else { return }
        reviewPhotoIndex = (reviewPhotoIndex + 1) % reviewPhotos.count
        analyzeCurrentReviewPhoto()
    }

    private func analyzeCurrentReviewPhoto() {
        guard reviewPhotos.indices.contains(reviewPhotoIndex) else { return }
        reviewVariant = .original
        camera.analyzeStillPhoto(data: reviewPhotos[reviewPhotoIndex].data)
    }

    private var beautifyStrengthBinding: Binding<Double> {
        Binding(
            get: { Double(camera.beautifySettings.strength) },
            set: { camera.setBeautifyStrength(Int($0.rounded())) }
        )
    }

    private var beautifyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.teal)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Portrait polish")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    Text(beautifyStatusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Text("\(camera.beautifySettings.strength)")
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            Slider(value: beautifyStrengthBinding, in: 0...10, step: 1)
                            .accessibilityLabel("Portrait polish strength")
                .tint(.teal)

            HStack(spacing: 8) {
                Button {
                    camera.setBeautifyStrength(0)
                    reviewVariant = .original
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.caption.bold())
                        .frame(minHeight: 44)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                if camera.beautifiedImage != nil {
                    Button {
                        reviewVariant = .beautified
                    } label: {
                        Label("Show", systemImage: "sparkles")
                            .font(.caption.bold())
                            .frame(minHeight: 44)
                            .padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(.teal, in: RoundedRectangle(cornerRadius: 8))
                }

                Spacer()
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
        guard camera.beautifySettings.strength > 0 else {
            return "Original image unchanged"
        }

        guard let result = camera.beautifyResult else {
            return "Ready"
        }

        if result.faceDetected {
            return "Face-aware polish active"
        }

        return "Global polish active"
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Label("Frame your friend and the view", systemImage: "person.crop.rectangle")
                        .font(.title2.bold())
                    Text("Dali shows one suggestion at a time. Subject means the person in the photo; Photographer means you.")
                    Text("Use Poses & angles for optional guided steps. Tap Done / Next when comfortable, or skip any step. You can take a photo whenever you like.")
                    Text("Tap the thumbnail to review your latest photo. Originals save to Photos; Save a copy keeps the enhancement you are viewing.")
                    Button("Start taking photos") { showTutor = false }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(minHeight: 44)
                }
                .padding(24)
            }
            .navigationTitle("Welcome to Dali")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showTutor = false }
                }
            }
        }
    }

    private var situationGuidanceCard: some View {
        let guidance = situationGuidance

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: guidance.symbol)
                    .accessibilityHidden(true)
                Text(shootingMode == .auto ? "Auto · \(activeSituation.title)" : activeSituation.title)
            }
            .font(.caption.bold())
            .textCase(.uppercase)
            .foregroundStyle(.teal)
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
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.teal.opacity(0.65), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("situationGuidanceCard")
        .padding(.bottom, 8)
    }

    private var situationGuidance: (title: String, instruction: String, symbol: String) {
        switch activeSituation {
        case .portrait, .personScene:
            let detail: String
            switch camera.advice.recipient {
            case "Photographer": detail = "Adjust the camera position or framing."
            case "Subject": detail = "Ask the subject to make this adjustment."
            default: detail = "Dali is analyzing the live camera view."
            }
            return (camera.advice.instruction, detail, camera.advice.directionSymbol ?? activeSituation.symbol)
        case .group:
            guard let group = camera.measurements.groupAnalysis else {
                return ("Bring everyone into frame", "Step back until every person is visible.", "person.3")
            }
            if group.faceVisibilityRatio < 0.8 {
                return ("Make every face visible", "Ask the group to adjust so no face is blocked.", "person.3")
            }
            if group.edgeCrowdingScore > 0.35 {
                return ("Leave space at the edges", "Step back slightly so nobody is cut off.", "arrow.down.right.and.arrow.up.left")
            }
            if let spacing = group.spacingScore, spacing > 1.8 {
                return ("Bring the group closer", "Reduce the gaps between people.", "arrow.left.and.right")
            }
            return ("Group looks ready", "Keep every face visible and take the photo.", "checkmark.circle")
        case .action:
            guard let person = camera.measurements.personBox else {
                return ("Find the moving subject", "Frame the subject before following the action.", "figure.run")
            }
            if person.rect.minX < 0.06 || person.rect.maxX > 0.94 {
                return ("Give the subject more room", "Keep space around them so movement stays in frame.", "arrow.left.and.right")
            }
            if camera.measurements.cameraMotion > 0.5 {
                return ("Track more smoothly", "Follow the subject steadily before pressing the shutter.", "viewfinder")
            }
            if camera.measurements.subjectMotion >= 0.16 {
                return ("Keep following the action", "Track the subject and take the photo as the moment develops.", "figure.run")
            }
            return ("Anticipate the movement", "Leave room in the direction the subject is moving.", "figure.run")
        case .closeUp:
            if camera.measurements.cameraMotion > 0.22 {
                return ("Steady the close-up", "Hold the phone still so the detail stays sharp.", "viewfinder")
            }
            if let object = camera.measurements.salientObjectBox {
                let area = object.rect.width * object.rect.height
                if area < 0.18 {
                    return ("Move closer to the detail", "Fill more of the frame while keeping the subject sharp.", "plus.magnifyingglass")
                }
                if area > 0.72 || object.rect.minX < 0.025 || object.rect.maxX > 0.975 {
                    return ("Give the detail more space", "Step back slightly so its edges are not cut off.", "minus.magnifyingglass")
                }
            } else {
                return ("Choose one clear detail", "Center the object you want Dali to evaluate.", "viewfinder")
            }
            if abs(camera.measurements.cameraRollDegrees) > 3 {
                return ("Align the subject", "Rotate the phone slightly to straighten the composition.", "level")
            }
            return ("Simplify the background", "Fill the frame with the detail and remove distractions around it.", "viewfinder")
        case .landscape:
            let guidance = landscapeGuidance
            return (guidance.title, guidance.instruction, guidance.symbol)
        case .auto:
            return ("Checking the scene", "Hold the camera steady while Dali chooses a situation.", "wand.and.stars")
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

    private var landscapeGuidanceCard: some View {
        let guidance = landscapeGuidance

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: guidance.symbol)
                    .accessibilityHidden(true)
                Text(shootingMode == .auto ? "Auto · Landscape" : "Landscape guidance")
            }
            .font(.caption.bold())
            .textCase(.uppercase)
            .foregroundStyle(.teal)
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
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.teal.opacity(0.65), lineWidth: 1)
        }
        .accessibilityIdentifier("landscapeGuidanceCard")
    }

    private var landscapeGuidance: (title: String, instruction: String, symbol: String) {
        let horizonTilt = camera.measurements.horizonAngleDegrees ?? camera.measurements.cameraRollDegrees
        if abs(horizonTilt) > 2.5 {
            return (
                "Level the horizon",
                horizonTilt > 0 ? "Rotate the phone slightly counterclockwise." : "Rotate the phone slightly clockwise.",
                "level"
            )
        }
        if camera.measurements.horizonConfidence > 0.2 {
            return (
                "Horizon looks level",
                "Place the horizon away from the center, then include a foreground element for depth.",
                "checkmark.circle"
            )
        }
        return (
            "Build depth in the scene",
            "Include a nearby subject, a middle distance, and the background before taking the photo.",
            "mountain.2"
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
                    Text(pose.title)
                        .font(.caption.bold())
                        .textCase(.uppercase)
                        .foregroundStyle(.teal)

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
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.teal.opacity(0.65), lineWidth: 1)
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
            "person \(result.personDetected ? "yes" : "no")"
        ]

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
            if thumbnail != nil {
                Button {
                    reviewPhotos = []
                    reviewPhotoIndex = 0
                    reviewVariant = .original
                    camera.openLatestCapture()
                } label: {
                    PhotoLibraryButtonLabel(thumbnail: thumbnail)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Review latest photo")
            } else {
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 20, matching: .images) {
                    PhotoLibraryButtonLabel(thumbnail: nil)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                camera.capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 76, height: 76)
                    Circle()
                        .stroke(.black.opacity(0.35), lineWidth: 3)
                        .frame(width: 60, height: 60)
                }
                .accessibilityLabel("Take photo")
            }
            .buttonStyle(.plain)
            .disabled(!camera.cameraReady || camera.isCapturing || camera.isSaving || camera.hasUnsavedCapture || camera.isAnalyzingPhoto)

            Spacer()

            Button {
                showCameraControls = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 20, weight: .bold))
                    Text(cameraControlMode.title)
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(cameraControlMode == .auto ? .white : .teal)
                .frame(width: 52, height: 52)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Camera controls, \(cameraControlMode.title)")
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
        Button("Save a copy") { camera.saveCopy(currentReviewDisplayImage(original: original)) }
            .disabled(camera.isSaving || camera.isAnalyzingPhoto)
        Button("Share") { sharedPhoto = SharedPhoto(image: currentReviewDisplayImage(original: original)) }
            .disabled(camera.isAnalyzingPhoto)
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
            return .white.opacity(0.35)
        case .ready:
            return .teal
        case .warning:
            return .yellow
        case .danger:
            return .red
        }
    }
}

private struct ReviewPhoto: Identifiable {
    let id = UUID()
    let data: Data
    let title: String
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

private enum ReviewVariant: Hashable {
    case original
    case reframed
    case leveled
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
        case .beautified:
            return "Beautified"
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
