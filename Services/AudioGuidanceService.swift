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

    #if os(macOS)
    private var speechDelegate: SpeechDelegate?
    #endif

    #if os(iOS)
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var speechGeneration: Int = 0
    #endif

    var soundEnabled: Bool = true
    var voiceGuidanceEnabled: Bool = true
    var repCountingEnabled: Bool = true
    var beepOnlyMode: Bool = false
    var speechRate: Float = 0.5
    var speechVolume: Float = 1.0

    init() {
        #if os(macOS)
        speechDelegate = SpeechDelegate(service: self)
        synthesizer.delegate = speechDelegate
        #endif
    }

    // MARK: - Public Announcements

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
        #if os(iOS)
        speechGeneration += 1
        playerNode?.stop()
        #endif
        isSpeaking = false
    }

    // MARK: - Private Speech

    private func speak(_ text: String) {
        // In beep-only mode, voice is silent — playBeep/playTransitionBeep handle alerts
        if beepOnlyMode { return }
        #if os(iOS)
        speakiOS(text)
        #else
        speakMacOS(text)
        #endif
    }

    // MARK: - iOS: Render speech to buffers + play via AVAudioEngine
    // AVSpeechSynthesizer.speak() hijacks the AVAudioSession on iOS, overriding
    // .mixWithOthers and cutting other apps' audio (YouTube, podcasts, etc.).
    // By using write() we render speech to PCM buffers without touching the session,
    // then play them ourselves through AVAudioEngine with full control.

    #if os(iOS)
    private func speakiOS(_ text: String) {
        playerNode?.stop()
        speechGeneration += 1
        let currentGeneration = speechGeneration

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = speechVolume

        isSpeaking = true

        let collector = BufferCollector()

        synthesizer.write(utterance) { [weak self] buffer in
            guard let self = self else { return }
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
            guard self.speechGeneration == currentGeneration else { return }

            if pcmBuffer.frameLength == 0 {
                let buffers = collector.buffers
                DispatchQueue.main.async {
                    guard self.speechGeneration == currentGeneration else {
                        self.isSpeaking = false
                        return
                    }
                    self.playCollectedBuffers(buffers, generation: currentGeneration)
                }
                return
            }

            collector.append(pcmBuffer)
        }
    }

    private func playCollectedBuffers(_ buffers: [AVAudioPCMBuffer], generation: Int) {
        guard !buffers.isEmpty, let format = buffers.first?.format else {
            isSpeaking = false
            return
        }

        ensureAudioEngine(format: format)

        guard let player = playerNode else {
            isSpeaking = false
            return
        }

        if !player.isPlaying {
            player.play()
        }

        for (index, buffer) in buffers.enumerated() {
            if index == buffers.count - 1 {
                player.scheduleBuffer(buffer) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self, self.speechGeneration == generation else { return }
                        self.isSpeaking = false
                    }
                }
            } else {
                player.scheduleBuffer(buffer)
            }
        }
    }

    private func ensureAudioEngine(format: AVAudioFormat) {
        if let engine = audioEngine, engine.isRunning {
            return
        }

        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            player.play()
            self.audioEngine = engine
            self.playerNode = player
        } catch {
            self.isSpeaking = false
        }
    }
    #endif

    // MARK: - macOS: Standard AVSpeechSynthesizer (no audio session issues)

    #if os(macOS)
    private func speakMacOS(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = speechVolume
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    #endif
}

/// Thread-safe collector for PCM buffers from AVSpeechSynthesizer.write()
private final class BufferCollector: @unchecked Sendable {
    private var _buffers: [AVAudioPCMBuffer] = []
    private let lock = NSLock()

    var buffers: [AVAudioPCMBuffer] {
        lock.lock()
        defer { lock.unlock() }
        return _buffers
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        _buffers.append(buffer)
    }
}

#if os(macOS)
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
