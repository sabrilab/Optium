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

@MainActor
private func corrected(_ day: Int, wakeShiftMinutes: Double) -> RecordedNight {
    let base = cal.date(byAdding: .day, value: day, to: day0)!
    let announced = cal.startOfDay(for: base).addingTimeInterval(5 * 3600)
    let real = announced.addingTimeInterval(wakeShiftMinutes * 60)

    let night = RecordedNight(
        Night(asleepAt: announced.addingTimeInterval(-6 * 3600), wokeAt: real),
        measured: true
    )
    night.corrected = true
    night.originalWokeAt = announced
    night.originalAsleepAt = announced.addingTimeInterval(-6 * 3600)
    return night
}

// ── Ce que les corrections apprennent ──
//
// Corriger une nuit repare cette nuit-la. Corriger plusieurs fois dans le meme
// sens dit que la source se trompe systematiquement — le cas d'une montre qui
// date le lever d'un reveil bref.

@MainActor
@Test func sousQuatreCorrectionsRienNEstConclu() {
    let nights = (0..<3).map { corrected($0, wakeShiftMinutes: 40) }
    #expect(SleepBias.estimate(from: nights) == nil)
}

@MainActor
@Test func unEcartRepeteEstDetecte() throws {
    let nights = (0..<6).map { corrected($0, wakeShiftMinutes: 40) }
    let estimate = try #require(SleepBias.estimate(from: nights))

    #expect(abs(estimate.wakeShift - 40 * 60) < 60)
    #expect(estimate.sampleCount == 6)
    #expect(estimate.isMeaningful)
}

@MainActor
@Test func unPetitEcartNEstPasSignale() throws {
    // Cinq minutes : du meme ordre que l'imprecision de la mesure elle-meme.
    let nights = (0..<6).map { corrected($0, wakeShiftMinutes: 5) }
    let estimate = try #require(SleepBias.estimate(from: nights))
    #expect(!estimate.isMeaningful)
}

@MainActor
@Test func uneCorrectionAberranteNeDeplacePasLEstimation() throws {
    // Une nuit oubliee puis rattrapee de six heures : la mediane l'ignore, une
    // moyenne aurait ete deplacee pour toujours.
    var nights = (0..<6).map { corrected($0, wakeShiftMinutes: 40) }
    nights.append(corrected(9, wakeShiftMinutes: 360))

    let estimate = try #require(SleepBias.estimate(from: nights))
    #expect(abs(estimate.wakeShift - 40 * 60) < 5 * 60)
}

@MainActor
@Test func lesNuitsNonCorrigeesNeComptentPas() {
    let untouched = (0..<8).map { day -> RecordedNight in
        let base = cal.date(byAdding: .day, value: day, to: day0)!
        return RecordedNight(
            Night(asleepAt: base, wokeAt: base.addingTimeInterval(8 * 3600)),
            measured: true
        )
    }
    #expect(SleepBias.estimate(from: untouched) == nil)
}

@MainActor
@Test func laProvenanceCorrigeePrimeSurLaMesure() {
    let night = corrected(0, wakeShiftMinutes: 40)
    #expect(night.night.origin == .corrected)
}

@Test func laMedianeSurUnNombrePairResteStable() {
    #expect(SleepBias.median([10, 20, 30, 40]) == 30)
    #expect(SleepBias.median([]) == 0)
}
