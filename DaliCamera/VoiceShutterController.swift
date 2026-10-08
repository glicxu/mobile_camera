@preconcurrency import AVFoundation
@preconcurrency import Speech
import SwiftUI

@MainActor
final class VoiceShutterController: NSObject, ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isListening = false
    @Published private(set) var statusText = "Voice shutter is off"
    @Published private(set) var permissionDenied = false

    var onTakePhoto: (@MainActor () -> Bool)?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: .current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var authorizationTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private var activeSessionID: UUID?
    private var inputTapInstalled = false
    private var listeningAllowed = true
    private var pausedStatusText = "Paused until the live camera returns"
    private var customPhrase = ""

    func setCustomPhrase(_ phrase: String) {
        customPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        if isListening { statusText = listeningStatusText }
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else {
            if enabled { prepareToListen() }
            return
        }

        isEnabled = enabled
        permissionDenied = false

        if enabled {
            statusText = "Checking microphone and speech access…"
            prepareToListen()
        } else {
            authorizationTask?.cancel()
            authorizationTask = nil
            stopListening()
            statusText = "Voice shutter is off"
        }
    }

    func pauseListening(reason: String = "Paused until the live camera returns") {
        listeningAllowed = false
        pausedStatusText = reason
        stopListening()
        if isEnabled { statusText = reason }
    }

    func resumeIfEnabled() {
        listeningAllowed = true
        guard isEnabled, !isListening else { return }
        prepareToListen()
    }

    private func prepareToListen() {
        guard isEnabled else { return }
        guard listeningAllowed else {
            statusText = pausedStatusText
            return
        }
        guard authorizationTask == nil else { return }

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        if speechStatus == .authorized, microphoneStatus == .authorized {
            startListening()
            return
        }

        if let denial = authorizationDenialMessage(
            speechStatus: speechStatus,
            microphoneStatus: microphoneStatus
        ) {
            failAuthorization(with: denial)
            return
        }

        statusText = "Requesting microphone and speech access…"
        authorizationTask = Task { [weak self] in
            guard let self else { return }
            let resolvedSpeechStatus = await requestSpeechAuthorization()
            guard !Task.isCancelled, isEnabled else {
                authorizationTask = nil
                return
            }
            let microphoneAllowed = await requestMicrophoneAuthorization()
            guard !Task.isCancelled, isEnabled else {
                authorizationTask = nil
                return
            }

            authorizationTask = nil
            let resolvedMicrophoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            guard resolvedSpeechStatus == .authorized, microphoneAllowed else {
                let message = authorizationDenialMessage(
                    speechStatus: resolvedSpeechStatus,
                    microphoneStatus: resolvedMicrophoneStatus
                ) ?? "Microphone and Speech Recognition access are required"
                failAuthorization(with: message)
                return
            }

            guard listeningAllowed else {
                statusText = pausedStatusText
                return
            }
            startListening()
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        guard currentStatus == .notDetermined else { return currentStatus }

        return await Self.requestSpeechAuthorizationFromSystem()
    }

    /// Speech calls its completion on an arbitrary queue. Keeping the callback
    /// in a nonisolated context prevents Swift 6 from attaching a MainActor
    /// executor precondition to the system-owned callback.
    nonisolated private static func requestSpeechAuthorizationFromSystem() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func authorizationDenialMessage(
        speechStatus: SFSpeechRecognizerAuthorizationStatus,
        microphoneStatus: AVAuthorizationStatus
    ) -> String? {
        if speechStatus == .denied || speechStatus == .restricted {
            return "Speech Recognition access is off. Enable it in Settings."
        }
        if microphoneStatus == .denied || microphoneStatus == .restricted {
            return "Microphone access is off. Enable it in Settings."
        }
        return nil
    }

    private func failAuthorization(with message: String) {
        permissionDenied = true
        isEnabled = false
        stopListening()
        statusText = message
    }

    private func startListening() {
        guard isEnabled, listeningAllowed, !isListening else { return }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            statusText = "Speech Recognition is temporarily unavailable"
            scheduleRestart(after: .seconds(2))
            return
        }

        stopListening(cancelRestart: false)
        let sessionID = UUID()
        activeSessionID = sessionID

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .confirmation
            request.contextualStrings = VoiceShutterCommand.spokenExamples + (customPhrase.isEmpty ? [] : [customPhrase])
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw VoiceShutterError.audioInputUnavailable
            }
            Self.installAudioTap(on: inputNode, format: format, request: request)
            inputTapInstalled = true

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            statusText = listeningStatusText

            recognitionTask = Self.startRecognitionTask(
                recognizer: speechRecognizer,
                request: request,
                sessionID: sessionID,
                owner: self
            )
        } catch {
            stopListening()
            statusText = "Could not start voice shutter. Retrying…"
            scheduleRestart(after: .seconds(2))
        }
    }

    nonisolated private static func installAudioTap(
        on inputNode: AVAudioInputNode,
        format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func startRecognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        sessionID: UUID,
        owner: VoiceShutterController
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { [weak owner] result, error in
                let transcript = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                Task { @MainActor [weak owner] in
                    owner?.handleRecognition(
                        transcript: transcript,
                        isFinal: isFinal,
                        error: error,
                        sessionID: sessionID
                    )
                }
            }
    }

    private func handleRecognition(transcript: String?, isFinal: Bool, error: Error?, sessionID: UUID) {
        guard activeSessionID == sessionID else { return }

        if let transcript, VoiceShutterCommand.matches(transcript, customPhrase: customPhrase) {
            stopListening()
            if onTakePhoto?() == true {
                statusText = "Voice command heard — taking photo…"
                scheduleRestart(after: .seconds(3))
            } else {
                statusText = "Camera is not ready yet. Keep the live camera open."
                scheduleRestart()
            }
            return
        }

        if error != nil || isFinal {
            stopListening()
            statusText = "Listening restarting…"
            scheduleRestart()
        }
    }

    private var listeningStatusText: String {
        customPhrase.isEmpty
            ? "Listening: say “Cheese” or “Take photo”"
            : "Listening: say “\(customPhrase)”"
    }

    private func scheduleRestart(after delay: Duration = .milliseconds(600)) {
        restartTask?.cancel()
        guard isEnabled, listeningAllowed else { return }
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            restartTask = nil
            guard isEnabled, listeningAllowed, !isListening else { return }
            prepareToListen()
        }
    }

    private func stopListening(cancelRestart: Bool = true) {
        if cancelRestart {
            restartTask?.cancel()
            restartTask = nil
        }
        activeSessionID = nil
        if audioEngine.isRunning { audioEngine.stop() }
        if inputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            inputTapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private enum VoiceShutterError: Error {
    case audioInputUnavailable
}
