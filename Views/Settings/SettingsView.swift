import SwiftUI

struct SettingsView: View {
    var healthKitService: HealthKitService
    var routineFileService: RoutineFileService

    var body: some View {
        #if os(macOS)
        TabView {
            RoutineSettingsTab(routineFileService: routineFileService)
                .tabItem {
                    Label("Routines", systemImage: "list.bullet")
                }

            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            if healthKitService.isAvailable {
                HealthSettingsTab(healthKitService: healthKitService)
                    .tabItem {
                        Label("Health", systemImage: "heart.fill")
                    }
            }
        }
        .frame(minWidth: 600, minHeight: 450)
        #else
        NavigationStack {
            List {
                NavigationLink {
                    RoutineSettingsTab(routineFileService: routineFileService)
                        .navigationTitle("Routines")
                } label: {
                    Label("Routines", systemImage: "list.bullet")
                }

                NavigationLink {
                    GeneralSettingsTab()
                        .navigationTitle("General")
                } label: {
                    Label("General", systemImage: "gear")
                }

                if healthKitService.isAvailable {
                    NavigationLink {
                        HealthSettingsTab(healthKitService: healthKitService)
                            .navigationTitle("Health")
                    } label: {
                        Label("Health", systemImage: "heart.fill")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        #endif
    }
}
