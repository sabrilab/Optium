import Foundation
import Testing

@testable import Optium

private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Paris")!
    return c
}
// Un lundi.
private let monday = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

private func night(_ day: Int, bed: Double = 23, hours: Double = 8,
                   origin: Night.Origin = .measured) -> Night {
    let d = cal.date(byAdding: .day, value: day, to: monday)!
    let asleep = cal.startOfDay(for: d).addingTimeInterval(bed * 3600)
    return Night(asleepAt: asleep, wokeAt: asleep.addingTimeInterval(hours * 3600), origin: origin)
}

// ── L'empreinte ──
//
// L'axe part de 18 h et non de minuit : sur un axe de minuit, une nuit
// ordinaire se coupe en deux fragments aux extremites, et l'oeil ne voit plus
// une nuit mais deux morceaux.

@Test func uneNuitOrdinaireTientDUnSeulTenant() throws {
    let rows = NightInsights.raster(nights: [night(0)], calendar: cal)
    let row = try #require(rows.first)

    #expect(row.spans.count == 1, "la nuit est coupee en morceaux")
}

@Test func lEmpreinteSituteLaNuitAuMilieuDeLAxe() throws {
    // Coucher 23 h, lever 7 h, sur un axe qui part de 18 h : la nuit occupe
    // le deuxieme quart au huitieme.
    let row = try #require(NightInsights.raster(nights: [night(0)], calendar: cal).first)
    let span = try #require(row.spans.first)

    #expect(abs(span.lowerBound - 5.0 / 24) < 0.01)
    #expect(abs(span.upperBound - 13.0 / 24) < 0.01)
}

@Test func uneNuitPlusTardiveGlisseVersLaDroite() throws {
    let early = try #require(NightInsights.raster(nights: [night(0, bed: 22)], calendar: cal).first)
    let late = try #require(NightInsights.raster(nights: [night(0, bed: 2)], calendar: cal).first)

    #expect(late.spans[0].lowerBound > early.spans[0].lowerBound)
}

@Test func lEmpreinteRetientLaProvenance() throws {
    let row = try #require(
        NightInsights.raster(nights: [night(0, origin: .inferred)], calendar: cal).first)
    #expect(row.inferred)
}

@Test func lEmpreinteSeLimiteAuNombreDeJoursDemande() {
    let nights = (0..<40).map { night($0) }
    #expect(NightInsights.raster(nights: nights, days: 28, calendar: cal).count == 28)
}

// ── Le milieu de nuit ──

@Test func leMilieuDeNuitEstEntreLeCoucherEtLeLever() {
    // 23 h → 7 h : milieu a 3 h.
    #expect(abs(NightInsights.midSleepHour(night(0), calendar: cal) - 3) < 0.02)
}

@Test func laMoyenneCirculaireNeTombePasAMidi() {
    // 23 h et 1 h : la moyenne est minuit, pas midi.
    let mean = NightInsights.circularMean([23, 1])
    #expect(mean < 0.1 || mean > 23.9)
}

// ── Le decalage social ──

@Test func sansWeekEndAucunDecalage() {
    // Cinq jours ouvres seulement.
    let nights = (0..<5).map { night($0) }
    #expect(NightInsights.socialJetLag(nights: nights, calendar: cal) == nil)
}

@Test func desHorairesIdentiquesDonnentUnDecalageNul() throws {
    let nights = (0..<14).map { night($0) }
    let lag = try #require(NightInsights.socialJetLag(nights: nights, calendar: cal))
    #expect(lag < 60)
}

@Test func seLeverPlusTardLeWeekEndProduitUnDecalage() throws {
    // **La nuit appartient au jour ou l'on se leve**, jamais a celui ou l'on
    // s'est couche : c'est ainsi que le decalage social est groupe, et une
    // nuit de vendredi soir compte pour le samedi.
    let nights = (0..<14).map { offset -> Night in
        let day = cal.date(byAdding: .day, value: offset, to: monday)!
        let weekday = cal.component(.weekday, from: day)
        let isFree = weekday == 1 || weekday == 7
        let wake = cal.startOfDay(for: day).addingTimeInterval((isFree ? 9 : 7) * 3600)
        return Night(asleepAt: wake.addingTimeInterval(-8 * 3600), wokeAt: wake)
    }

    let lag = try #require(NightInsights.socialJetLag(nights: nights, calendar: cal))

    // Deux heures de lever plus tard a duree egale : deux heures de milieu de
    // nuit plus tard.
    #expect(abs(lag - 2 * 3600) < 5 * 60)
}

// ── Les durees ──

@Test func laMedianeEtLesExtremesSontRapportes() throws {
    let nights = [night(0, hours: 5), night(1, hours: 7), night(2, hours: 9)]
    let summary = try #require(NightInsights.durations(nights: nights))

    #expect(abs(summary.median - 7 * 3600) < 1)
    #expect(abs(summary.shortest - 5 * 3600) < 1)
    #expect(abs(summary.longest - 9 * 3600) < 1)
}

@Test func laPartDansLaCibleUtiliseLesBornesDuMoteur() throws {
    // Deux nuits dans 7–9 h, deux en dehors : la moitie.
    let nights = [night(0, hours: 5), night(1, hours: 7.5),
                  night(2, hours: 8.5), night(3, hours: 11)]
    let summary = try #require(NightInsights.durations(nights: nights))
    #expect(abs(summary.inTargetShare - 0.5) < 0.01)
}

@Test func sansNuitAucunResume() {
    #expect(NightInsights.durations(nights: []) == nil)
}

// ── Le cafe ──

@Test func sansAssezDeNuitsDeChaqueCoteAucuneComparaison() {
    let nights = (0..<10).map { night($0) }
    // Un seul cafe tardif : une mediane sur une nuit n'est pas une mediane.
    let coffee = [nights[0].asleepAt.addingTimeInterval(-2 * 3600)]
    #expect(NightInsights.coffeeEffect(nights: nights, coffees: coffee, calendar: cal) == nil)
}

@Test func lesNuitsAvecEtSansCafeSontComparees() throws {
    // Six nuits courtes precedees d'un cafe tardif, six longues sans.
    var nights = [Night](), coffees = [Date]()
    for day in 0..<6 {
        let short = night(day, hours: 6)
        nights.append(short)
        coffees.append(short.asleepAt.addingTimeInterval(-3 * 3600))
    }
    for day in 6..<12 { nights.append(night(day, hours: 8)) }

    let comparison = try #require(
        NightInsights.coffeeEffect(nights: nights, coffees: coffees, calendar: cal))

    #expect(comparison.lateNights == 6)
    #expect(comparison.otherNights == 6)
    #expect(abs(comparison.gap - 2 * 3600) < 60)
}

@Test func unCafeHorsDeLHorizonNeComptePas() throws {
    var nights = [Night](), coffees = [Date]()
    for day in 0..<12 {
        let n = night(day)
        nights.append(n)
        // Douze heures avant le coucher : au-dela du seuil du moteur.
        coffees.append(n.asleepAt.addingTimeInterval(-12 * 3600))
    }
    // Toutes les nuits tombent du meme cote : pas de comparaison possible.
    #expect(NightInsights.coffeeEffect(nights: nights, coffees: coffees, calendar: cal) == nil)
}
