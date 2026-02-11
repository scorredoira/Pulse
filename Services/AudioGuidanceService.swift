import AVFoundation
#if os(macOS)
import AppKit
#else
import AudioToolbox
#endif

@Observable
final class AudioGuidanceService {
    var isSpeaking: Bool = false

    #if os(macOS)
    private let synthesizer = NSSpeechSynthesizer()
    private var speechDelegate: NSSpeechDelegate?
    #else
    private let synthesizer = AVSpeechSynthesizer()
    private var speechDelegate: SpeechDelegate?
    #endif
    private var audioPlayer: AVAudioPlayer?

    var soundEnabled: Bool = true
    var voiceGuidanceEnabled: Bool = true
    var speechRate: Float = 0.5
    var speechVolume: Float = 1.0

    init() {
        #if os(macOS)
        speechDelegate = NSSpeechDelegate(service: self)
        synthesizer.delegate = speechDelegate
        #else
        speechDelegate = SpeechDelegate(service: self)
        synthesizer.delegate = speechDelegate
        #endif
    }

    func announceExercise(name: String, duration: Int) {
        guard voiceGuidanceEnabled else { return }
        speak("\(name). \(TimeFormatting.spokenDuration(duration)). Go!")
    }

    func announceExerciseWithSets(name: String, duration: Int, set: Int, totalSets: Int) {
        guard voiceGuidanceEnabled else { return }
        speak("\(name). Set \(set) of \(totalSets). \(TimeFormatting.spokenDuration(duration)). Go!")
    }

    func announceRest(duration: Int) {
        guard voiceGuidanceEnabled else { return }
        speak("Rest. \(TimeFormatting.spokenDuration(duration)).")
    }

    func announceCountdown(_ seconds: Int) {
        guard voiceGuidanceEnabled else { return }
        speak("\(seconds)")
    }

    func announceExerciseComplete() {
        guard voiceGuidanceEnabled else { return }
        speak("Done! Well done.")
    }

    func announceSessionComplete(totalExercises: Int, totalMinutes: Int) {
        guard voiceGuidanceEnabled else { return }
        speak("Session complete! \(totalExercises) exercises in \(totalMinutes) minutes. Great job!")
    }

    func announceWorkIntervalComplete() {
        guard voiceGuidanceEnabled else { return }
        speak("Time to move! Let's do some exercises.")
    }

    func playBeep() {
        guard soundEnabled else { return }
        #if os(macOS)
        NSSound.beep()
        #else
        AudioServicesPlaySystemSound(1057)
        #endif
    }

    func playTransitionBeep() {
        guard soundEnabled else { return }
        #if os(macOS)
        if let sound = NSSound(named: "Tink") {
            sound.play()
        } else {
            NSSound.beep()
        }
        #else
        AudioServicesPlaySystemSound(1057)
        #endif
    }

    func stop() {
        #if os(macOS)
        synthesizer.stopSpeaking()
        #else
        synthesizer.stopSpeaking(at: .immediate)
        #endif
        isSpeaking = false
    }

    private func speak(_ text: String) {
        #if os(macOS)
        synthesizer.stopSpeaking()
        synthesizer.volume = speechVolume
        synthesizer.rate = nsSpeechRate(from: speechRate)
        isSpeaking = true
        synthesizer.startSpeaking(text)
        #else
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = speechVolume
        isSpeaking = true
        synthesizer.speak(utterance)
        #endif
    }

    #if os(macOS)
    /// Convert AVSpeechUtterance-style rate (0.0–1.0) to NSSpeechSynthesizer rate (words per minute).
    private func nsSpeechRate(from rate: Float) -> Float {
        // Map 0.3–0.7 range (our slider) roughly to 150–300 wpm.
        // NSSpeechSynthesizer default rate is ~180–200 wpm.
        let minWPM: Float = 150
        let maxWPM: Float = 300
        let clamped = min(max(rate, Constants.minimumSpeechRate), Constants.maximumSpeechRate)
        let normalized = (clamped - Constants.minimumSpeechRate) / (Constants.maximumSpeechRate - Constants.minimumSpeechRate)
        return minWPM + normalized * (maxWPM - minWPM)
    }
    #endif
}

#if os(macOS)
private final class NSSpeechDelegate: NSObject, NSSpeechSynthesizerDelegate {
    weak var service: AudioGuidanceService?

    init(service: AudioGuidanceService) {
        self.service = service
    }

    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        DispatchQueue.main.async {
            self.service?.isSpeaking = false
        }
    }
}
#else
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var service: AudioGuidanceService?

    init(service: AudioGuidanceService) {
        self.service = service
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.service?.isSpeaking = false
        }
    }
}
#endif
