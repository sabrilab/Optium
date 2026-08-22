import Foundation
import SwiftData
import Testing

@testable import Optium

private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    return calendar
}

private let day0 = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!

private func night(dayOffset: Int, bedHour: Double = 23, hours: Double = 8) -> Night {
    let day = calendar.date(byAdding: .day, value: dayOffset, to: day0)!
    let asleep = day.addingTimeInterval(bedHour * 3600)
    return Night(asleepAt: asleep, wokeAt: asleep.addingTimeInterval(hours * 3600))
}

// ── L'absence de clarte ──
//
// Sous le seuil, la clarte n'existe pas. Elle ne vaut pas « moyenne » par
// defaut : une valeur inventee se propagerait dans le cerveau, dans les
// widgets et jusqu'a la porte, ou elle produirait un refus injustifiable.

@Test func sousLeSeuilLaClarteEstAbsente() {
    let two = (0..<2).map { night(dayOffset: $0) }
    let reading = ClarityEngine.reading(nights: two, now: day0, calendar: calendar)

    #expect(reading.clarity == nil)
    #expect(reading.observedNights == 2)
}

@Test func auSeuilLaClarteApparait() {
    let three = (0..<3).map { night(dayOffset: $0) }
    let last = three.last!.wokeAt.addingTimeInterval(3 * 3600)
    let reading = ClarityEngine.reading(nights: three, now: last, calendar: calendar)

    #expect(reading.clarity != nil)
    #expect(reading.observedNights == 3)
}

@Test func sansAucuneNuitLaFenetreExisteQuandMeme() {
    let reading = ClarityEngine.reading(nights: [], now: day0, calendar: calendar)

    // L'application reste utilisable comme carnet : les fils s'ouvrent et se
    // ferment. Seule la clarte manque.
    #expect(reading.clarity == nil)
    #expect(reading.window.duration > 0)
}

// ── La porte ne s'ouvre pas sans mesure ──

@MainActor
@Test func laPorteResteFermeeSansClarte() throws {
    let schema = Schema([Project.self, WorkThread.self, Resumption.self])
    let container = try ModelContainer(
        for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    let thread = WorkThread(phrase: "Choisir la tarification", nature: .decision)
    context.insert(thread)

    // Un refus sans mesure est pire qu'une absence de refus : on affirmerait
    // une clarte basse sans rien pour l'etayer.
    #expect(thread.closingOutcome(clarity: nil) == .direct)
}

// ── La justification ──
//
// Elle cite la composante dont la contribution manquante est la plus grande :
// celle qui, portee au maximum, aurait le plus change le resultat.

@Test func laJustificationCiteLaDureeQuandLaNuitEstCourte() {
    // Vingt-huit nuits tres regulieres, la derniere tres courte : c'est la
    // duree qui manque, pas la regularite.
    var nights = (0..<27).map { night(dayOffset: $0) }
    nights.append(night(dayOffset: 27, bedHour: 3, hours: 3.5))
    let now = nights.last!.wokeAt.addingTimeInterval(2 * 3600)

    let reading = ClarityEngine.reading(nights: nights, now: now, calendar: calendar)
    let cited = reading.shortfalls.first?.component

    #expect(cited == .duration)
}

@Test func laJustificationCiteLaRegulariteQuandLesHorairesSautent() {
    // Nuits de bonne duree mais horaires chaotiques.
    let nights = (0..<28).map { index in
        night(dayOffset: index, bedHour: index.isMultiple(of: 2) ? 22 : 4, hours: 8)
    }
    let now = nights.last!.wokeAt.addingTimeInterval(2 * 3600)

    let reading = ClarityEngine.reading(nights: nights, now: now, calendar: calendar)
    let cited = reading.shortfalls.first?.component

    #expect(cited == .regularity)
}

@Test func lesManquesSontClassesDuPlusGrandAuPlusPetit() {
    let nights = (0..<28).map { index in
        night(dayOffset: index, bedHour: 22 + Double(index % 3), hours: 5)
    }
    let reading = ClarityEngine.reading(
        nights: nights, now: nights.last!.wokeAt.addingTimeInterval(11 * 3600), calendar: calendar)

    let values = reading.shortfalls.map(\.amount)
    #expect(values == values.sorted(by: >))
    #expect(reading.shortfalls.count == 3)
}

@Test func laJustificationNeCiteJamaisTroisComposantes() {
    let nights = (0..<28).map { index in
        night(dayOffset: index, bedHour: 20 + Double(index % 7), hours: 4 + Double(index % 4))
    }
    let reading = ClarityEngine.reading(
        nights: nights, now: nights.last!.wokeAt.addingTimeInterval(9 * 3600), calendar: calendar)

    #expect(reading.citedShortfalls.count <= 2)
}

@Test func uneSecondeComposanteNEstCiteeQueSiSonManqueEstProche() {
    let nights = (0..<28).map { index in
        night(dayOffset: index, bedHour: 23, hours: 8) }
    var uneven = nights
    uneven[27] = night(dayOffset: 27, bedHour: 23, hours: 3)
    let reading = ClarityEngine.reading(
        nights: uneven, now: uneven.last!.wokeAt.addingTimeInterval(2 * 3600), calendar: calendar)

    // Regularite quasi parfaite, duree tres basse : l'ecart de manque est
    // large, une seule composante doit etre citee.
    let first = reading.shortfalls[0].amount
    let second = reading.shortfalls[1].amount
    #expect(first - second > first * 0.15)
    #expect(reading.citedShortfalls.count == 1)
}

// ── Les faits mesures ──

@Test func laDerniereNuitEstRapporteeTelleQuelle() throws {
    let nights = (0..<5).map { night(dayOffset: $0, bedHour: 23, hours: 6.5) }
    let reading = ClarityEngine.reading(
        nights: nights, now: nights.last!.wokeAt.addingTimeInterval(3600), calendar: calendar)

    let duration = try #require(reading.lastNightDuration)
    #expect(abs(duration - 6.5 * 3600) < 1)
}

@Test func lAmplitudeDesLeversEstUnFaitPasUnScore() throws {
    // Trois levers a 7 h, 8 h et 9 h 10 : amplitude de deux heures dix.
    let nights = [
        night(dayOffset: 0, bedHour: 23, hours: 8),      // lever 7 h
        night(dayOffset: 1, bedHour: 23, hours: 9),      // lever 8 h
        night(dayOffset: 2, bedHour: 23, hours: 10.167), // lever 9 h 10
    ]
    let reading = ClarityEngine.reading(
        nights: nights, now: nights.last!.wokeAt.addingTimeInterval(3600), calendar: calendar)

    let spread = try #require(reading.wakeSpread)
    #expect(abs(spread - 2.167 * 3600) < 120)
}

// ── Ce que la phrase de la porte n'a pas le droit de contenir ──

private func lowReading(now: Date) -> ClarityReading {
    var nights = (0..<27).map { night(dayOffset: $0, bedHour: 20 + Double($0 % 5), hours: 5) }
    nights.append(night(dayOffset: 27, bedHour: 3, hours: 3.5))
    return ClarityEngine.reading(nights: nights, now: now, calendar: calendar)
}

@Test func laPhraseNeContientNiPourcentageNiNote() throws {
    let now = day0.addingTimeInterval(28 * 86_400 + 15 * 3600)
    let sentence = try #require(GateJustification.sentence(for: lowReading(now: now), now: now, calendar: calendar))

    #expect(!sentence.contains("%"))
    #expect(!sentence.contains("/100"))
    #expect(!sentence.contains("sur 100"))
}

@Test func laPhraseNeDitJamaisLeMotClarte() throws {
    let now = day0.addingTimeInterval(28 * 86_400 + 15 * 3600)
    let sentence = try #require(GateJustification.sentence(for: lowReading(now: now), now: now, calendar: calendar))

    // Elle cite un fait mesure ; nommer la clarte reviendrait a justifier le
    // score par lui-meme.
    #expect(!sentence.lowercased().contains("clarté"))
}

@Test func laPhraseNeConseilleNiNeJuge() throws {
    let now = day0.addingTimeInterval(28 * 86_400 + 15 * 3600)
    let sentence = try #require(GateJustification.sentence(for: lowReading(now: now), now: now, calendar: calendar)).lowercased()

    for banned in ["devrais", "essaie", "mauvais", "insuffisant", "trop peu", "attends"] {
        #expect(!sentence.contains(banned), "la phrase contient « \(banned) » : \(sentence)")
    }
}

@Test func sansManqueAucunePhraseNEstProduite() {
    // Rien a citer : mieux vaut se taire qu'inventer un grief.
    let reading = ClarityEngine.reading(nights: [], now: day0, calendar: calendar)
    #expect(GateJustification.sentence(for: reading, now: day0, calendar: calendar) == nil)
}

// ── La provenance des nuits ──
//
// L'application n'affiche que des faits verifiables par l'utilisateur : « tu
// as dormi 5 h 10 » se controle dans Sante. Une nuit deduite du mouvement du
// telephone ne s'y controle pas. Elle etait pourtant enregistree comme mesuree
// et annoncee comme telle — la seule entorse de l'application a sa propre
// regle.

private func inferredNight(dayOffset: Int, bedHour: Double = 23, hours: Double = 8) -> Night {
    let base = night(dayOffset: dayOffset, bedHour: bedHour, hours: hours)
    return Night(asleepAt: base.asleepAt, wokeAt: base.wokeAt, origin: .inferred)
}

@Test func uneLectureEntierementDevineeSeSait() {
    let nights = (0..<28).map { inferredNight(dayOffset: $0) }
    let reading = ClarityEngine.reading(
        nights: nights, now: nights.last!.wokeAt.addingTimeInterval(3600), calendar: calendar)

    #expect(reading.inferredNights == 28)
    #expect(reading.restsOnInference)
}

@Test func uneSeuleNuitMesureeSuffitANePlusReposerSurLaDeduction() {
    var nights = (0..<27).map { inferredNight(dayOffset: $0) }
    nights.append(night(dayOffset: 27))
    let reading = ClarityEngine.reading(
        nights: nights, now: nights.last!.wokeAt.addingTimeInterval(3600), calendar: calendar)

    #expect(reading.inferredNights == 27)
    #expect(!reading.restsOnInference)
}

@Test func laPorteNommeSaSourceQuandElleDevine() throws {
    var nights = (0..<27).map { inferredNight(dayOffset: $0, bedHour: 20 + Double($0 % 5), hours: 5) }
    nights.append(inferredNight(dayOffset: 27, bedHour: 3, hours: 3.5))
    let now = day0.addingTimeInterval(28 * 86_400 + 15 * 3600)
    let reading = ClarityEngine.reading(nights: nights, now: now, calendar: calendar)

    let sentence = try #require(GateJustification.sentence(for: reading, now: now, calendar: calendar))
    #expect(sentence.contains("mouvement de ton téléphone"))
}

@Test func laPorteNeParleDeSourceQueSiElleDevine() throws {
    let now = day0.addingTimeInterval(28 * 86_400 + 15 * 3600)
    let sentence = try #require(
        GateJustification.sentence(for: lowReading(now: now), now: now, calendar: calendar))

    // Mesurees, les nuits se verifient dans Sante : rien a preciser.
    #expect(!sentence.contains("mouvement"))
}

@Test func laProvenanceSurvitAuStockage() {
    let stored = RecordedNight(inferredNight(dayOffset: 0), measured: false)
    #expect(stored.night.origin == .inferred)

    let real = RecordedNight(night(dayOffset: 0), measured: true)
    #expect(real.night.origin == .measured)
}
