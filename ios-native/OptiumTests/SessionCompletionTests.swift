import Foundation
import SwiftData
import Testing

@testable import Optium

@MainActor
private func makeWorld() throws -> (TimerEngine, AppSettings, ModelContext) {
    let name = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    let settings = AppSettings(defaults: defaults)

    let schema = Schema([Project.self, ProjectTask.self, FocusSession.self])
    let container = try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)

    return (TimerEngine(settings: settings), settings, context)
}

@MainActor
@Test func laSessionTermineeEstEnregistreePourSaDureeTotale() throws {
    let (timer, settings, context) = try makeWorld()
    timer.start()

    let recorded = SessionCompletion.record(
        timer: timer, settings: settings, context: context, tasks: [], coordinate: nil
    )

    #expect(recorded == true)
    let sessions = try context.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions.count == 1)
    #expect(sessions[0].durationSeconds == 25 * 60)
    #expect(sessions[0].isFocus == true)
}

@MainActor
@Test func laSessionTermineeIncrementeLaTacheActive() throws {
    let (timer, settings, context) = try makeWorld()
    let project = Project(name: "Memoire", detail: "")
    context.insert(project)
    let task = ProjectTask(title: "Plan", estimatedPomodoros: 2, order: 0)
    project.tasks.append(task)

    timer.activeProjectID = project.id
    timer.activeTaskID = task.id
    timer.start()

    _ = SessionCompletion.record(
        timer: timer, settings: settings, context: context, tasks: [task], coordinate: nil
    )

    #expect(task.completedPomodoros == 1)
}

@MainActor
@Test func unePauseTermineeNIncrementeAucuneTache() throws {
    let (timer, settings, context) = try makeWorld()
    let task = ProjectTask(title: "Plan", estimatedPomodoros: 2, order: 0)
    context.insert(task)
    timer.activeTaskID = task.id
    timer.switchToRest()

    _ = SessionCompletion.record(
        timer: timer, settings: settings, context: context, tasks: [task], coordinate: nil
    )

    // Se reposer n'est pas travailler.
    #expect(task.completedPomodoros == 0)
    let sessions = try context.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions[0].isFocus == false)
}

@MainActor
@Test func leLieuEstEnregistreQuandIlEstFourni() throws {
    let (timer, settings, context) = try makeWorld()
    timer.start()

    _ = SessionCompletion.record(
        timer: timer, settings: settings, context: context, tasks: [],
        coordinate: (lat: 48.8566, lng: 2.3522)
    )

    let sessions = try context.fetch(FetchDescriptor<FocusSession>())
    #expect(sessions[0].latitude == 48.8566)
    #expect(sessions[0].longitude == 2.3522)
}

@MainActor
@Test func unDeuxiemeAppelNEnregistrePasLaMemeSessionDeuxFois() throws {
    let (timer, settings, context) = try makeWorld()
    timer.start()

    let first = SessionCompletion.record(
        timer: timer, settings: settings, context: context, tasks: [], coordinate: nil
    )
    let second = SessionCompletion.record(
        timer: timer, settings: settings, context: context, tasks: [], coordinate: nil
    )

    // Le minuteur est mis en pause par le premier appel : le second n'a plus rien a enregistrer.
    #expect(first == true)
    #expect(second == false)
    #expect(try context.fetchCount(FetchDescriptor<FocusSession>()) == 1)
}

/// Le dossier Resources est synchronise depuis le disque : on verifie que les
/// fichiers non-Swift y arrivent bien dans le paquet compile.
@Test func leCarillonEstEmbarqueDansLePaquet() {
    #expect(Bundle.main.url(forResource: "chime", withExtension: "wav") != nil)
}
