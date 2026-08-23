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
