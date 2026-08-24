import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var camera = CameraModel()
    @AppStorage("hasSeenDaliTutor") private var hasSeenDaliTutor = false
    @AppStorage("beautifyStrength") private var storedBeautifyStrength = 0
    @AppStorage("beautifyFaceBrightnessEnabled") private var storedBeautifyFaceBrightnessEnabled = true
    @AppStorage("beautifySkinSmoothingEnabled") private var storedBeautifySkinSmoothingEnabled = true
    @AppStorage("beautifyWarmthEnabled") private var storedBeautifyWarmthEnabled = true
    @AppStorage("beautifyClarityEnabled") private var storedBeautifyClarityEnabled = true
    @AppStorage("beautifySubjectEmphasisEnabled") private var storedBeautifySubjectEmphasisEnabled = true
    @State private var showTutor = false
    @State private var tutorStepIndex = 0
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingFolderImporter = false
    @State private var showConfiguration = false
    @State private var reviewPhotos: [ReviewPhoto] = []
    @State private var reviewPhotoIndex = 0
    @State private var reviewVariant: ReviewVariant = .original
    @State private var showFullScreenReviewImage = false
    @State private var shootingMode: ShootingMode = .people

    private let tutorSteps = [
        TutorStep(
            title: "Subject",
            instruction: "Use these when Dali cannot clearly see the person or needs the subject's attention.",
            symbolName: "person.crop.rectangle",
            examples: [
                "Frame the person",
                "Face the camera"
            ]
        ),
        TutorStep(
            title: "Photographer movement",
            instruction: "Move your body or change distance while keeping the same person and scene in view.",
            symbolName: "arrow.left.and.right",
            examples: [
                "Move left",
                "Move right",
                "Step back",
                "Step closer",
                "Lower camera",
                "Raise camera"
            ]
        ),
        TutorStep(
            title: "Camera handling",
            instruction: "Adjust the phone itself when the frame is tilted, shaky, or in the wrong orientation.",
            symbolName: "camera.viewfinder",
            examples: [
                "Tilt left",
                "Tilt right",
                "Hold steady",
                "Switch to portrait",
                "Switch to landscape"
            ]
        ),
        TutorStep(
            title: "Framing",
            instruction: "Use these to keep the person comfortable in the frame while preserving the place around them.",
            symbolName: "rectangle.inset.filled",
            examples: [
                "Keep their feet in frame",
                "Give them more headroom",
                "Put them slightly left",
                "Put them slightly right",
                "Include more of the view",
                "Leave more space above them"
            ]
        ),
        TutorStep(
            title: "Lighting",
            instruction: "Use these when the face is too dark, the background is too bright, or the angle is fighting the light.",
            symbolName: "sun.max",
            examples: [
                "Turn them toward the light",
                "Move them out of shadow",
                "Try a slightly different angle",
                "Face the light",
                "Find brighter light"
            ]
        ),
        TutorStep(
            title: "Subject direction",
            instruction: "Say these to the person in the photo when a small pose or position change would help.",
            symbolName: "figure.wave",
            examples: [
                "Ask them to turn slightly left",
                "Ask them to turn slightly right",
                "Ask them to face the light",
                "Ask them to step slightly forward"
            ]
        ),
        TutorStep(
            title: "Readiness",
            instruction: "Use these when the frame is good enough and the photographer can take the shot.",
            symbolName: "checkmark.circle",
            examples: [
                "Hold there",
                "Great shot",
                "Ready",
                "Take it"
            ]
        )
    ]

    var body: some View {
        ZStack {
            if let reviewImage = camera.reviewImage {
                reviewSlideshowView(original: reviewImage)
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()

                OverlayView(
                    advice: camera.advice,
                    measurements: camera.measurements,
                    issues: camera.issues,
                    debugEnabled: camera.debugEnabled && shootingMode.showsGuidance
                )
                .opacity(shootingMode.showsGuidance ? 1 : 0)
            }

            if camera.reviewImage == nil {
                VStack {
                    topBar
                    Spacer()
                    if let captureStatus = camera.captureStatus {
                        Text(captureStatus)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
                            .padding(.bottom, 8)
                    }
                    if shootingMode.showsGuidance {
                        adviceCard
                    }
                    controls
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 18)
            }

            if camera.permissionDenied {
                permissionView
            }

            if camera.debugEnabled, camera.reviewImage == nil {
                floatingDebugPanel
            }

            if showTutor {
                tutorCard
            }
        }
        .background(Color.black)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            loadStoredBeautifySettings()
            camera.start()
            if !hasSeenDaliTutor {
                showTutor = true
                hasSeenDaliTutor = true
            }
        }
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await loadReviewPhotos(from: items)
                selectedPhotoItems = []
            }
        }
        .onChange(of: camera.selectedPosePackage) { _, _ in
            camera.refreshStillPhotoAdvice()
        }
        .onChange(of: camera.beautifySettings) { _, _ in
            persistBeautifySettings()
            camera.refreshBeautify()
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
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showFullScreenReviewImage) {
            if let reviewImage = camera.reviewImage {
                ZoomableReviewImageView(
                    image: currentReviewDisplayImage(original: reviewImage),
                    originalImage: reviewImage,
                    title: reviewVariant.title,
                    subtitle: reviewImageSubtitle,
                    isPresented: $showFullScreenReviewImage
                )
            }
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
            .disabled(camera.reviewImage != nil)
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
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Portrait polish")
                            Spacer()
                            Text("\(camera.beautifySettings.strength)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: beautifyStrengthBinding, in: 0...10, step: 1)
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

            ZStack {
                Color.black

                VStack(spacing: 0) {
                    reviewSlideshowTopBar
                        .padding(.horizontal, 12)
                        .padding(.top, max(12, proxy.safeAreaInsets.top + 6))
                        .padding(.bottom, 8)

                    reviewModePicker
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)

                    posePackagePicker
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)

                    reviewImagePane(
                        image: image,
                        title: reviewVariant.title,
                        subtitle: reviewImageSubtitle,
                        showOverlay: false
                    )
                    .frame(maxWidth: .infinity, minHeight: imageHeight, maxHeight: imageHeight)

                    detailedAnalysisPanel
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
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
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(.teal, in: RoundedRectangle(cornerRadius: 8))

            Button {
                showPreviousReviewPhoto()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 42, height: 42)
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
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canNavigateReviewPhotos ? .white : .white.opacity(0.32))
            .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
            .disabled(!canNavigateReviewPhotos)

            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 20, matching: .images) {
                Image(systemName: "photo.on.rectangle.angled")
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(.teal, in: RoundedRectangle(cornerRadius: 8))

            Button {
                showingFolderImporter = true
            } label: {
                Image(systemName: "folder")
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(.teal, in: RoundedRectangle(cornerRadius: 8))
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

            Button {
                camera.simulateTilt(degrees: -7)
                reviewVariant = .tilted
            } label: {
                Image(systemName: "rotate.left")
                    .frame(width: 40, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))

            Button {
                camera.simulateTilt(degrees: 7)
                reviewVariant = .tilted
            } label: {
                Image(systemName: "rotate.right")
                    .frame(width: 40, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
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
                    .font(.headline.bold())
                    .frame(width: 42, height: 42)
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
                .tint(.teal)

            HStack(spacing: 8) {
                Button {
                    camera.setBeautifyStrength(0)
                    reviewVariant = .original
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.caption.bold())
                        .frame(minHeight: 34)
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
                            .frame(minHeight: 34)
                            .padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(.teal, in: RoundedRectangle(cornerRadius: 8))
                }

                Spacer()
            }

            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(beautifyDebugChips, id: \.self) { chip in
                    metricChip(chip)
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
        let step = tutorSteps[tutorStepIndex]

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: step.symbolName)
                    .font(.title2.bold())
                    .foregroundStyle(.teal)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("How to use Dali")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                        .textCase(.uppercase)
                    Text(step.title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }

                Spacer()

                Button {
                    showTutor = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.bold())
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.82))
            }

            Text(step.instruction)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(step.examples, id: \.self) { example in
                    Text(example)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack {
                Text("\(tutorStepIndex + 1) of \(tutorSteps.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.58))

                Spacer()

                Button {
                    tutorStepIndex = max(0, tutorStepIndex - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(tutorStepIndex == 0 ? .white.opacity(0.28) : .white)
                .disabled(tutorStepIndex == 0)

                Button {
                    if tutorStepIndex == tutorSteps.count - 1 {
                        showTutor = false
                    } else {
                        tutorStepIndex += 1
                    }
                } label: {
                    Text(tutorStepIndex == tutorSteps.count - 1 ? "Done" : "Next")
                        .font(.headline)
                        .frame(minWidth: 78, minHeight: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(.teal, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: 460)
        .shadow(radius: 20)
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
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(toneColor(camera.advice.tone).opacity(0.7), lineWidth: 1)
        }
        .padding(.bottom, 14)
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
            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 20, matching: .images) {
                PhotoLibraryButtonLabel(thumbnail: thumbnail)
            }
            .buttonStyle(.plain)

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
        }
        .padding(24)
        .foregroundStyle(.white)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
        .padding(24)
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

private struct TutorStep {
    let title: String
    let instruction: String
    let symbolName: String
    let examples: [String]
}

private struct ReviewPhoto: Identifiable {
    let id = UUID()
    let data: Data
    let title: String
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
                                .font(.headline.bold())
                                .frame(width: 42, height: 42)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))

                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline.bold())
                                .frame(width: 42, height: 42)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, max(14, proxy.safeAreaInsets.top + 8))

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
                            Text("Original | \(title)")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(minHeight: 38)
                                .padding(.horizontal, 10)
                                .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.bottom, max(18, proxy.safeAreaInsets.bottom + 10))
                }
            }
        }
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
