import AVFoundation
import Observation

/// Speaks an entry aloud with the system voice. A shared singleton so a note
/// keeps reading until you stop it.
@Observable
final class ReadAloud: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = ReadAloud()

    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Toggle: start reading the text, or stop if already speaking.
    func toggle(_ text: String) {
        if synthesizer.isSpeaking {
            stop()
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.96
        utterance.postUtteranceDelay = 0.1
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}
