import SwiftData
import SwiftUI

struct ProjectComposer: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]

    @State private var name = ""
    @State private var detail = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom du projet", text: $name)
                    TextField("Objectif", text: $detail, axis: .vertical)
                        .lineLimit(3...6)
                } footer: {
                    Text("L’objectif décrit ce que le projet doit accomplir.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Ink.canvas.ignoresSafeArea())
            .navigationTitle("Nouveau projet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // La couleur tourne dans la palette selon le nombre de projets, comme
        // dans la version Expo : deux projets voisins ne se ressemblent pas.
        let color = Project.palette[projects.count % Project.palette.count]
        context.insert(Project(name: trimmed, detail: detail.trimmingCharacters(in: .whitespaces), colorHex: color))
        dismiss()
    }
}
