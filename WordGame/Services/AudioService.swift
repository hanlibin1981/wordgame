import Foundation
import AVFoundation
import os

/// Service for text-to-speech audio playback
final class AudioService: ObservableObject {
    static let shared = AudioService()

    private let logger = Logger(subsystem: "com.wordgame.audio", category: "AudioService")

    @Published var isPlaying = false
    @Published var lastError: String?

    private var audioPlayer: AVAudioPlayer?
    private var audioPlayerOnComplete: ((Bool) -> Void)?
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
            logger.error("Audio session setup failed: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Sound Enabled Check
    private var isSoundEnabled: Bool {
        // Default to true if not set (sound enabled by default)
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "soundEnabled")
    }

    private var preferredVoice: String {
        UserDefaults.standard.string(forKey: "ttsVoice") ?? "Alex"
    }

    // MARK: - Text-to-Speech
    /// Speak a word using system TTS
    func speak(_ text: String, language: String = "en-US") {
        guard isSoundEnabled else { return }

        #if os(macOS)
        speakWithSay(text)
        return
        #endif

        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8
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
    func speakWithSay(_ text: String, voice: String? = nil) {
        guard isSoundEnabled else { return }
        stop()

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        task.arguments = ["-v", voice ?? preferredVoice, text]

        isPlaying = true

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
                    self?.logger.error("say command failed: \(error.localizedDescription)")
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
        guard isSoundEnabled else {
            onFinish?()
            return
        }
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
        task.arguments = ["-v", preferredVoice, word.word]

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
                    self?.logger.error("TTS fallback failed: \(error.localizedDescription)")
                    onFinish?()
                }
            }
        }
    }

    private var audioPlayerCompletionTimer: Timer?

    /// Play audio from a URL using AVAudioPlayer with delegate-based completion detection
    private func playFromURL(_ url: URL, onComplete: @escaping (Bool) -> Void) {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = AudioPlayerDelegateHandler.shared
                self.audioPlayer = player
                self.audioPlayerOnComplete = onComplete
                AudioPlayerDelegateHandler.shared.onComplete = { [weak self] success in
                    DispatchQueue.main.async {
                        self?.audioPlayer = nil
                        onComplete(success)
                    }
                }
                player.prepareToPlay()
                player.play()
            } catch {
                DispatchQueue.main.async {
                    self.lastError = "Failed to play audio from URL: \(error.localizedDescription)"
                    self.logger.error("URL playback failed: \(error.localizedDescription)")
                    onComplete(false)
                }
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate Handler
/// Dedicated handler for AVAudioPlayerDelegate to avoid Timer polling
private class AudioPlayerDelegateHandler: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerDelegateHandler()
    var onComplete: ((Bool) -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onComplete?(flag)
        onComplete = nil
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Logger(subsystem: "com.wordgame.audio", category: "AudioPlayerDelegate")
            .error("Decode error: \(error?.localizedDescription ?? "unknown")")
        onComplete?(false)
        onComplete = nil
    }
}

// MARK: - Speech Delegate
private class AudioServiceDelegate: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = AudioServiceDelegate()
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }
}
