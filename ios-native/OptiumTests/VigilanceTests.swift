import Foundation
import Testing

@testable import Optium

// ── Le modele a deux processus ──
//
// La clarte etait un verdict du matin : un mot pose au reveil qui ne bougeait
// plus. Ces tests fixent les cinq proprietes qui font qu'elle vit desormais
// dans la journee. Les constantes du modele sont calibrees numeriquement ; les
// changer sans repasser ici casse cette structure en silence.

private let good = Vigilance(ceilingAtWake: 98, pressureTau: 13)
private let fair = Vigilance(ceilingAtWake: 78, pressureTau: 10.5)
private let poor = Vigilance(ceilingAtWake: 55, pressureTau: 7)

// ── 1. Le plafond descend dans la journee ──

@Test func lePlafondDescendAuFilDeLaJournee() {
    var previous = Double.infinity
    for hour in stride(from: 0.0, through: 16.0, by: 0.5) {
        let ceiling = good.ceiling(hoursAwake: hour)
        #expect(ceiling <= previous + 0.0001, "le plafond remonte a +\(hour) h")
        previous = ceiling
    }
    // Et il descend d'une quantite visible, pas de deux points.
    #expect(good.ceiling(hoursAwake: 0) - good.ceiling(hoursAwake: 16) > 12)
}

// ── 2. Une nuit courte part plus bas ET descend plus vite ──

@Test func uneMauvaiseNuitPartPlusBas() {
    #expect(poor.ceiling(hoursAwake: 0) < good.ceiling(hoursAwake: 0))
}

@Test func uneMauvaiseNuitDescendPlusVite() {
    // Sur les quatre premieres heures, la chute doit etre plus rapide.
    let goodDrop = good.ceiling(hoursAwake: 0) - good.ceiling(hoursAwake: 4)
    let poorDrop = poor.ceiling(hoursAwake: 0) - poor.ceiling(hoursAwake: 4)
    #expect(poorDrop > goodDrop)
}

// ── 3. L'amplitude croit avec la pression ──

@Test func lAmplitudeCroitAvecLaPression() {
    var previous = -Double.infinity
    for hour in stride(from: 0.0, through: 16.0, by: 1.0) {
        let amplitude = good.amplitude(hoursAwake: hour)
        #expect(amplitude >= previous)
        previous = amplitude
    }
}

@Test func malDormirCreuseLaJourneeAuLieuDeLAplatir() {
    // **C'est la propriete la plus contre-intuitive du modele, et la plus
    // importante.** Une composition multiplicative aplatissait les mauvaises
    // journees ; la litterature dit l'inverse — sous forte pression, le
    // *quand* compte davantage.
    func spread(_ model: Vigilance) -> Double {
        let values = model.curve(from: 0.5, to: 15).map(\.clarity)
        return (values.max() ?? 0) - (values.min() ?? 0)
    }
    #expect(spread(poor) > spread(good))
    #expect(spread(fair) > spread(good))
}

// ── 4. La forme de la journee ──

@Test func lePicTombeEnFinDeMatinee() {
    let peak = good.curve(from: 0.5, to: 15).max(by: { $0.clarity < $1.clarity })!
    // Deux a cinq heures apres le lever : ni a l'instant du reveil — l'inertie
    // l'interdit — ni en pleine apres-midi.
    #expect(peak.hoursAwake >= 2 && peak.hoursAwake <= 5)
}

@Test func lInertieDuReveilEmpecheLePicImmediat() {
    #expect(good.clarity(hoursAwake: 0) < good.clarity(hoursAwake: 3))
}

@Test func unRebondSuitLeCreuxDeLApresMidi() {
    // **Le creux du milieu de journee, pas la descente du soir.** La courbe
    // redescend en fin de soiree ; chercher le minimum jusqu'a +15 h tombe sur
    // le coucher et manque le creux qui nous interesse, celui d'apres-midi.
    let afternoon = good.curve(from: 6, to: 11)
    let dip = afternoon.min(by: { $0.clarity < $1.clarity })!
    #expect(dip.hoursAwake > 6 && dip.hoursAwake < 11, "le creux n'est pas dans l'apres-midi")

    let evening = good.curve(from: dip.hoursAwake, to: 14)
    let rebound = evening.max(by: { $0.clarity < $1.clarity })!

    // C'est ce qui rend une mauvaise journee tenable : il y a quelque chose
    // derriere le creux.
    #expect(rebound.clarity > dip.clarity + 2)
    #expect(rebound.hoursAwake > dip.hoursAwake)
}

@Test func leRebondExisteAussiApresUneMauvaiseNuit() {
    // C'est la raison d'etre du modele : annoncer « tu es en bas » toute la
    // journee etait faux, et surtout inutile.
    let afternoon = poor.curve(from: 6, to: 11)
    let dip = afternoon.min(by: { $0.clarity < $1.clarity })!
    let evening = poor.curve(from: dip.hoursAwake, to: 14)
    let rebound = evening.max(by: { $0.clarity < $1.clarity })!
    #expect(rebound.clarity > dip.clarity + 2)
}

@Test func leRythmeEstIndependantDeLaNuit() {
    // C'est ce qui garantit qu'une mauvaise nuit garde de bons moments.
    for hour in stride(from: 0.0, through: 16.0, by: 2.0) {
        #expect(abs(good.rhythm(hoursAwake: hour) - poor.rhythm(hoursAwake: hour)) < 0.0001)
    }
}

// ── 5. La fenetre est derivee, et se retrecit ──

@Test func laFenetreSeRetrecitApresUneMauvaiseNuit() {
    func duration(_ model: Vigilance) -> Double {
        let w = model.window()
        return w.end - w.start
    }
    #expect(duration(poor) < duration(good))
    #expect(duration(fair) < duration(good))
}

@Test func laFenetreEntoureLeSommetDeLaJournee() {
    let peak = good.curve(from: 0.5, to: 15).max(by: { $0.clarity < $1.clarity })!
    let window = good.window()
    #expect(peak.hoursAwake >= window.start - 0.3)
    #expect(peak.hoursAwake <= window.end + 0.3)
}

@Test func uneJourneeSansSeuilAtteintGardeQuandMemeUneFenetre() {
    // « Ta fenetre est plus etroite aujourd'hui » informe ; « tu n'as aucune
    // fenetre » n'informe pas.
    let window = poor.window()
    #expect(window.end > window.start)
}

// ── L'hysteresis ──

@Test func unSeulPointNeFaitPasBasculer() {
    // 70 est le seuil ; a 71 on ne passe pas encore haut depuis moyenne.
    #expect(ClarityLevel.level(value: 71, previous: .medium) == .medium)
    #expect(ClarityLevel.level(value: 73, previous: .medium) == .high)
}

@Test func onNeRedescendPasAuPremierPointPerdu() {
    #expect(ClarityLevel.level(value: 69, previous: .high) == .high)
    #expect(ClarityLevel.level(value: 66, previous: .high) == .medium)
}

@Test func lHysteresisEmpecheLAllerRetour() {
    // Une valeur qui oscille autour du seuil ne doit pas faire clignoter la
    // porte : refusee puis autorisee puis refusee dans la meme minute.
    var level = ClarityLevel.high
    for value in [71, 69, 71, 68, 70, 69, 71] {
        level = ClarityLevel.level(value: value, previous: level)
    }
    #expect(level == .high)
}

@Test func sansEtatPrecedentLeSeuilSAppliqueSimplement() {
    #expect(ClarityLevel.level(value: 70, previous: nil) == .high)
    #expect(ClarityLevel.level(value: 41, previous: nil) == .low)
}

// ── Le raccordement : la clarte bouge vraiment dans la journee ──
//
// Le moteur pouvait rester juste et l'application rester figee : c'est ce qui
// se passait. Ces tests portent sur `ClarityEngine.reading`, pas sur le
// modele.

private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Paris")!
    return c
}
private let day0 = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

private func night(_ day: Int, bed: Double = 23, hours: Double = 8) -> Night {
    let d = cal.date(byAdding: .day, value: day, to: day0)!
    let asleep = cal.startOfDay(for: d).addingTimeInterval(bed * 3600)
    return Night(asleepAt: asleep, wokeAt: asleep.addingTimeInterval(hours * 3600))
}

private func reading(at hoursAfterWake: Double, nights: [Night]) -> ClarityReading {
    let woke = nights.last!.wokeAt
    return ClarityEngine.reading(
        nights: nights, now: woke.addingTimeInterval(hoursAfterWake * 3600), calendar: cal)
}

@Test func laClarteChangeAuFilDeLaJournee() {
    let nights = (0..<28).map { night($0) }
    let values = [1.0, 3.0, 6.0, 9.0, 12.0].map { reading(at: $0, nights: nights).clarity?.value ?? 0 }

    // Elle etait figee : quatre-vingts pour cent du score venait de la nuit.
    #expect(Set(values).count == values.count, "des valeurs identiques a des heures differentes")
    #expect((values.max() ?? 0) - (values.min() ?? 0) >= 10, "la journee est encore trop plate")
}

@Test func lePlafondRapporteDescendAussi() {
    let nights = (0..<28).map { night($0) }
    let matin = reading(at: 1, nights: nights).ceiling ?? 0
    let soir = reading(at: 14, nights: nights).ceiling ?? 0
    #expect(soir < matin)
}

@Test func laCourbeDuJourEstRapportee() {
    let nights = (0..<28).map { night($0) }
    let curve = reading(at: 3, nights: nights).curve
    #expect(curve.count > 40, "la courbe est trop grossiere pour etre dessinee")
    #expect(curve.allSatisfy { $0.ceiling >= $0.clarity - 0.001 },
            "la clarte passe au-dessus du plafond")
}

@Test func laFenetreRapporteeSuitLaCourbe() {
    // **Ce qui retrecit la fenetre, c'est la duree de la nuit**, qui decide
    // de la vitesse d'accumulation de la pression et donc du creusement de la
    // journee. La regularite, elle, deplace le plafond sans changer la forme :
    // deux nuits de meme duree mais d'horaires differents ont bien la meme
    // largeur de fenetre, et c'est defendable.
    let good = (0..<28).map { night($0, hours: 8) }
    let poor = (0..<28).map { night($0, hours: 4.5) }

    let wide = reading(at: 3, nights: good).window.duration
    let narrow = reading(at: 3, nights: poor).window.duration
    #expect(narrow < wide, "la fenetre ne se retrecit pas apres des nuits courtes")
}

@Test func avantLeLeverOnNEstPasEveilleDepuisMoinsQueRien() {
    let nights = (0..<28).map { night($0) }
    // Consulte a 5 h du matin, avant le lever habituel : on est encore dans la
    // nuit precedente, jamais un nombre d'heures negatif.
    let dawn = cal.startOfDay(for: nights.last!.wokeAt).addingTimeInterval(5 * 3600)
    let r = ClarityEngine.reading(nights: nights, now: dawn, calendar: cal)
    #expect(r.hoursAwake >= 0)
}

@Test func leNiveauRapporteTientCompteDuPrecedent() {
    let nights = (0..<28).map { night($0) }
    let woke = nights.last!.wokeAt
    let plain = ClarityEngine.reading(nights: nights, now: woke.addingTimeInterval(3 * 3600), calendar: cal)

    // Meme instant, mais en venant de « basse » : l'hysteresis doit retenir la
    // montee si la valeur est juste au-dessus du seuil.
    let value = plain.clarity?.value ?? 0
    let held = ClarityEngine.reading(
        nights: nights, now: woke.addingTimeInterval(3 * 3600), calendar: cal, previousLevel: .low)
    if value >= 42 && value < 45 {
        #expect(held.level == .low)
    }
    #expect(plain.level == ClarityLevel(value: value))
}

// ── La teinte suit le sens de variation ──
//
// Encoder le niveau en couleur ferait du verdict l'evenement visuel dominant,
// et le rendrait illisible pour les huit pour cent d'hommes ayant une
// deficience de vision des couleurs. Monter ou descendre, en revanche, n'est
// pas etre bon ou mauvais.

@Test func laPenteEstPositiveQuandLaClarteMonte() {
    let model = Vigilance(ceilingAtWake: 90, pressureTau: 12)
    // Deux heures apres le lever, on monte encore vers le sommet.
    #expect(model.slope(hoursAwake: 1.5) > 0)
}

@Test func laPenteEstNegativeApresLeSommet() {
    let model = Vigilance(ceilingAtWake: 90, pressureTau: 12)
    let peak = model.curve(from: 0.5, to: 15).max(by: { $0.clarity < $1.clarity })!
    #expect(model.slope(hoursAwake: peak.hoursAwake + 2) < 0)
}

@Test func laPenteNeClignotePasAuPassageParZero() {
    // **C'est la raison d'etre du taux plutot que du signe.** Autour du
    // sommet, le signe bascule d'un echantillon a l'autre ; le taux, lui,
    // traverse zero continument.
    let model = Vigilance(ceilingAtWake: 90, pressureTau: 12)
    let peak = model.curve(from: 0.5, to: 15).max(by: { $0.clarity < $1.clarity })!

    var previous = model.slope(hoursAwake: peak.hoursAwake - 1)
    for offset in stride(from: -1.0, through: 1.0, by: 0.1) {
        let current = model.slope(hoursAwake: peak.hoursAwake + offset)
        #expect(abs(current - previous) < 0.25, "saut de teinte a \(offset) h du sommet")
        previous = current
    }
}

@Test func laPenteResteBornee() {
    let model = Vigilance(ceilingAtWake: 55, pressureTau: 7)
    for hour in stride(from: 0.0, through: 20.0, by: 0.5) {
        let slope = model.slope(hoursAwake: hour)
        #expect(slope >= -1 && slope <= 1)
    }
}
