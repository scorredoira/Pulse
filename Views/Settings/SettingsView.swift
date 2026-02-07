import SwiftUI

struct SettingsView: View {
    var healthKitService: HealthKitService

    var body: some View {
        #if os(macOS)
        TabView {
            RoutineSettingsTab()
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
                    RoutineSettingsTab()
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
