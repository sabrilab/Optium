import Foundation
import Testing

@testable import Optium

/// Horloge pilotee : les tests avancent le temps au lieu de l'attendre.
private final class FakeClock {
    var now = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: TimeInterval) { now += seconds }
}

@MainActor
private func makeEngine() -> (TimerEngine, AppSettings, FakeClock) {
    let name = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    let settings = AppSettings(defaults: defaults)
    let clock = FakeClock()
    let engine = TimerEngine(settings: settings, now: { clock.now })
    return (engine, settings, clock)
}

@MainActor
@Test func leMinuteurDemarreSurUneSessionDeConcentration() {
    let (engine, _, _) = makeEngine()

    #expect(engine.mode == .focus)
    #expect(engine.total == 25 * 60)
    #expect(engine.remaining == 25 * 60)
    #expect(engine.isRunning == false)
}

@MainActor
@Test func leTempsSEcouleApresLeDemarrage() {
    let (engine, _, clock) = makeEngine()

    engine.start()
    #expect(engine.isRunning == true)

    clock.advance(60)
    engine.refresh()

    #expect(engine.remaining == 24 * 60)
    #expect(engine.elapsed == 60)
}

@MainActor
@Test func laPauseFigeLeTempsRestant() {
    let (engine, _, clock) = makeEngine()

    engine.start()
    clock.advance(60)
    engine.refresh()
    engine.pause()

    // Le temps continue de passer dans le monde reel, mais le minuteur est arrete.
    clock.advance(3600)
    engine.refresh()

    #expect(engine.remaining == 24 * 60)
    #expect(engine.isRunning == false)
}

@MainActor
@Test func laReprisePartDuTempsRestantEtNonDuTotal() {
    let (engine, _, clock) = makeEngine()

    engine.start()
    clock.advance(60)
    engine.refresh()
    engine.pause()
    engine.start()

    clock.advance(60)
    engine.refresh()

    #expect(engine.remaining == 23 * 60)
}

@MainActor
@Test func leRetourAuPremierPlanRattrapeToutLeTempsDeSuspension() {
    let (engine, _, clock) = makeEngine()

    engine.start()
    // iOS a suspendu le processus : aucun battement n'a eu lieu pendant dix minutes.
    clock.advance(600)
    engine.refresh()

    #expect(engine.remaining == 15 * 60)
}

@MainActor
@Test func leTempsRestantNeDescendJamaisSousZero() {
    let (engine, _, clock) = makeEngine()

    engine.start()
    clock.advance(99_999)
    engine.refresh()

    #expect(engine.remaining == 0)
    #expect(engine.isFinished == true)
}

@MainActor
@Test func ajouterDuTempsProlongeLaSessionSansDecalerLEcoule() {
    let (engine, _, clock) = makeEngine()

    engine.start()
    clock.advance(60)
    engine.refresh()

    engine.addTime(300)

    #expect(engine.total == 25 * 60 + 300)
    #expect(engine.remaining == 24 * 60 + 300)
    #expect(engine.elapsed == 60)
}

@MainActor
@Test func laBasculeEnReposDemarreLaPauseImmediatement() {
    let (engine, _, _) = makeEngine()

    engine.start()
    engine.switchToRest()

    #expect(engine.mode == .rest)
    #expect(engine.total == 5 * 60)
    #expect(engine.isRunning == true)
}

@MainActor
@Test func laQuatriemeSessionOuvreUnePauseLongue() {
    let (engine, settings, _) = makeEngine()

    for _ in 0..<3 {
        engine.switchToRest()
        engine.switchToFocus()
    }
    #expect(engine.total == 25 * 60)

    engine.switchToRest()

    #expect(engine.total == 15 * 60)
    #expect(settings.sessionCount == 4)
}

@MainActor
@Test func laBasculeEnConcentrationNeDemarrePasTouteSeule() {
    let (engine, _, _) = makeEngine()

    engine.switchToRest()
    engine.switchToFocus()

    #expect(engine.mode == .focus)
    #expect(engine.total == 25 * 60)
    #expect(engine.isRunning == false)
}

@MainActor
@Test func changerLaDureeReinitialiseUnMinuteurALArret() {
    let (engine, settings, _) = makeEngine()

    settings.focusMinutes = 50
    engine.reset(to: .focus)

    #expect(engine.total == 50 * 60)
    #expect(engine.remaining == 50 * 60)
}

@MainActor
@Test func laProgressionVaDeZeroAUn() {
    let (engine, _, clock) = makeEngine()

    #expect(engine.progress == 0)

    engine.start()
    clock.advance(25 * 60 / 2)
    engine.refresh()

    #expect(abs(engine.progress - 0.5) < 0.001)
}

@MainActor
@Test func lInstantDeFinEstConnuDesLeDemarrage() {
    let (engine, _, clock) = makeEngine()
    let depart = clock.now

    engine.start()

    // C'est cette date qui sert a programmer la notification de fin.
    #expect(engine.finishesAt == depart.addingTimeInterval(25 * 60))
}

@MainActor
@Test func aLArretAucunInstantDeFinNEstAnnonce() {
    let (engine, _, _) = makeEngine()

    #expect(engine.finishesAt == nil)
}
