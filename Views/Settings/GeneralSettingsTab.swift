import SwiftUI
import SwiftData
#if os(macOS)
import ServiceManagement
#endif

struct GeneralSettingsTab: View {
    @Query private var settings: [AppSettings]
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar = false
    @AppStorage("autoStartTimers") private var autoStartTimers = true
    @AppStorage("exerciseWindowAlwaysOnTop") private var exerciseWindowAlwaysOnTop = false

    private var appSettings: AppSettings? { settings.first }

    var body: some View {
        Form {
            if let settings = appSettings {
                Section("Audio") {
                    Toggle("Sound effects", isOn: Binding(
                        get: { settings.soundEnabled },
                        set: { settings.soundEnabled = $0 }
                    ))

                    Toggle("Voice guidance", isOn: Binding(
                        get: { settings.voiceGuidanceEnabled },
                        set: { settings.voiceGuidanceEnabled = $0 }
                    ))

                    if settings.voiceGuidanceEnabled {
                        HStack {
                            Text("Speech rate")
                            Slider(
                                value: Binding(
                                    get: { settings.speechRate },
                                    set: { settings.speechRate = $0 }
                                ),
                                in: Constants.minimumSpeechRate...Constants.maximumSpeechRate,
                                step: 0.05
                            ) {
                                Text("Speech rate")
                            } minimumValueLabel: {
                                Text("Slow")
                                    .font(.caption2)
                            } maximumValueLabel: {
                                Text("Fast")
                                    .font(.caption2)
                            }
                        }

                        HStack {
                            Text("Voice volume")
                            Slider(
                                value: Binding(
                                    get: { settings.speechVolume },
                                    set: { settings.speechVolume = $0 }
                                ),
                                in: 0.1...1.0,
                                step: 0.1
                            ) {
                                Text("Voice volume")
                            } minimumValueLabel: {
                                Text("Low")
                                    .font(.caption2)
                            } maximumValueLabel: {
                                Text("Max")
                                    .font(.caption2)
                            }
                        }
                    }
                }

                #if os(macOS)
                Section("Menu Bar") {
                    Toggle("Show timer in menu bar", isOn: $showTimerInMenuBar)
                }

                Section("Exercise Window") {
                    Toggle("Always on top", isOn: $exerciseWindowAlwaysOnTop)
                }

                Section("Timers") {
                    Toggle("Auto-start timers on launch", isOn: $autoStartTimers)
                }

                Section("System") {
                    Toggle("Launch at login", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { newValue in
                            settings.launchAtLogin = newValue
                            updateLaunchAtLogin(newValue)
                        }
                    ))
                }
                #endif
            }
        }
        .formStyle(.grouped)
    }

    #if os(macOS)
    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
    #endif
}

#Preview {
    GeneralSettingsTab()
}
