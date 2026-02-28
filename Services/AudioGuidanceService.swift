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
    private var speechDelegate: SpeechDelegate?
    private var audioPlayer: AVAudioPlayer?

    var soundEnabled: Bool = true
    var voiceGuidanceEnabled: Bool = true
    var repCountingEnabled: Bool = true
    var speechRate: Float = 0.5
    var speechVolume: Float = 1.0

    init() {
        speechDelegate = SpeechDelegate(service: self)
        synthesizer.delegate = speechDelegate
        #if os(iOS)
        configureAudioSession()
        #endif
    }

    #if os(iOS)
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
    #endif

    func announceExercise(name: String, duration: Int) {
        guard voiceGuidanceEnabled else { return }
        speak("\(name). \(TimeFormatting.spokenDuration(duration)).")
    }

    func announceExerciseWithSets(name: String, duration: Int, set: Int, totalSets: Int) {
        guard voiceGuidanceEnabled else { return }
        speak("\(name). \(set) of \(totalSets). \(TimeFormatting.spokenDuration(duration)).")
    }

    func announceExerciseWithReps(name: String, reps: Int) {
        guard voiceGuidanceEnabled else { return }
        speak("\(name). \(reps) repetitions.")
    }

    func announceExerciseWithRepsAndSets(name: String, reps: Int, set: Int, totalSets: Int) {
        guard voiceGuidanceEnabled else { return }
        speak("\(name). Set \(set) of \(totalSets). \(reps) repetitions.")
    }

    func announceRest(duration: Int) {
        guard voiceGuidanceEnabled else { return }
        speak("Rest. \(TimeFormatting.spokenDuration(duration)).")
    }

    func announceRepCount(_ rep: Int) {
        guard voiceGuidanceEnabled, repCountingEnabled else { return }
        speak("\(rep)")
    }

    func announceCountdown(_ seconds: Int) {
        guard voiceGuidanceEnabled else { return }
        speak("\(seconds)")
    }

    func announceExerciseComplete() {
        guard voiceGuidanceEnabled else { return }
        speak("Done!")
    }

    func announceSessionComplete(totalExercises: Int, totalMinutes: Int) {
        guard voiceGuidanceEnabled else { return }
        speak("Session complete! \(totalExercises) exercises in \(totalMinutes) minutes.")
    }

    func announceWorkIntervalComplete() {
        guard voiceGuidanceEnabled else { return }
        speak("Time to move!")
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
