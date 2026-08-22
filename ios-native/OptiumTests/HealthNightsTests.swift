import Foundation
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

// ── L'union des intervalles ──
//
// Une montre et un iPhone qui enregistrent la meme nuit produisent deux jeux
// d'echantillons qui se recouvrent. Les additionner doublerait la nuit.

@Test func desIntervallesQuiSeRecouvrentNeFontQuUn() {
    let merged = HealthSleepSource.union(of: [
        at(0, 23)...at(1, 3),
        at(1, 1)...at(1, 7),
    ])
    #expect(merged.count == 1)
    #expect(merged[0].lowerBound == at(0, 23))
    #expect(merged[0].upperBound == at(1, 7))
}

@Test func desIntervallesDisjointsRestentSepares() {
    let merged = HealthSleepSource.union(of: [
        at(0, 23)...at(1, 3),
        at(1, 5)...at(1, 7),
    ])
    #expect(merged.count == 2)
}

@Test func lUnionNeDependPasDeLOrdre() {
    let a = HealthSleepSource.union(of: [at(1, 1)...at(1, 7), at(0, 23)...at(1, 3)])
    let b = HealthSleepSource.union(of: [at(0, 23)...at(1, 3), at(1, 1)...at(1, 7)])
    #expect(a == b)
}

// ── L'amplitude n'est pas la duree ──
//
// Se reveiller quarante minutes a 3 h laisse un trou que le recollage
// franchit. L'ecart coucher-lever comptait ce trou comme du sommeil.

@Test func unReveilIntraNuitNeComptePasCommeDuSommeil() {
    // 23 h → 3 h, puis 3 h 40 → 7 h : sept heures vingt d'amplitude, mais
    // sept heures vingt moins quarante minutes de sommeil.
    let night = Night(
        asleepAt: at(0, 23), wokeAt: at(1, 7),
        measuredSleep: 4 * 3600 + (7 - 3.667) * 3600
    )
    #expect(night.span == 8 * 3600)
    #expect(night.duration < night.span)
    #expect(abs(night.duration - (8 * 3600 - 40 * 60)) < 60)
}

@Test func sansMesureLaDureeVautLAmplitude() {
    // Les nuits deduites du mouvement n'ont qu'un bloc.
    let night = Night(asleepAt: at(0, 23), wokeAt: at(1, 7))
    #expect(night.duration == night.span)
}

// ── Une sieste n'est pas une nuit ──

@Test func laPlusLongueGagnePourUnMemeJour() throws {
    let nap = Night(asleepAt: at(1, 14), wokeAt: at(1, 17.5))
    let real = Night(asleepAt: at(0, 23), wokeAt: at(1, 7))

    let kept = HealthSleepSource.longestPerDay([nap, real], calendar: cal)

    #expect(kept.count == 1)
    let night = try #require(kept.first)
    #expect(night.asleepAt == at(0, 23))
}

@Test func lOrdreDArriveeNeDecidePas() {
    // La sieste arrive en premier dans le tri par date de debut d'echantillon
    // seulement si elle precede ; dans les deux sens, c'est la duree qui
    // tranche.
    let nap = Night(asleepAt: at(1, 14), wokeAt: at(1, 17.5))
    let real = Night(asleepAt: at(0, 23), wokeAt: at(1, 7))

    #expect(HealthSleepSource.longestPerDay([nap, real], calendar: cal)
         == HealthSleepSource.longestPerDay([real, nap], calendar: cal))
}

@Test func deuxJoursDistinctsGardentChacunLeurNuit() {
    let first = Night(asleepAt: at(0, 23), wokeAt: at(1, 7))
    let second = Night(asleepAt: at(1, 23), wokeAt: at(2, 7))
    #expect(HealthSleepSource.longestPerDay([first, second], calendar: cal).count == 2)
}
