import SwiftUI

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        List {
            Section {
                Toggle("Vibrations", isOn: $settings.hapticsEnabled)
                    .listRowBackground(row)
                Toggle("Visualisation 3D", isOn: $settings.brainEnabled)
                    .listRowBackground(row)
            } header: {
                header("Affichage")
            } footer: {
                footer("Couper la visualisation économise la batterie.")
            }

            Section {
                Picker("Clarté", selection: $settings.simulatedClarity) {
                    ForEach(ClarityLevel.allCases, id: \.self) { level in
                        Text(level.word.capitalized).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            } header: {
                header("Mesure")
            } footer: {
                footer("Réglage temporaire. La clarté sera lue du sommeil et du mouvement ; en attendant, elle se force ici pour que la porte soit éprouvable.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(InkBackground())
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Terminé") { dismiss() }.tint(Ink.control)
            }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(.secondary)
    }

    private func footer(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.tertiary)
    }

    private var row: some View { Color.white.opacity(0.045) }
}
