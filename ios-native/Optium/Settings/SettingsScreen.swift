import SwiftUI

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TimerEngine.self) private var timer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Durées") {
                Stepper("Session · \(settings.focusMinutes) min",
                        value: $settings.focusMinutes, in: 5...90, step: 5)
                Stepper("Pause · \(settings.restMinutes) min",
                        value: $settings.restMinutes, in: 1...30, step: 1)
                Stepper("Pause longue · \(settings.longRestMinutes) min",
                        value: $settings.longRestMinutes, in: 5...45, step: 5)
            }

            Section("Retours") {
                Toggle("Carillon de fin", isOn: $settings.soundEnabled)
                Toggle("Vibrations", isOn: $settings.hapticsEnabled)
            }

            Section {
                Toggle("Enregistrer le lieu", isOn: $settings.locationEnabled)
                Toggle("Visualisation 3D", isOn: $settings.brainEnabled)
            } header: {
                Text("Session")
            } footer: {
                Text("Couper la visualisation économise la batterie.")
            }
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Terminé") { dismiss() }
            }
        }
        // Une duree changee doit se voir tout de suite. On ne touche pas a un
        // minuteur en cours : ce serait perdre la session de l'utilisateur.
        .onChange(of: settings.focusMinutes) { _, _ in
            if !timer.isRunning && timer.mode == .focus { timer.reset(to: .focus) }
        }
        .onChange(of: settings.restMinutes) { _, _ in
            if !timer.isRunning && timer.mode == .rest { timer.reset(to: .rest) }
        }
    }
}
