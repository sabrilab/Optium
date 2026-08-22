import SwiftUI

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TimerEngine.self) private var timer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        List {
            Section {
                duration("Session", value: $settings.focusMinutes, range: 5...90, step: 5)
                duration("Pause", value: $settings.restMinutes, range: 1...30, step: 1)
                duration("Pause longue", value: $settings.longRestMinutes, range: 5...45, step: 5)
            } header: {
                header("Durées")
            } footer: {
                footer("Une pause longue est offerte toutes les quatre sessions.")
            }

            Section {
                Toggle("Carillon de fin", isOn: $settings.soundEnabled)
                    .listRowBackground(row)
                Toggle("Vibrations", isOn: $settings.hapticsEnabled)
                    .listRowBackground(row)
            } header: {
                header("Retours")
            }

            Section {
                Toggle("Enregistrer le lieu", isOn: $settings.locationEnabled)
                    .listRowBackground(row)
                Toggle("Visualisation 3D", isOn: $settings.brainEnabled)
                    .listRowBackground(row)
            } header: {
                header("Session")
            } footer: {
                footer("Couper la visualisation économise la batterie.")
            }
        }
        .listStyle(.insetGrouped)
        // Les controles restent ceux du systeme — un Toggle maison perdrait le
        // retour haptique, l'accessibilite et l'animation d'Apple. Seule la
        // surface change : fond retire, rangees en verre.
        .scrollContentBackground(.hidden)
        .background(InkBackground())
        .tint(Ink.focusGlow)
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Terminé") { dismiss() }
                    .foregroundStyle(.primary)
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

    /// Une duree : le nombre en chiffres tabulaires, l'unite en retrait.
    /// Le Stepper natif garde son incrementation continue a l'appui long.
    private func duration(
        _ label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(label)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(value.wrappedValue)")
                        .font(.body.weight(.medium))
                        .monospacedDigit()
                    Text("min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listRowBackground(row)
        .frame(minHeight: 44)
    }

    private func header(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(.secondary)
            .padding(.bottom, 2)
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    /// Rangee posee sur le noir : un voile clair tres faible suffit a la
    /// detacher. Un verre complet par rangee empilerait autant de couches de
    /// refraction qu'il y a de lignes, pour un gain nul a cette taille.
    private var row: some View {
        Color.white.opacity(0.045)
    }
}
