//
//  SpeechService.swift
//  RSS RAIder
//

import Foundation
import AVFoundation
import Combine

@MainActor
class SpeechService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentRate: Float = 0.5
    @Published var progress: Double = 0.0
    @Published var currentWordRange: NSRange?

    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private var fullText: String = ""
    private var textSegments: [String] = []
    private var currentSegmentIndex = 0

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func speak(text: String) {
        stop()

        fullText = text
        textSegments = splitTextIntoSegments(text)
        currentSegmentIndex = 0

        speakNextSegment()
    }

    private func splitTextIntoSegments(_ text: String) -> [String] {
        // Split by sentences to avoid AVSpeechSynthesizer limitations
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var segments: [String] = []
        var currentSegment = ""

        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if currentSegment.count + trimmed.count < 200 {
                currentSegment += trimmed + ". "
            } else {
                if !currentSegment.isEmpty {
                    segments.append(currentSegment)
                }
                currentSegment = trimmed + ". "
            }
        }

        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }

        return segments.isEmpty ? [text] : segments
    }

    private func speakNextSegment() {
        guard currentSegmentIndex < textSegments.count else {
            isPlaying = false
            progress = 1.0
            return
        }

        let segment = textSegments[currentSegmentIndex]
        let utterance = AVSpeechUtterance(string: segment)

        // Configure voice - use Spanish voice
        utterance.voice = AVSpeechSynthesisVoice(language: "es-ES") ?? AVSpeechSynthesisVoice(language: "es-MX")
        utterance.rate = currentRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        currentUtterance = utterance
        synthesizer.speak(utterance)
        isPlaying = true
    }

    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
            isPlaying = false
        }
    }

    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
        } else if !synthesizer.isSpeaking {
            speakNextSegment()
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        progress = 0.0
        currentSegmentIndex = 0
        currentWordRange = nil
    }

    func changeRate(_ newRate: Float) {
        currentRate = max(0.2, min(2.0, newRate))

        if synthesizer.isSpeaking || synthesizer.isPaused {
            // Need to restart with new rate
            let wasPlaying = isPlaying
            let currentIndex = currentSegmentIndex

            stop()
            currentSegmentIndex = currentIndex

            if wasPlaying {
                speakNextSegment()
            }
        }
    }

    func skipForward(seconds: TimeInterval = 15) {
        // Skip approximately 15 seconds worth of text
        // Estimate: ~150 words per minute at rate 0.5, so ~37 words per 15 seconds
        let wordsToSkip = Int(37 * (currentRate / 0.5))

        skipSegments(forward: true, wordCount: wordsToSkip)
    }

    func skipBackward(seconds: TimeInterval = 15) {
        let wordsToSkip = Int(37 * (currentRate / 0.5))

        skipSegments(forward: false, wordCount: wordsToSkip)
    }

    private func skipSegments(forward: Bool, wordCount: Int) {
        let wasPlaying = isPlaying
        stop()

        if forward {
            // Skip forward
            currentSegmentIndex = min(currentSegmentIndex + 3, textSegments.count - 1)
        } else {
            // Skip backward
            currentSegmentIndex = max(currentSegmentIndex - 3, 0)
        }

        if wasPlaying {
            speakNextSegment()
        }
    }

    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        let spanishVoices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("es")
        }
        return spanishVoices
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            currentSegmentIndex += 1
            progress = Double(currentSegmentIndex) / Double(textSegments.count)

            if currentSegmentIndex < textSegments.count {
                speakNextSegment()
            } else {
                isPlaying = false
                progress = 1.0
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            currentWordRange = characterRange
        }
    }
}
