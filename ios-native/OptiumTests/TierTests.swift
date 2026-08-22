import Foundation
import Testing

@testable import Optium

// ── Les paliers ──

@Test func lesPaliersSuiventLesSeuilsPublies() {
    #expect(Tier(regularity: 92) == .crystalline)
    #expect(Tier(regularity: 84) == .limpid)
    #expect(Tier(regularity: 79) == .clear)
    #expect(Tier(regularity: 71) == .veiled)
    #expect(Tier(regularity: 55) == .murky)
}

@Test func laMedianeDeLaPopulationTombeDansLePalierMedian() {
    // Mediane 81 sur la UK Biobank : c'est le palier du milieu qui doit
    // l'accueillir, sinon le bareme flatte ou punit tout le monde.
    #expect(Tier(regularity: 81) == .clear)
}

@Test func chaqueMonteeDePalierRemplitDavantageLEmbleme() {
    let ordered: [Tier] = [.murky, .veiled, .clear, .limpid, .crystalline]
    for (lower, higher) in zip(ordered, ordered.dropFirst()) {
        #expect(lower.fill < higher.fill)
    }
}

@Test func lePalierSeCalculeSurLaMedianeGlissante() {
    // Une seule bonne nuit ne fait pas monter : on ne peut pas y arriver par
    // gavage, et on redescend en cas d'arret.
    let mostlyPoor = Array(repeating: 60.0, count: 27) + [98.0]
    #expect(Tier(rollingRegularity: mostlyPoor) == .murky)
}

@Test func sansHistoriqueAucunPalierNEstAttribue() {
    #expect(Tier(rollingRegularity: []) == nil)
}

// ── Les preuves ──

private func thread(nature: ThreadNature, held: Int = 0, inWindow: Int = 0,
                    resumptions: Int = 0, nights: Int = 0) -> ProofFacts.ClosedThread {
    ProofFacts.ClosedThread(nature: nature, holdCount: held, inWindowCount: inWindow,
                            resumptionCount: resumptions, nightsCrossed: nights)
}

@Test func laPreuveDeRetenueDemandeCinqDecisionsRetenues() {
    let four = Array(repeating: thread(nature: .decision, held: 1), count: 4)
    #expect(Proof.restraint.isEarned(by: ProofFacts(threads: four)) == false)

    let five = Array(repeating: thread(nature: .decision, held: 1), count: 5)
    #expect(Proof.restraint.isEarned(by: ProofFacts(threads: five)) == true)
}

@Test func laPreuveDeFenetreDemandeDixDecisionsDAffilee() {
    // Neuf dans la fenetre, puis une hors fenetre : la suite est rompue.
    var threads = Array(repeating: thread(nature: .decision, inWindow: 1, resumptions: 1), count: 9)
    threads.append(thread(nature: .decision, inWindow: 0, resumptions: 1))
    #expect(Proof.window.isEarned(by: ProofFacts(threads: threads)) == false)

    let ten = Array(repeating: thread(nature: .decision, inWindow: 1, resumptions: 1), count: 10)
    #expect(Proof.window.isEarned(by: ProofFacts(threads: ten)) == true)
}

@Test func laPreuveDeTraverseeDemandeUnFilQuiAPasseCinqNuits() {
    #expect(Proof.crossing.isEarned(by: ProofFacts(threads: [thread(nature: .production, nights: 4)])) == false)
    #expect(Proof.crossing.isEarned(by: ProofFacts(threads: [thread(nature: .production, nights: 5)])) == true)
}

@Test func lesPreuvesRecompensentLaRetenueJamaisLeVolume() {
    // Cinquante fils fermes a la chaine, aucun retenu, aucun dans la fenetre :
    // l'acharnement ne debloque rien.
    let grind = Array(repeating: thread(nature: .production, resumptions: 12), count: 50)
    let facts = ProofFacts(threads: grind)

    #expect(Proof.all.allSatisfy { !$0.isEarned(by: facts) })
}

// ── L'assemblage des faits ──

private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Paris")!
    return c
}

private let base = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

private func wake(day: Int, hour: Double) -> Night {
    let d = cal.date(byAdding: .day, value: day, to: base)!
    let up = d.addingTimeInterval(hour * 3600)
    return Night(asleepAt: up.addingTimeInterval(-8 * 3600), wokeAt: up)
}

@Test func lesNuitsRegulieresSeComptentASerreVingtMinutes() {
    // Quatorze levers a moins de vingt minutes d'ecart.
    let steady = (0..<14).map { wake(day: $0, hour: 7 + Double($0 % 2) * 0.2) }
    #expect(ProofFactsBuilder.regularNightStreak(steady, calendar: cal) >= 14)
}

@Test func unLeverDecaleRompLaSerie() {
    var nights = (0..<13).map { wake(day: $0, hour: 7) }
    nights.insert(wake(day: 13, hour: 10), at: 6)
    #expect(ProofFactsBuilder.regularNightStreak(nights, calendar: cal) < 14)
}

@Test func unJourSansCafeApresQuatorzeHeuresCompte() {
    let afternoon = base.addingTimeInterval(15 * 3600)
    let morning = base.addingTimeInterval(9 * 3600)

    #expect(ProofFactsBuilder.soberDays([morning], through: base, days: 1, calendar: cal) == 1)
    #expect(ProofFactsBuilder.soberDays([afternoon], through: base, days: 1, calendar: cal) == 0)
}
