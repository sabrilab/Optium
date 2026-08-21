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
            Group {
                if projects.isEmpty {
                    ContentUnavailableView {
                        Label("Aucun projet", systemImage: "folder")
                    } description: {
                        Text("Créez un projet, puis découpez-le en tâches.")
                    } actions: {
                        Button("Nouveau projet") { composingProject = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    list
                }
            }
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

    private var list: some View {
        List {
            ForEach(projects) { project in
                Section {
                    ForEach(project.orderedTasks) { task in
                        Button { start(task, in: project) } label: { row(task) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in delete(offsets, from: project) }

                    Button {
                        composingTaskFor = project
                    } label: {
                        Label("Ajouter une tâche", systemImage: "plus.circle")
                    }
                } header: {
                    Text(project.name)
                } footer: {
                    if !project.tasks.isEmpty {
                        let done = project.tasks.filter(\.isDone).count
                        Text("\(done) sur \(project.tasks.count) tâches terminées")
                    }
                }
            }
            .onDelete(perform: deleteProjects)
        }
    }

    private func row(_ task: ProjectTask) -> some View {
        HStack {
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isDone ? Color.accentColor : Color(.tertiaryLabel))
            Text(task.title)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
    }

    /// Demarrer une tache la rend active et lance immediatement une session.
    private func start(_ task: ProjectTask, in project: Project) {
        timer.activeTaskID = task.id
        timer.activeProjectID = project.id
        timer.reset(to: .focus)
        timer.start()
    }

    private func delete(_ offsets: IndexSet, from project: Project) {
        let ordered = project.orderedTasks
        for index in offsets {
            let task = ordered[index]
            // Supprimer la tache en cours doit liberer le minuteur, sinon il
            // pointerait vers un objet disparu.
            if timer.activeTaskID == task.id { timer.activeTaskID = nil }
            context.delete(task)
        }
    }

    private func deleteProjects(_ offsets: IndexSet) {
        for index in offsets {
            let project = projects[index]
            if timer.activeProjectID == project.id {
                timer.activeProjectID = nil
                timer.activeTaskID = nil
            }
            context.delete(project)
        }
    }
}
