@preconcurrency import AVFoundation
@preconcurrency import Speech
import SwiftUI

@MainActor
final class VoiceShutterController: NSObject, ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isListening = false
    @Published private(set) var statusText = "Voice shutter is off"
    @Published private(set) var permissionDenied = false

    var onTakePhoto: (@MainActor () -> Void)?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: .current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var activeSessionID: UUID?
    private var inputTapInstalled = false
    private var cameraIsLive = true

    func setEnabled(_ enabled: Bool) {
        if !enabled {
            isEnabled = false
            permissionDenied = false
            stopListening()
            statusText = "Voice shutter is off"
            return
        }

        guard !isEnabled else { return }
        isEnabled = true
        permissionDenied = false
        statusText = "Requesting microphone and speech access…"

        Task {
            let speechStatus = await requestSpeechAuthorization()
            guard isEnabled else { return }
            let microphoneAllowed = await AVCaptureDevice.requestAccess(for: .audio)
            guard isEnabled else { return }

            guard speechStatus == .authorized, microphoneAllowed else {
                permissionDenied = true
                isEnabled = false
                stopListening()
                statusText = "Microphone and Speech Recognition access are required"
                return
            }

            if cameraIsLive {
                startListening()
            } else {
                statusText = "Paused until the camera is live"
            }
        }
    }

    func pauseListening() {
        cameraIsLive = false
        stopListening()
        if isEnabled { statusText = "Paused until the camera is live" }
    }

    func resumeIfEnabled() {
        cameraIsLive = true
        guard isEnabled, !isListening else { return }
        startListening()
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        if SFSpeechRecognizer.authorizationStatus() != .notDetermined {
            return SFSpeechRecognizer.authorizationStatus()
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func startListening() {
        guard isEnabled, cameraIsLive, !isListening else { return }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            statusText = "Speech Recognition is temporarily unavailable"
            scheduleRestart()
            return
        }

        stopListening()
        let sessionID = UUID()
        activeSessionID = sessionID

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
                request.append(buffer)
            }
            inputTapInstalled = true

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            statusText = "Listening for “Cheese”"

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                let transcript = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                Task { @MainActor [weak self] in
                    self?.handleRecognition(
                        transcript: transcript,
                        isFinal: isFinal,
                        error: error,
                        sessionID: sessionID
                    )
                }
            }
        } catch {
            stopListening()
            statusText = "Could not start voice shutter"
            scheduleRestart()
        }
    }

    private func handleRecognition(transcript: String?, isFinal: Bool, error: Error?, sessionID: UUID) {
        guard activeSessionID == sessionID else { return }

        if let transcript, VoiceShutterCommand.matches(transcript) {
            statusText = "Taking photo…"
            stopListening()
            onTakePhoto?()
            scheduleRestart(after: .seconds(3))
            return
        }

        if error != nil || isFinal {
            stopListening()
            scheduleRestart()
        }
    }

    private func scheduleRestart(after delay: Duration = .milliseconds(600)) {
        guard isEnabled, cameraIsLive else { return }
        Task {
            try? await Task.sleep(for: delay)
            guard isEnabled, cameraIsLive, !isListening else { return }
            startListening()
        }
    }

    private func stopListening() {
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
