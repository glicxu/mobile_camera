import AVFoundation
import Speech

/// Optional on-device recognition; never enables a remote speech fallback.
final class SpeechShutterService {
    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: .current)
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var enabled = false
    private var token = UUID()
    private var lastCommand = Date.distantPast
    var customPhrase = ""
    var onShutter: (() -> Void)?

    func setEnabled(_ value: Bool, completion: @escaping (Result<Bool, Error>) -> Void) {
        stop(); enabled = value
        guard value, recognizer?.supportsOnDeviceRecognition == true, recognizer?.isAvailable == true else { enabled = false; completion(.success(false)); return }
        let epoch = token
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { DispatchQueue.main.async { completion(.success(false)) }; return }
            AVCaptureDevice.requestAccess(for: .audio) { allowed in DispatchQueue.main.async {
                guard self.token == epoch, self.enabled, allowed else { completion(.success(false)); return }
                do { try self.listen(); completion(.success(true)) }
                catch { self.stop(); completion(.failure(error)) }
            }}
        }
    }
    func stop() {
        enabled = false; token = UUID(); stopAudio()
    }
    private func stopAudio() {
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio(); task?.cancel(); request = nil; task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func listen() throws {
        guard enabled, let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { return }
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.record, mode: .measurement, options: [.duckOthers]); try audio.setActive(true)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true; self.request = request
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in request.append(buffer) }
        tapInstalled = true; engine.prepare(); try engine.start()
        let epoch = token
        task = recognizer.recognitionTask(with: request) { result, error in
            let transcript = result?.bestTranscription.formattedString.lowercased() ?? ""
            let final = result?.isFinal == true
            DispatchQueue.main.async {
                guard self.enabled, self.token == epoch else { return }
                let words = transcript.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
                let custom = self.customPhrase.lowercased().components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
                let normalized = " " + words.joined(separator: " ") + " "
                let command = words.contains("cheese") || transcript.range(of: #"\b(take|capture|snap) (a )?(photo|picture)\b"#, options: .regularExpression) != nil || (!custom.isEmpty && normalized.contains(" " + custom.joined(separator: " ") + " "))
                if command && Date().timeIntervalSince(self.lastCommand) > 3 {
                    self.lastCommand = Date(); self.onShutter?(); self.restart(after: 3)
                } else if final || error != nil { self.restart(after: 1) }
            }
        }
    }
    private func restart(after delay: Double) {
        stopAudio(); let epoch = token
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard self.enabled, self.token == epoch else { return }
            do { try self.listen() } catch { self.stop() }
        }
    }
}
