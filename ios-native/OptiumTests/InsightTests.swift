import Foundation
import Testing

@testable import Optium

private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Paris")!
    return c
}
private let day0 = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

private func answer(_ day: Int, felt: Bool, measured: ClarityLevel) -> CalibrationRecord {
    CalibrationRecord(
        askedAt: cal.date(byAdding: .day, value: day, to: day0)!,
        feltClear: felt,
        measured: measured
    )
}

// ── Ce que la calibration apprend ──
//
// L'ecart entre le ressenti et la mesure est la seule chose que la
// calibration a a enseigner. En restriction chronique, la somnolence
// ressentie plafonne alors que la performance continue de decliner : les gens
// perdent la capacite de se juger, et c'est cette capacite qu'on entraine.

@Test func sansCalibrationIlNYARienAApprendre() {
    #expect(CalibrationInsight.summary(of: [], calendar: cal) == nil)
}

@Test func uneSeuleCalibrationNeSuffitPas() {
    // Une reponse isolee n'etablit aucune tendance.
    let one = [answer(0, felt: true, measured: .low)]
    #expect(CalibrationInsight.summary(of: one, calendar: cal) == nil)
}

@Test func laSurestimationEstComptee() throws {
    // Se sentir clair alors que la mesure est basse : le cas qui trompe le
    // plus, et le seul que l'application peut nommer.
    let records = (0..<6).map { answer($0, felt: true, measured: .low) }
    let summary = try #require(CalibrationInsight.summary(of: records, calendar: cal))

    #expect(summary.overestimates == 6)
    #expect(summary.underestimates == 0)
    #expect(summary.agreements == 0)
}

@Test func laSousEstimationEstCompteeAPart() throws {
    let records = (0..<6).map { answer($0, felt: false, measured: .high) }
    let summary = try #require(CalibrationInsight.summary(of: records, calendar: cal))

    #expect(summary.underestimates == 6)
    #expect(summary.overestimates == 0)
}

@Test func lAccordCompteAussi() throws {
    let records = [
        answer(0, felt: true, measured: .high),
        answer(1, felt: false, measured: .low),
        answer(2, felt: true, measured: .medium),
    ]
    let summary = try #require(CalibrationInsight.summary(of: records, calendar: cal))

    // Une mesure moyenne ne contredit rien : elle ne compte ni pour ni contre.
    #expect(summary.agreements == 2)
    #expect(summary.overestimates == 0)
    #expect(summary.underestimates == 0)
}

@Test func laPhraseNommeLaTendanceDominante() throws {
    let records = (0..<5).map { answer($0, felt: true, measured: .low) }
        + [answer(5, felt: true, measured: .high)]
    let summary = try #require(CalibrationInsight.summary(of: records, calendar: cal))

    #expect(summary.sentence.contains("clair"))
    // Elle enonce un ecart, elle ne juge pas.
    for banned in ["devrais", "mauvais", "erreur", "tort"] {
        #expect(!summary.sentence.lowercased().contains(banned))
    }
}

@Test func sansEcartLaPhraseLeDitSansFeliciter() throws {
    let records = (0..<4).map { answer($0, felt: true, measured: .high) }
    let summary = try #require(CalibrationInsight.summary(of: records, calendar: cal))

    #expect(summary.overestimates == 0)
    #expect(!summary.sentence.lowercased().contains("bravo"))
    #expect(!summary.sentence.lowercased().contains("félicit"))
}

// ── Depuis combien de temps a ce palier ──
//
// Retrospectif, jamais predictif. « Tu es a Net depuis neuf jours » recompense
// un resultat deja acquis ; « tu passes Net dans six jours » serait un compte
// a rebours vers un score de sommeil, c'est-a-dire le levier meme de
// l'orthosomnie.

private func night(_ day: Int, hours: Double = 8, bed: Double = 23) -> Night {
    let d = cal.date(byAdding: .day, value: day, to: day0)!
    let asleep = d.addingTimeInterval(bed * 3600)
    return Night(asleepAt: asleep, wokeAt: asleep.addingTimeInterval(hours * 3600))
}

@Test func sansAssezDeNuitsAucuneDureeDePalier() {
    let few = (0..<5).map { night($0) }
    #expect(TierHistory.daysAtCurrentTier(nights: few, now: day0, calendar: cal) == nil)
}

@Test func unSommeilStableDonneUneDureeDePalier() throws {
    // Quarante nuits identiques : le palier ne bouge pas.
    let steady = (0..<40).map { night($0) }
    let now = steady.last!.wokeAt.addingTimeInterval(3600)
    let days = try #require(TierHistory.daysAtCurrentTier(nights: steady, now: now, calendar: cal))

    #expect(days >= 5)
}

@Test func laDureeNeDepasseJamaisLHistorique() throws {
    let steady = (0..<40).map { night($0) }
    let now = steady.last!.wokeAt.addingTimeInterval(3600)
    let days = try #require(TierHistory.daysAtCurrentTier(nights: steady, now: now, calendar: cal))

    #expect(days <= 40)
}
