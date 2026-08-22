import Foundation
import Testing

@testable import Optium

private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Paris")!
    return c
}
private let day0 = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

private func night(_ day: Int, bed: Double, hours: Double) -> Night {
    let d = cal.date(byAdding: .day, value: day, to: day0)!
    let asleep = d.addingTimeInterval(bed * 3600)
    return Night(asleepAt: asleep, wokeAt: asleep.addingTimeInterval(hours * 3600))
}

/// Lecture au meilleur moment de la journee : trois heures apres le lever.
/// Le circadien y est proche du maximum, donc ce qui reste vient du sommeil.
private func atBestHour(_ nights: [Night]) -> Clarity? {
    ClarityEngine.reading(
        nights: nights, now: nights.last!.wokeAt.addingTimeInterval(3 * 3600), calendar: cal
    ).clarity
}

// ── L'indice de regularite n'est pas un pourcentage ──
//
// La moitie de la UK Biobank tient entre 73,8 et 86,3. Lire un SRI comme un
// score sur 100 accorde une mention honorable au cinquieme le moins regulier
// de la population, et tasse toute la distribution vers le haut.

@Test func lesQuartilesPubliesTombentSurLeursRangs() {
    #expect(abs(SleepRegularity.populationScore(73.8) - 25) < 0.01)
    #expect(abs(SleepRegularity.populationScore(81) - 50) < 0.01)
    #expect(abs(SleepRegularity.populationScore(86.3) - 75) < 0.01)
}

@Test func leRangEstMonotoneEtBorne() {
    var previous = -1.0
    for sri in stride(from: 0.0, through: 100.0, by: 0.5) {
        let rank = SleepRegularity.populationScore(sri)
        #expect(rank >= previous)
        #expect(rank >= 0 && rank <= 100)
        previous = rank
    }
}

@Test func unIndiceDuPireQuintileNeVautPasUneMentionHonorable() {
    // 68 designe le cinquieme le moins regulier. Lu brut, il valait 68.
    #expect(SleepRegularity.populationScore(68) < 30)
}

// ── Les seuils separent des profils reellement differents ──
//
// Ce test existe parce que la distribution a deja ete tassee une fois : tous
// les profils, y compris un coucher errant sur huit heures, sortaient en
// clarte haute. Les seuils ne valent que si des profils distincts se
// repartissent de part et d'autre.

@Test func unSommeilExemplaireSortHaut() throws {
    let nights = (0..<28).map { night($0, bed: 23, hours: 7.5) }
    let clarity = try #require(atBestHour(nights))
    #expect(clarity.level == .high)
}

@Test func unCouchageErrantSurHuitHeuresNeSortPasHaut() throws {
    // Coucher entre 19 h et 3 h, nuits de 4 a 7 h : quelle que soit l'heure
    // de lecture, ce profil ne doit jamais etre annonce comme clair.
    let nights = (0..<28).map { night($0, bed: 19 + Double($0 % 9), hours: 4 + Double($0 % 4)) }
    let clarity = try #require(atBestHour(nights))
    #expect(clarity.level != .high)
}

@Test func uneNuitCourteApresUnHistoriqueIrregulierSortBas() throws {
    var nights = (0..<27).map { night($0, bed: 20 + Double($0 % 5), hours: 5) }
    nights.append(night(27, bed: 3, hours: 3.5))
    let clarity = try #require(atBestHour(nights))
    #expect(clarity.level == .low)
}

@Test func lesTroisNiveauxSontAtteignables() throws {
    let exemplaire = (0..<28).map { night($0, bed: 23, hours: 7.5) }
    let moyen = (0..<28).map { night($0, bed: 23 + Double(($0 % 3) - 1), hours: 7.5) }
    var bas = (0..<27).map { night($0, bed: 20 + Double($0 % 5), hours: 5) }
    bas.append(night(27, bed: 3, hours: 3.5))

    let levels = try [exemplaire, moyen, bas].map { try #require(atBestHour($0)).level }
    #expect(Set(levels).count == 3)
}

@Test func laClarteDecroitQuandLaRegulariteSeDegrade() throws {
    // A duree identique, seule l'amplitude des couchers change.
    let values = try [0.0, 0.5, 1.0, 2.0].map { jitter in
        let nights = (0..<28).map { night($0, bed: 23 + Double(($0 % 3) - 1) * jitter, hours: 7.5) }
        return try #require(atBestHour(nights)).value
    }
    #expect(values == values.sorted(by: >))
}
