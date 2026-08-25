import Foundation
import SwiftData
import Testing

@testable import Optium

private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Paris")!
    return c
}
private let day0 = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

private func at(_ day: Int, _ hour: Double) -> Date {
    cal.date(byAdding: .day, value: day, to: day0)!.addingTimeInterval(hour * 3600)
}

// ── La duree reelle survit au stockage ──
//
// `HealthSleepSource` calculait bien la somme des fragments endormis, `Night`
// la portait — et `RecordedNight` ne l'enregistrait pas. Le getter
// reconstruisait un `Night` sans elle, `duration` retombait sur `span`, et
// chaque reveil de nuit redevenait du sommeil.
//
// Seuls les tests, qui construisent un `Night` a la main, y echappaient : le
// correctif affirme par le commentaire de `Night` n'atteignait jamais la
// production.

@MainActor
@Test func laDureeReelleSurvitAUnAllerRetourEnBase() throws {
    let night = Night(
        asleepAt: at(0, 23), wokeAt: at(1, 7),
        origin: .measured,
        // Huit heures d'amplitude, sept heures vingt de sommeil.
        measuredSleep: 7.33 * 3600
    )
    let stored = RecordedNight(night, measured: true)

    #expect(abs(stored.night.duration - 7.33 * 3600) < 60, "la duree reelle est perdue")
    #expect(abs(stored.night.span - 8 * 3600) < 60)
    #expect(stored.night.duration < stored.night.span)
}

@MainActor
@Test func uneNuitSansDureeMesureeRetombeSurLAmplitude() {
    // Les nuits deduites du mouvement n'ont qu'un bloc.
    let night = Night(asleepAt: at(0, 23), wokeAt: at(1, 7), origin: .inferred)
    let stored = RecordedNight(night, measured: false)

    #expect(stored.sleptSeconds == nil)
    #expect(stored.night.duration == stored.night.span)
}

@MainActor
@Test func uneCorrectionManuelleAnnuleLaDureeMesuree() {
    // Ce que l'utilisateur saisit est un couple coucher-lever : garder a cote
    // une somme de fragments issue d'une lecture qu'il vient de dementir
    // donnerait une nuit dont la duree contredit ses bornes.
    let night = Night(asleepAt: at(0, 23), wokeAt: at(1, 7),
                      origin: .measured, measuredSleep: 6 * 3600)
    let stored = RecordedNight(night, measured: true)
    stored.corrected = true

    #expect(stored.night.duration == stored.night.span)
    #expect(stored.night.origin == .corrected)
}

// ── Les nuits fragmentees ne sont plus amputees ──
//
// Ne garder que l'episode le plus long creditait quelqu'un qui dort 2 h, se
// reveille deux heures, puis dort 4 h, de quatre heures seulement. L'intention
// — une sieste ne doit pas devenir « la nuit » — frappait precisement les
// dormeurs fragmentes.

@Test func deuxEpisodesComptentTousLesDeuxDansLaDuree() throws {
    let first = Night(asleepAt: at(0, 23), wokeAt: at(1, 1), measuredSleep: 2 * 3600)
    let second = Night(asleepAt: at(1, 3), wokeAt: at(1, 7), measuredSleep: 4 * 3600)

    let kept = HealthSleepSource.longestPerDay([first, second], calendar: cal)
    let night = try #require(kept.first)

    #expect(kept.count == 1)
    #expect(abs(night.duration - 6 * 3600) < 60, "les deux heures du premier episode sont jetees")
}

@Test func lEpisodeLePlusLongDonneLHoraire() throws {
    let short = Night(asleepAt: at(0, 23), wokeAt: at(1, 1), measuredSleep: 2 * 3600)
    let long = Night(asleepAt: at(1, 3), wokeAt: at(1, 7), measuredSleep: 4 * 3600)

    let night = try #require(HealthSleepSource.longestPerDay([short, long], calendar: cal).first)

    // Les bornes couvrent l'ensemble rattache — c'est l'amplitude reelle de la
    // nuit, et c'est elle qui situe le sommeil pour l'indice de regularite.
    #expect(night.asleepAt == at(0, 23))
    #expect(night.wokeAt == at(1, 7))
}

@Test func uneSiesteDApresMidiResteExclue() throws {
    let night = Night(asleepAt: at(0, 23), wokeAt: at(1, 7), measuredSleep: 8 * 3600)
    let nap = Night(asleepAt: at(1, 14), wokeAt: at(1, 15.5), measuredSleep: 1.5 * 3600)

    let kept = try #require(HealthSleepSource.longestPerDay([night, nap], calendar: cal).first)

    #expect(abs(kept.duration - 8 * 3600) < 60, "la sieste a ete rattachee a la nuit")
    #expect(kept.wokeAt == at(1, 7))
}

@Test func unReveilNocturneLongResteRattache() throws {
    // Deux heures et demie d'eveil au milieu de la nuit : c'est une nuit
    // fragmentee, pas deux nuits.
    let first = Night(asleepAt: at(0, 22), wokeAt: at(1, 0.5), measuredSleep: 2.5 * 3600)
    let second = Night(asleepAt: at(1, 3), wokeAt: at(1, 7), measuredSleep: 4 * 3600)

    let kept = try #require(HealthSleepSource.longestPerDay([first, second], calendar: cal).first)
    #expect(abs(kept.duration - 6.5 * 3600) < 60)
}

@Test func laDureeNeDepasseJamaisLAmplitude() {
    let first = Night(asleepAt: at(0, 23), wokeAt: at(1, 1), measuredSleep: 2 * 3600)
    let second = Night(asleepAt: at(1, 3), wokeAt: at(1, 7), measuredSleep: 4 * 3600)

    for night in HealthSleepSource.longestPerDay([first, second], calendar: cal) {
        #expect(night.duration <= night.span + 1)
    }
}
