import Foundation
import SwiftData

@Model
final class AppSettings {
    var workIntervalMinutes: Int
    var soundEnabled: Bool
    var voiceGuidanceEnabled: Bool
    var speechRate: Float
    var speechVolume: Float
    var healthKitEnabled: Bool
    var launchAtLogin: Bool

    init(
        workIntervalMinutes: Int = 45,
        soundEnabled: Bool = true,
        voiceGuidanceEnabled: Bool = true,
        speechRate: Float = 0.5,
        speechVolume: Float = 1.0,
        healthKitEnabled: Bool = false,
        launchAtLogin: Bool = false
    ) {
        self.workIntervalMinutes = workIntervalMinutes
        self.soundEnabled = soundEnabled
        self.voiceGuidanceEnabled = voiceGuidanceEnabled
        self.speechRate = speechRate
        self.speechVolume = speechVolume
        self.healthKitEnabled = healthKitEnabled
        self.launchAtLogin = launchAtLogin
    }
}
