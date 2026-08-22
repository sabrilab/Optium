import Foundation
import Testing

@testable import Optium

private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    return calendar
}

/// Un jour de reference, a minuit.
private let day0 = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!

/// Une nuit qui commence a `bedHour` le soir du jour `dayOffset` et dure
/// `hours` heures.
private func night(dayOffset: Int, bedHour: Double, hours: Double) -> Night {
    let day = calendar.date(byAdding: .day, value: dayOffset, to: day0)!
    let asleep = day.addingTimeInterval(bedHour * 3600)
    return Night(asleepAt: asleep, wokeAt: asleep.addingTimeInterval(hours * 3600))
}

/// Vingt-huit nuits identiques : coucher a 23 h, huit heures.
private func regularNights() -> [Night] {
    (0..<28).map { night(dayOffset: $0, bedHour: 23, hours: 8) }
}

// ── L'indice de regularite ──

@Test func laRegulariteEstMaximaleQuandLesNuitsSontIdentiques() throws {
    let sri = try #require(SleepRegularity.index(nights: regularNights(), calendar: calendar))

    // Meme etat a vingt-quatre heures d'intervalle, tous les jours : 100.
    #expect(sri > 99)
}

@Test func laRegulariteChuteQuandLesHorairesSautent() throws {
    // Une nuit sur deux decalee de six heures.
    let nights = (0..<28).map { index in
        night(dayOffset: index, bedHour: index.isMultiple(of: 2) ? 23 : 17, hours: 8)
    }

    let sri = try #require(SleepRegularity.index(nights: nights, calendar: calendar))

    #expect(sri < 60)
}

@Test func laRegulariteDUneSeuleNuitNEstPasCalculable() {
    // Il faut deux jours pour comparer deux instants a vingt-quatre heures.
    #expect(SleepRegularity.index(nights: [night(dayOffset: 0, bedHour: 23, hours: 8)],
                                  calendar: calendar) == nil)
}

@Test func laRegulariteResteDansSonIntervalle() throws {
    let chaotic = (0..<28).map { index in
        night(dayOffset: index, bedHour: 14 + Double(index % 11), hours: 4 + Double(index % 5))
    }

    let sri = try #require(SleepRegularity.index(nights: chaotic, calendar: calendar))
    #expect(sri >= 0)
    #expect(sri <= 100)
}

// ── La duree ──

@Test func laDureeMedianeObtientLeMeilleurScore() {
    let score = ClarityEngine.durationScore(lastNight: 8 * 3600, median: 8 * 3600)
    #expect(score > 99)
}

@Test func laDureeEstPenaliseeDansLesDeuxSens() {
    // La relation duree/mortalite est en U : le trop-long compte autant que le
    // trop-court. Ne jamais recompenser lineairement.
    let short = ClarityEngine.durationScore(lastNight: 5 * 3600, median: 8 * 3600)
    let long = ClarityEngine.durationScore(lastNight: 11 * 3600, median: 8 * 3600)

    #expect(short < 70)
    #expect(long < 70)
    #expect(abs(short - long) < 5)
}

// ── La phase circadienne ──

@Test func lePicCircadienSuitLHeureDeLeverHabituelle() {
    let wake = calendar.date(byAdding: .hour, value: 7, to: day0)!
    let engine = CircadianModel(habitualWake: wake, calendar: calendar)

    // Le creux de l'apres-midi doit valoir moins que la fin de matinee.
    let midMorning = calendar.date(byAdding: .hour, value: 10, to: day0)!
    let afternoonDip = calendar.date(byAdding: .hour, value: 15, to: day0)!

    #expect(engine.score(at: midMorning) > engine.score(at: afternoonDip))
}

@Test func laPressionHomeostatiqueFaitBaisserLeScoreEnFinDeJournee() {
    let wake = calendar.date(byAdding: .hour, value: 7, to: day0)!
    let engine = CircadianModel(habitualWake: wake, calendar: calendar)

    let morning = calendar.date(byAdding: .hour, value: 9, to: day0)!
    let lateEvening = calendar.date(byAdding: .hour, value: 23, to: day0)!

    #expect(engine.score(at: morning) > engine.score(at: lateEvening))
}

@Test func laFenetreSOuvreApresLeLeverEtDureQuelquesHeures() {
    let wake = calendar.date(byAdding: .hour, value: 7, to: day0)!
    let engine = CircadianModel(habitualWake: wake, calendar: calendar)

    let window = engine.window(on: day0)

    #expect(window.start > wake)
    #expect(window.duration >= 2 * 3600)
    #expect(window.duration <= 4 * 3600)
    // Elle tombe le matin, pas le soir.
    #expect(calendar.component(.hour, from: window.start) < 12)
}

@Test func unLeverPlusTardifDecaleLaFenetre() {
    let early = CircadianModel(
        habitualWake: calendar.date(byAdding: .hour, value: 6, to: day0)!, calendar: calendar)
    let late = CircadianModel(
        habitualWake: calendar.date(byAdding: .hour, value: 10, to: day0)!, calendar: calendar)

    // Le chronotype decale la courbe : il doit etre appris des levers reels,
    // jamais suppose.
    #expect(late.window(on: day0).start > early.window(on: day0).start)
}

// ── La composition ──

@Test func sansAucuneNuitLaClarteNEstPasAffirmee() {
    let reading = ClarityEngine.reading(nights: [], now: day0, calendar: calendar)

    // Un oracle qui a toujours une reponse ment en permanence.
    #expect(reading.clarity == nil)
}

// Le seuil est passe de quatorze nuits a trois. Les sources rendent leur
// historique des la premiere seconde — HealthKit sur des mois, CoreMotion sur
// sept jours — donc attendre deux semaines rendait l'application muette alors
// que la mesure existait deja. Le detail du seuil est couvert par
// ClarityAbsenceTests.

@Test func unSommeilRegulierEtSuffisantDonneUneClarteHaute() {
    let nights = regularNights()
    // Trois heures apres le lever : encore dans la fenetre.
    let morning = nights.last!.wokeAt.addingTimeInterval(3 * 3600)

    let reading = ClarityEngine.reading(nights: nights, now: morning, calendar: calendar)

    #expect(reading.clarity?.level == .high)
}

@Test func uneNuitCourteApresUnSommeilChaotiqueDonneUneClarteBasse() {
    var nights = (0..<27).map { index in
        night(dayOffset: index, bedHour: 14 + Double(index % 11), hours: 4 + Double(index % 3))
    }
    nights.append(night(dayOffset: 27, bedHour: 3, hours: 4))
    let now = nights.last!.wokeAt.addingTimeInterval(10 * 3600)

    let reading = ClarityEngine.reading(nights: nights, now: now, calendar: calendar)

    #expect(reading.clarity?.level == .low)
}

@Test func laClarteResteDansSonIntervalle() {
    for hours in stride(from: 2.0, through: 13.0, by: 0.5) {
        let nights = (0..<28).map { night(dayOffset: $0, bedHour: 23, hours: hours) }
        let reading = ClarityEngine.reading(nights: nights, now: day0.addingTimeInterval(28 * 86_400),
                                            calendar: calendar)
        let value = try! #require(reading.clarity).value
        #expect(value >= 0)
        #expect(value <= 100)
    }
}

// ── Le cafe ──

@Test func leCafeAbaisseLaNuitProjeteePasLaClarteDuJour() {
    let nights = regularNights()
    let now = nights.last!.wokeAt.addingTimeInterval(3 * 3600)
    let before = ClarityEngine.reading(nights: nights, now: now, calendar: calendar)

    // Une prise tardive : moins de huit heures avant le coucher vise.
    let late = now.addingTimeInterval(10 * 3600)
    let after = ClarityEngine.reading(nights: nights, now: now, coffees: [late], calendar: calendar)

    // La clarte d'aujourd'hui ne bouge pas — le cafe agit sur demain.
    #expect(after.clarity?.value == before.clarity?.value)
    #expect(after.projectedNightPenalty > 0)
}

@Test func unCafeDuMatinNAffectePasLaNuit() {
    let nights = regularNights()
    let now = nights.last!.wokeAt.addingTimeInterval(1 * 3600)

    let reading = ClarityEngine.reading(nights: nights, now: now, coffees: [now], calendar: calendar)

    // Demi-vie de cinq heures : au coucher, il n'en reste presque rien.
    #expect(reading.projectedNightPenalty < 0.05)
}
