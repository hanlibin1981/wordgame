import Foundation
import AVFoundation

/// Service for text-to-speech audio playback
final class AudioService: ObservableObject {
    static let shared = AudioService()

    @Published var isPlaying = false
    @Published var lastError: String?

    private var audioPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        #if os(macOS)
        // macOS doesn't require explicit audio session setup
        #else
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
        #endif
    }

    // MARK: - Text-to-Speech
    /// Speak a word using system TTS
    func speak(_ text: String, language: String = "en-US") {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8  // Slightly slower for learning
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isPlaying = true

        synthesizer.delegate = AudioServiceDelegate.shared
        AudioServiceDelegate.shared.onFinish = { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
            }
        }

        synthesizer.speak(utterance)
    }

    /// Speak a word using the `say` command (macOS native)
    func speakWithSay(_ text: String, voice: String = "Alex") {
        stop()

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        task.arguments = ["-v", voice, text]

        isPlaying = true

        // Use a simple notification approach
        DispatchQueue.global().async { [weak self] in
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    self?.isPlaying = false
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isPlaying = false
                    self?.lastError = error.localizedDescription
                }
            }
        }
    }

    /// Stop any currently playing audio
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        isPlaying = false
    }
}

// MARK: - Delegate
private class AudioServiceDelegate: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = AudioServiceDelegate()
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }
}
