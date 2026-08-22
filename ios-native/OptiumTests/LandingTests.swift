import Foundation
import Testing

@testable import Optium

private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Paris")!
    return c
}
private let start = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

private func history(_ resumptionsPerThread: [Int]) -> [Int] { resumptionsPerThread }

@Test func sansHistoriqueAucuneEstimationNEstDonnee() {
    // L'IA ne devine jamais une duree. Sans fils fermes, il n'y a rien a
    // extrapoler — et inventer une date serait pire que se taire.
    #expect(LandingEstimator.estimate(closedResumptions: [], openThreads: 3,
                                      dailyCapacity: 4, from: start, calendar: cal) == nil)
}

@Test func sansCapaciteObserveeAucuneEstimationNonPlus() {
    #expect(LandingEstimator.estimate(closedResumptions: [3, 4], openThreads: 2,
                                      dailyCapacity: 0, from: start, calendar: cal) == nil)
}

@Test func lEstimationEstToujoursUneFourchette() throws {
    let landing = try #require(LandingEstimator.estimate(
        closedResumptions: history([2, 3, 4, 6, 8]), openThreads: 4,
        dailyCapacity: 3, from: start, calendar: cal))

    #expect(landing.earliest < landing.latest)
}

@Test func laFourchetteSeResserreQuandLHistoriqueSAccumule() throws {
    // Meme mediane, dispersion moindre : la fourchette doit retrecir.
    let loose = try #require(LandingEstimator.estimate(
        closedResumptions: [1, 2, 4, 8, 16], openThreads: 4,
        dailyCapacity: 3, from: start, calendar: cal))
    let tight = try #require(LandingEstimator.estimate(
        closedResumptions: [3, 4, 4, 4, 5], openThreads: 4,
        dailyCapacity: 3, from: start, calendar: cal))

    let looseSpan = loose.latest.timeIntervalSince(loose.earliest)
    let tightSpan = tight.latest.timeIntervalSince(tight.earliest)
    #expect(tightSpan < looseSpan)
}

@Test func lAjoutDePerimetreFaitRemonterLaCourbe() throws {
    let before = try #require(LandingEstimator.estimate(
        closedResumptions: [3, 4, 5], openThreads: 3,
        dailyCapacity: 3, from: start, calendar: cal))
    let after = try #require(LandingEstimator.estimate(
        closedResumptions: [3, 4, 5], openThreads: 6,
        dailyCapacity: 3, from: start, calendar: cal))

    // C'est l'information la plus utile du graphique : elle ne doit jamais
    // etre masquee.
    #expect(after.latest > before.latest)
}

@Test func lEstimationPondereParLesReprisesPasParLeNombreDeFils() throws {
    // Un fil peut valoir vingt fois un autre. Deux fils dont l'historique dit
    // qu'ils prennent dix reprises pesent plus que cinq fils a une reprise.
    let heavy = try #require(LandingEstimator.estimate(
        closedResumptions: [10, 10, 10], openThreads: 2,
        dailyCapacity: 2, from: start, calendar: cal))
    let light = try #require(LandingEstimator.estimate(
        closedResumptions: [1, 1, 1], openThreads: 5,
        dailyCapacity: 2, from: start, calendar: cal))

    #expect(heavy.latest > light.latest)
}

@Test func uneCapaciteFaibleRepousseLAtterrissage() throws {
    let fast = try #require(LandingEstimator.estimate(
        closedResumptions: [4, 4, 4], openThreads: 4,
        dailyCapacity: 8, from: start, calendar: cal))
    let slow = try #require(LandingEstimator.estimate(
        closedResumptions: [4, 4, 4], openThreads: 4,
        dailyCapacity: 1, from: start, calendar: cal))

    #expect(slow.latest > fast.latest)
}
