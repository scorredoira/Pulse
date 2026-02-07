import AVFoundation
#if os(macOS)
import AppKit
#else
import AudioToolbox
#endif

@Observable
final class AudioGuidanceService {
    var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var speechDelegate: SpeechDelegate?

    var soundEnabled: Bool = true
    var voiceGuidanceEnabled: Bool = true
    var speechRate: Float = 0.5
    var speechVolume: Float = 1.0

    init() {
        speechDelegate = SpeechDelegate(service: self)
        synthesizer.delegate = speechDelegate
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
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = speechVolume
        isSpeaking = true
        synthesizer.speak(utterance)
    }
}

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
