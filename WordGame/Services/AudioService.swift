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
        audioPlayerCompletionTimer?.invalidate()
        audioPlayerCompletionTimer = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    // MARK: - Word Audio Playback

    /// Play audio for a word using hybrid strategy: URL audio first, then TTS fallback
    func playWordAudio(word: Word, onFinish: (() -> Void)? = nil) {
        stop()

        // If URL exists, try to play it first
        if let urlString = word.audioUrl, let url = URL(string: urlString) {
            isPlaying = true
            playFromURL(url) { [weak self] success in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                    if !success {
                        // Fallback to TTS on URL failure
                        self?.playTTSFallback(word: word, onFinish: onFinish)
                    } else {
                        onFinish?()
                    }
                }
            }
        } else {
            // No URL, use TTS directly
            playTTSFallback(word: word, onFinish: onFinish)
        }
    }

    /// Play word via TTS and fire onFinish when done
    private func playTTSFallback(word: Word, onFinish: (() -> Void)? = nil) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        task.arguments = ["-v", "Alex", word.word]

        isPlaying = true

        DispatchQueue.global().async { [weak self] in
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    self?.isPlaying = false
                    onFinish?()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isPlaying = false
                    self?.lastError = error.localizedDescription
                    onFinish?()
                }
            }
        }
    }

    private var audioPlayerCompletionTimer: Timer?

    /// Play audio from a URL using AVAudioPlayer
    private func playFromURL(_ url: URL, onComplete: @escaping (Bool) -> Void) {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer = player
                player.prepareToPlay()
                player.play()

                // Use timer to detect playback completion (no CPU polling)
                DispatchQueue.main.async {
                    self.audioPlayerCompletionTimer?.invalidate()
                    self.audioPlayerCompletionTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak player] timer in
                        guard let player = player else {
                            timer.invalidate()
                            return
                        }
                        if !player.isPlaying {
                            timer.invalidate()
                            self.audioPlayer = nil  // Release resource
                            onComplete(true)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.lastError = "Failed to play audio from URL: \(error.localizedDescription)"
                    onComplete(false)
                }
            }
        }
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
