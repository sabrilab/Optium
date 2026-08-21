import SwiftData
import SwiftUI

struct ProjectsScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var timer

    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    @State private var composingProject = false
    @State private var composingTaskFor: Project?

    var body: some View {
        NavigationStack {
            ScrollView {
                if projects.isEmpty {
                    empty
                } else {
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 12) {
                            ForEach(projects) { project in
                                card(project)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(background)
            .navigationTitle("Projets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        composingProject = true
                    } label: {
                        Label("Nouveau projet", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $composingProject) { ProjectComposer() }
            .sheet(item: $composingTaskFor) { TaskComposer(project: $0) }
        }
    }

    private var background: some View {
        Ink.canvas.ignoresSafeArea()
    }

    private var empty: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Aucun projet")
                .font(.title3.weight(.semibold))
            Text("Créez un projet, puis découpez-le en tâches.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Nouveau projet") { composingProject = true }
                .buttonStyle(.glassProminent)
                .tint(Ink.focusGlow)
                .padding(.top, 4)
        }
        .padding(.top, 120)
        .padding(.horizontal, 40)
    }

    /// Un projet est une carte, teintee de sa propre couleur : c'est ce qui
    /// permet de le reconnaitre d'un coup d'oeil dans une liste.
    private func card(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.title3.weight(.semibold))
                    if !project.tasks.isEmpty {
                        let done = project.tasks.filter(\.isDone).count
                        Text("\(done) sur \(project.tasks.count) terminées")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Menu {
                    Button("Ajouter une tâche") { composingTaskFor = project }
                    Button("Supprimer le projet", role: .destructive) {
                        delete(project)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44, alignment: .trailing)
                }
                .accessibilityLabel("Actions du projet")
            }

            ForEach(project.orderedTasks) { task in
                Button { start(task, in: project) } label: { row(task) }
                    .buttonStyle(.plain)
            }

            Button {
                composingTaskFor = project
            } label: {
                Label("Ajouter une tâche", systemImage: "plus")
                    .font(.footnote.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.glass)
        }
        .padding(18)
        .bentoSurface(tint: Color(hex: project.colorHex), corner: 26)
    }

    private func row(_ task: ProjectTask) -> some View {
        HStack(spacing: 12) {
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(task.isDone ? Ink.marker : Color.white.opacity(0.3))
            Text(task.title)
                .font(.subheadline)
                .strikethrough(task.isDone, color: .secondary)
                .foregroundStyle(task.isDone ? .secondary : .primary)
            Spacer()
            Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .contextMenu {
            Button("Supprimer la tâche", role: .destructive) { delete(task) }
        }
    }

    /// Demarrer une tache la rend active et lance immediatement une session.
    private func start(_ task: ProjectTask, in project: Project) {
        timer.activeTaskID = task.id
        timer.activeProjectID = project.id
        timer.reset(to: .focus)
        timer.start()
    }

    private func delete(_ task: ProjectTask) {
        // Supprimer la tache en cours doit liberer le minuteur, sinon il
        // pointerait vers un objet disparu.
        if timer.activeTaskID == task.id { timer.activeTaskID = nil }
        context.delete(task)
    }

    private func delete(_ project: Project) {
        if timer.activeProjectID == project.id {
            timer.activeProjectID = nil
            timer.activeTaskID = nil
        }
        context.delete(project)
    }
}

extension Color {
    /// Les couleurs de projet sont stockees en hexadecimal : c'est une donnee
    /// du modele, portee telle quelle depuis la version Expo.
    init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt64(cleaned, radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
