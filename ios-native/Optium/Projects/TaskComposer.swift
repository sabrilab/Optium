import SwiftUI

/// Saisie manuelle d'une tache.
///
/// Sans equivalent dans la version Expo, ou les taches ne naissent que de la
/// generation par IA. Celle-ci etant hors perimetre, cet ecran est ce qui rend
/// le modele tache/pomodoro utilisable.
struct TaskComposer: View {
    let project: Project

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var estimate = 1

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Que faut-il faire ?", text: $title)
                }
                Section {
                    Stepper("\(estimate) session\(estimate > 1 ? "s" : "")", value: $estimate, in: 1...12)
                } header: {
                    Text("Estimation")
                } footer: {
                    Text("Une session dure le temps réglé pour la concentration.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Ink.canvas.ignoresSafeArea())
            .navigationTitle("Nouvelle tâche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { create() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        project.tasks.append(
            ProjectTask(title: trimmed, estimatedPomodoros: estimate, order: project.tasks.count)
        )
        dismiss()
    }
}
