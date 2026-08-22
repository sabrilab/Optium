import SwiftData
import SwiftUI

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ClarityStore.self) private var clarityStore
    @Environment(\.dismiss) private var dismiss
    @Query private var nights: [RecordedNight]

    @State private var confirmingErase = false

    private var nightCount: Int { nights.count }

    private var memoryCount: Int { ProjectMemory.all.count }

    private var regularityText: String {
        guard let regularity = clarityStore.reading.regularity else { return "—" }
        return "\(Int(regularity.rounded())) / 100"
    }

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
                LabeledContent("Nuits observées", value: "\(nightCount)")
                    .listRowBackground(row)
                LabeledContent("Régularité") {
                    Text(regularityText).foregroundStyle(.secondary)
                }
                .listRowBackground(row)
            } header: {
                header("Mesure")
            } footer: {
                footer("La clarté est lue du sommeil enregistré, ou déduite du mouvement du téléphone quand il n’y en a pas. Elle a besoin de deux semaines de nuits pour vouloir dire quelque chose.")
            }

            Section {
                Picker("Forcer la clarté", selection: $settings.clarityOverride) {
                    Text("Mesurée").tag(ClarityLevel?.none)
                    ForEach(ClarityLevel.allCases, id: \.self) { level in
                        Text(level.word.capitalized).tag(ClarityLevel?.some(level))
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            } header: {
                header("Développement")
            } footer: {
                footer("La porte ne se déclenche qu’à clarté basse. Attendre une mauvaise nuit pour l’éprouver rendrait toute vérification impraticable.")
            }

            Section {
                LabeledContent("Mémoire des projets", value: "\(memoryCount) fichier\(memoryCount > 1 ? "s" : "")")
                    .listRowBackground(row)
                Button("Tout effacer", role: .destructive) { confirmingErase = true }
                    .listRowBackground(row)
                    .frame(minHeight: 44)
            } header: {
                header("Confidentialité")
            } footer: {
                footer("Rien ne quitte l’appareil. La mémoire est en markdown, dans les fichiers de l’application — lisible, corrigeable, effaçable.")
            }
        }
        .alert("Effacer la mémoire ?", isPresented: $confirmingErase) {
            Button("Annuler", role: .cancel) {}
            Button("Effacer", role: .destructive) { ProjectMemory.eraseAll() }
        } message: {
            Text("Les lignes écrites à la fermeture de tes fils seront perdues. Les fils eux-mêmes restent.")
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
