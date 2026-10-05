import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @StateObject private var camera = CameraModel()
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
    @State private var reviewPhotos: [ReviewPhoto] = []
    @State private var reviewPhotoIndex = 0
    @State private var reviewVariant: ReviewVariant = .original
    @State private var showFullScreenReviewImage = false
    @State private var startReviewComparison = false
    @State private var shootingMode: ShootingMode = .people
    @State private var sharedPhoto: SharedPhoto?
    @State private var showDiscardConfirmation = false
    @State private var showPoseChooser = false
    @State private var guideCollection: PosePackageID = .masculine
    @State private var chosenGuidePose: GuidedPose?
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
            } else if phase == .background {
                camera.stop()
            }
        }
        .sheet(item: $sharedPhoto) { photo in
            PhotoShareSheet(image: photo.image)
        }
        .sheet(isPresented: $showPoseChooser) { poseChooser }
        .sheet(isPresented: $showTutor) { tutorCard }
        .onChange(of: showTutor) { _, showing in
            if showing { camera.stop() } else { camera.start() }
        }
        .onChange(of: shootingMode) { _, mode in
            if !mode.showsGuidance { camera.beginGuidance(pose: nil, position: nil) }
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
                  shootingMode.showsGuidance, !showTutor, !showPoseChooser, !showConfiguration else { return }
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
        }
        .sheet(isPresented: $showConfiguration) {
            configurationSheet
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
                        liveAdvicePanel
                        controls
                    }
                    .frame(width: min(360, proxy.size.width * 0.44))
                }
                .padding(12)
            } else {
                VStack(spacing: 8) {
                    topBar
                    viewfinder
                    liveAdvicePanel
                        .frame(maxHeight: proxy.size.height * 0.34)
                    controls
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
            if shootingMode.showsGuidance {
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
                if shootingMode.showsGuidance {
                    adviceCard
                    guidedControls
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dali V1")
                    .font(.caption.bold())
                    .foregroundStyle(.teal)
                Text(shootingMode.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                showConfiguration = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3.bold())
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
                    .font(.title3.bold())
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

            Button {
                camera.switchCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title3.bold())
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
                Section("Camera") {
                    Picker("Mode", selection: $shootingMode) {
                        ForEach(ShootingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

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
                    .font(.headline.bold())
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
                    .font(.headline.bold())
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
                            .font(.headline.bold())
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

    private var adviceCard: some View {
        HStack(spacing: 12) {
            Text(camera.advice.recipient)
                .font(.caption.bold())
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 96)
                .padding(.vertical, 8)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

            Text(camera.advice.instruction)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(toneColor(camera.advice.tone).opacity(0.7), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .padding(.bottom, 14)
    }

    private var guidedControls: some View {
        VStack(spacing: 6) {
            if camera.guidedSession.isActive {
                Text(camera.guidedSession.isComplete ? "Sequence finished" : "Step \(camera.guidedSession.stepIndex + 1) of \(camera.guidedSession.steps.count) · Confirm when comfortable")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            HStack {
                Button("Poses & angles") {
                    chosenGuidePose = camera.guidedSession.pose
                    guideCollection = chosenGuidePose?.package ?? .masculine
                    chosenCameraPosition = camera.guidedSession.position
                    guideMoveRight = camera.guidedSession.moveRight
                    showPoseChooser = true
                }
                if camera.guidedSession.isActive {
                    Button("Natural") { camera.beginGuidance(pose: nil, position: nil) }
                }
            }
            .font(.caption.bold())
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.teal)
            if camera.guidedSession.currentStep != nil {
                HStack {
                    Button("Done / Next") { camera.advanceGuidance() }
                    Button("Skip this step") { camera.advanceGuidance() }
                }
                .font(.caption.bold())
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.teal)
                .disabled(camera.guidedAction == nil)
            }
        }
        .padding(8)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 8)
    }

    private var poseChooser: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Choose a pose, a camera position, or both. Either collection is available to anyone. Each step is optional; take a photo whenever you like.")
                }
                Section("Subject pose") {
                    Picker("Collection", selection: $guideCollection) {
                        Text("Male / Masculine").tag(PosePackageID.masculine)
                        Text("Female / Feminine").tag(PosePackageID.feminine)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: guideCollection) { _, collection in
                        if chosenGuidePose?.package != collection { chosenGuidePose = nil }
                    }
                    Picker("Pose", selection: $chosenGuidePose) {
                        Text("No pose guidance").tag(Optional<GuidedPose>.none)
                        ForEach(GuidedPose.allCases.filter { $0.package == guideCollection }) { pose in
                            Text(pose.title).tag(Optional(pose))
                        }
                    }
                    if let pose = chosenGuidePose {
                        PoseReferenceView(pose: pose)
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                        Text(pose.cues[0])
                        Text("Left and right refer to the subject's own sides. Confirm or skip each step yourself.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("Photographer position") {
                    Picker("Position", selection: $chosenCameraPosition) {
                        Text("No position guidance").tag(Optional<GuidedCameraPosition>.none)
                        ForEach(GuidedCameraPosition.allCases) { position in
                            Text(position.title).tag(Optional(position))
                        }
                    }
                    if chosenCameraPosition == .side {
                        Toggle("Move to your right", isOn: $guideMoveRight)
                    }
                    if let position = chosenCameraPosition, let step = position.steps(moveRight: guideMoveRight).first {
                        Label(step.instruction, systemImage: step.action.symbol)
                        Text("Directions use the photographer's viewpoint. Camera height is relative to the subject, including when seated.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Poses & angles")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPoseChooser = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(chosenGuidePose == nil && chosenCameraPosition == nil ? "Use Natural" : "Start") {
                        camera.beginGuidance(pose: chosenGuidePose, position: chosenCameraPosition, moveRight: guideMoveRight)
                        showPoseChooser = false
                    }
                }
            }
        }
    }

    private var reviewAnalysisCard: some View {
        let summary = lightingReviewSummary

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Image(systemName: summary.symbolName)
                    .font(.title3.bold())
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

            Color.clear
                .frame(width: 52, height: 52)
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

/// A schematic reference, not a detector overlay or an idealized body shape.
private struct PoseReferenceView: View {
    let pose: GuidedPose

    private var joints: [CGPoint] {
        // Head, neck, hip, left elbow/wrist, right elbow/wrist, left knee/foot, right knee/foot.
        let coordinates: [(Double, Double)]
        switch pose {
        case .relaxedStanding:
            coordinates = [(50, 18), (50, 34), (50, 78), (30, 55), (28, 79), (70, 55), (72, 79), (39, 103), (33, 128), (61, 103), (67, 128)]
        case .threeQuarter:
            coordinates = [(51, 18), (49, 34), (54, 78), (34, 55), (36, 79), (62, 55), (65, 79), (47, 103), (43, 128), (62, 102), (69, 125)]
        case .handInPocket:
            coordinates = [(50, 18), (50, 34), (50, 78), (28, 55), (43, 79), (70, 55), (72, 79), (39, 103), (33, 128), (61, 103), (67, 128)]
        case .seatedLean:
            coordinates = [(58, 24), (57, 40), (42, 80), (66, 60), (68, 88), (77, 62), (81, 89), (65, 92), (63, 128), (83, 94), (84, 128)]
        case .walking:
            coordinates = [(50, 18), (50, 34), (50, 78), (27, 51), (18, 72), (71, 47), (81, 32), (30, 99), (16, 119), (68, 99), (79, 129)]
        case .weightShift:
            coordinates = [(50, 18), (49, 34), (57, 78), (28, 55), (31, 80), (70, 55), (75, 79), (36, 104), (47, 128), (59, 103), (60, 128)]
        case .footForward:
            coordinates = [(50, 18), (50, 34), (50, 78), (31, 55), (29, 79), (69, 55), (72, 79), (47, 103), (55, 130), (59, 100), (66, 120)]
        case .handAtWaist:
            coordinates = [(50, 18), (50, 34), (54, 78), (25, 55), (45, 67), (72, 55), (74, 79), (45, 103), (41, 128), (64, 103), (69, 128)]
        case .seatedAngle:
            coordinates = [(46, 20), (46, 36), (45, 78), (27, 56), (57, 85), (67, 56), (68, 86), (71, 92), (77, 128), (82, 90), (89, 126)]
        case .overShoulder:
            coordinates = [(58, 18), (48, 34), (49, 78), (31, 54), (32, 80), (62, 54), (59, 80), (41, 103), (37, 128), (56, 103), (60, 128)]
        }
        return coordinates.map { CGPoint(x: $0.0, y: $0.1) }
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 100, proxy.size.height / 140)
            let originX = (proxy.size.width - 100 * scale) / 2
            let points = joints.map { CGPoint(x: originX + $0.x * scale, y: $0.y * scale) }
            Path { path in
                for chain in [[1, 2], [1, 3, 4], [1, 5, 6], [2, 7, 8], [2, 9, 10]] {
                    path.move(to: points[chain[0]])
                    for index in chain.dropFirst() { path.addLine(to: points[index]) }
                }
                path.addEllipse(in: CGRect(x: points[0].x - 9 * scale, y: points[0].y - 10 * scale, width: 18 * scale, height: 20 * scale))
            }
            .stroke(.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pose sketch: \(pose.title)")
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
                    .font(.title3.bold())
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
                                .font(.headline.bold())
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
                                .font(.headline.bold())
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

private enum ShootingMode: String, CaseIterable, Identifiable {
    case people
    case landscape
    case camera

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .people:
            return "People Coach"
        case .landscape:
            return "Landscape"
        case .camera:
            return "Camera"
        }
    }

    var shortTitle: String {
        switch self {
        case .people:
            return "People"
        case .landscape:
            return "Landscape"
        case .camera:
            return "Camera"
        }
    }

    var showsGuidance: Bool {
        self == .people
    }
}

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
