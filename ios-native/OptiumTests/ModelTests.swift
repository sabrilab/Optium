import Foundation
import SwiftData
import Testing

@testable import Optium

/// Conteneur en memoire : chaque test part d'une base vide et ne touche pas au disque.
@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema([Project.self, ProjectTask.self, FocusSession.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: config)
    return ModelContext(container)
}

@MainActor
@Test func supprimerUnProjetSupprimeSesTaches() throws {
    let context = try makeContext()
    let project = Project(name: "Memoire", detail: "Rediger le chapitre 2")
    context.insert(project)
    project.tasks.append(ProjectTask(title: "Plan detaille", estimatedPomodoros: 2, order: 0))
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<ProjectTask>()) == 1)

    context.delete(project)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<ProjectTask>()) == 0)
}

@MainActor
@Test func lIncrementBasculeLaTacheEnTermineeAlEstimationAtteinte() throws {
    let context = try makeContext()
    let task = ProjectTask(title: "Relire", estimatedPomodoros: 2, order: 0)
    context.insert(task)

    task.incrementPomodoro()
    #expect(task.completedPomodoros == 1)
    #expect(task.isDone == false)

    task.incrementPomodoro()
    #expect(task.completedPomodoros == 2)
    #expect(task.isDone == true)
}

@MainActor
@Test func lIncrementNeRedescendJamaisUneTacheTerminee() throws {
    let context = try makeContext()
    let task = ProjectTask(title: "Relire", estimatedPomodoros: 1, order: 0)
    context.insert(task)

    task.incrementPomodoro()
    task.incrementPomodoro()

    #expect(task.completedPomodoros == 2)
    #expect(task.isDone == true)
}

@MainActor
@Test func lesSessionsSurviventALaSuppressionDuProjet() throws {
    let context = try makeContext()
    let project = Project(name: "Memoire", detail: "")
    context.insert(project)
    let projectID = project.id
    context.insert(FocusSession(durationSeconds: 1500, isFocus: true, projectID: projectID, taskID: nil))
    try context.save()

    context.delete(project)
    try context.save()

    // L'historique de concentration deja mene ne doit pas disparaitre avec le projet.
    #expect(try context.fetchCount(FetchDescriptor<FocusSession>()) == 1)
}

@Test func laPaletteDeProjetCompteHuitCouleurs() {
    #expect(Project.palette.count == 8)
}
