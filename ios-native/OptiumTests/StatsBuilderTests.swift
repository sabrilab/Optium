import Foundation
import Testing

@testable import Optium

private let reference = Date(timeIntervalSince1970: 1_760_000_000)

private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    return calendar
}

/// Une session de concentration placee il y a `daysAgo` jours.
@MainActor
private func session(daysAgo: Int, minutes: Int, isFocus: Bool = true) -> FocusSession {
    let day = calendar.date(byAdding: .day, value: -daysAgo, to: reference)!
    return FocusSession(
        durationSeconds: minutes * 60,
        isFocus: isFocus,
        projectID: nil,
        taskID: nil,
        createdAt: day
    )
}

@MainActor
@Test func laFenetreCouvreQuatorzeJours() {
    let stats = StatsBuilder.build(sessions: [], today: reference, calendar: calendar)
    #expect(stats.days.count == 14)
}

@MainActor
@Test func lesSessionsDuJourSontComptees() {
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 0, minutes: 25), session(daysAgo: 0, minutes: 25)],
        today: reference, calendar: calendar
    )

    #expect(stats.todayCount == 2)
    #expect(stats.todaySeconds == 50 * 60)
}

@MainActor
@Test func lesPausesNeComptentPasCommeDuTravail() {
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 0, minutes: 25), session(daysAgo: 0, minutes: 5, isFocus: false)],
        today: reference, calendar: calendar
    )

    #expect(stats.todayCount == 1)
    #expect(stats.todaySeconds == 25 * 60)
}

@MainActor
@Test func laSerieCompteLesJoursConsecutifs() {
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 0, minutes: 25),
                   session(daysAgo: 1, minutes: 25),
                   session(daysAgo: 2, minutes: 25)],
        today: reference, calendar: calendar
    )

    #expect(stats.streak == 3)
}

@MainActor
@Test func unJourCourantVideNeCassePasLaSerie() {
    // Rien aujourd'hui, mais trois jours d'affilee avant : la serie tient.
    // Sans cette regle, la serie de chacun tomberait a zero chaque matin.
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 1, minutes: 25),
                   session(daysAgo: 2, minutes: 25),
                   session(daysAgo: 3, minutes: 25)],
        today: reference, calendar: calendar
    )

    #expect(stats.streak == 3)
}

@MainActor
@Test func unTrouCasseLaSerie() {
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 0, minutes: 25), session(daysAgo: 2, minutes: 25)],
        today: reference, calendar: calendar
    )

    #expect(stats.streak == 1)
}

@MainActor
@Test func lesMoyennesIgnorentLesJoursSansSession() {
    // Deux jours actifs a 30 min : la moyenne est 30, pas 60/14.
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 0, minutes: 30), session(daysAgo: 5, minutes: 30)],
        today: reference, calendar: calendar
    )

    #expect(stats.averageSeconds == 30 * 60)
    #expect(abs(stats.averageCount - 1.0) < 0.001)
}

@MainActor
@Test func leMeilleurJourEstCeluiDuPlusLongTemps() {
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 0, minutes: 25), session(daysAgo: 3, minutes: 90)],
        today: reference, calendar: calendar
    )

    #expect(stats.best?.seconds == 90 * 60)
}

@MainActor
@Test func sansAucuneSessionToutEstNeutre() {
    let stats = StatsBuilder.build(sessions: [], today: reference, calendar: calendar)

    #expect(stats.streak == 0)
    #expect(stats.todaySeconds == 0)
    #expect(stats.averageSeconds == 0)
    #expect(stats.best == nil)
}

@MainActor
@Test func lesSessionsHorsFenetreSontIgnorees() {
    let stats = StatsBuilder.build(
        sessions: [session(daysAgo: 30, minutes: 60)],
        today: reference, calendar: calendar
    )

    #expect(stats.days.allSatisfy { $0.seconds == 0 })
    #expect(stats.best == nil)
}
