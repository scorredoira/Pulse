import SwiftUI
import SwiftData

struct HealthSettingsTab: View {
    @Query private var settings: [AppSettings]
    var healthKitService: HealthKitService

    private var appSettings: AppSettings? { settings.first }

    var body: some View {
        Form {
            if healthKitService.isAvailable {
                if let settings = appSettings {
                    Section("Apple Health") {
                        Toggle("Sync workouts to Health", isOn: Binding(
                            get: { settings.healthKitEnabled },
                            set: { newValue in
                                if newValue {
                                    requestHealthKitAccess(settings: settings)
                                } else {
                                    settings.healthKitEnabled = false
                                }
                            }
                        ))

                        if settings.healthKitEnabled {
                            Label("Exercises will be logged as workouts in Apple Health", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    Section("Activity Mapping") {
                        VStack(alignment: .leading, spacing: 8) {
                            mappingRow(exercise: "Plank", activity: "Core Training")
                            mappingRow(exercise: "Walk", activity: "Walking")
                            mappingRow(exercise: "Stretch", activity: "Flexibility")
                            mappingRow(exercise: "Push-ups", activity: "Strength Training")
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "HealthKit Not Available",
                    systemImage: "heart.slash",
                    description: Text("HealthKit is not available on this device.")
                )
            }
        }
        .formStyle(.grouped)
    }

    private func mappingRow(exercise: String, activity: String) -> some View {
        HStack {
            Text(exercise)
                .font(.body)
            Spacer()
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .font(.caption)
            Spacer()
            Text(activity)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func requestHealthKitAccess(settings: AppSettings) {
        Task {
            let granted = await healthKitService.requestAuthorization()
            await MainActor.run {
                settings.healthKitEnabled = granted
            }
        }
    }
}
