import Foundation
import Testing

@testable import Optium

private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    return calendar
}

private let day0 = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!

private func span(day: Int, from: Double, to: Double) -> DateInterval {
    let base = calendar.date(byAdding: .day, value: day, to: day0)!
    return DateInterval(start: base.addingTimeInterval(from * 3600),
                        end: base.addingTimeInterval(to * 3600))
}

@Test func laPlusLonguePeriodeImmobileDeLaNuitDevientLaNuit() {
    // Immobile de 23 h a 7 h : huit heures.
    let nights = SleepInference.nights(fromStillPeriods: [span(day: 0, from: 23, to: 31)],
                                       calendar: calendar)

    #expect(nights.count == 1)
    #expect(nights[0].duration == 8 * 3600)
}

@Test func uneImmobiliteDiurneNEstPasUneNuit() {
    // Trois heures immobile en pleine apres-midi : un film, pas un sommeil.
    let nights = SleepInference.nights(fromStillPeriods: [span(day: 0, from: 14, to: 17)],
                                       calendar: calendar)

    #expect(nights.isEmpty)
}

@Test func uneImmobiliteTropCourteNEstPasUneNuit() {
    // Deux heures a 23 h : une sieste devant la television.
    let nights = SleepInference.nights(fromStillPeriods: [span(day: 0, from: 23, to: 25)],
                                       calendar: calendar)

    #expect(nights.isEmpty)
}

@Test func plusieursNuitsSeSuiventSansSeMelanger() {
    let nights = SleepInference.nights(
        fromStillPeriods: [
            span(day: 0, from: 23, to: 31),
            span(day: 1, from: 23.5, to: 31),
            span(day: 2, from: 22.5, to: 30),
        ],
        calendar: calendar
    )

    #expect(nights.count == 3)
}

@Test func laPlusLonguePeriodeLEmporteSurLesReveils() {
    // Un reveil bref coupe la nuit en deux : on retient le plus long segment
    // plutot que d'additionner, faute de savoir si l'entre-deux etait du
    // sommeil ou une insomnie debout.
    let nights = SleepInference.nights(
        fromStillPeriods: [span(day: 0, from: 23, to: 25), span(day: 0, from: 25.5, to: 31)],
        calendar: calendar
    )

    #expect(nights.count == 1)
    #expect(nights[0].duration == 5.5 * 3600)
}

@Test func uneNuitSansAucuneDonneeNestPasInventee() {
    // Telephone laisse dans une autre piece : il ne faut surtout pas la lire
    // comme une nuit parfaitement immobile.
    let nights = SleepInference.nights(fromStillPeriods: [], calendar: calendar)

    #expect(nights.isEmpty)
}

@Test func uneImmobiliteInvraisemblablementLongueEstEcartee() {
    // Vingt heures immobile : le telephone est pose sur un meuble, pas au
    // chevet de quelqu'un qui dort.
    let nights = SleepInference.nights(fromStillPeriods: [span(day: 0, from: 20, to: 40)],
                                       calendar: calendar)

    #expect(nights.isEmpty)
}
