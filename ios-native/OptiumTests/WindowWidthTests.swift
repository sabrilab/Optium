import Foundation
import Testing

@testable import Optium

// ── La fenetre varie continument ──
//
// Elle etait binaire : son plancher valait `max(seuil haute, pic - 8)`, et le
// `max` faisait gagner le seuil de 70 des que le pic tombait sous 78. Toutes
// les nuits mediocres recevaient donc la meme fenetre minimale. Le test
// precedent ne le voyait pas — il ne comparait que deux extremes.

/// La correspondance reelle du moteur : une nuit courte donne un plafond bas
/// **et** une pression rapide. Les faire varier ensemble est la seule facon de
/// tester ce que l'application produit vraiment.
private func tau(for ceiling: Double) -> Double {
    6.5 + (ceiling - 50) / 50 * 7
}

private func width(ceiling: Double) -> Double {
    width(ceiling: ceiling, tau: tau(for: ceiling))
}

private func width(ceiling: Double, tau: Double) -> Double {
    let w = Vigilance(ceilingAtWake: ceiling, pressureTau: tau).window()
    return w.end - w.start
}

@Test func laLargeurVarieAuMilieuDeLaPlage() {
    // C'est precisement la ou le bug se cachait : 76 et en dessous rendaient
    // tous 0,75 h.
    let widths = [64.0, 70, 76, 82, 88].map { width(ceiling: $0) }
    #expect(Set(widths.map { Int($0 * 100) }).count > 1,
            "la fenetre est encore binaire au milieu de la plage")
}

@Test func aucuneNuitNeTombeSurLeMinimumParDefaut() {
    // Le minimum reste un garde-fou, pas le cas ordinaire.
    let onFloor = stride(from: 55.0, through: 95.0, by: 5.0)
        .map { width(ceiling: $0) }
        .count { abs($0 - 0.75) < 0.01 }
    #expect(onFloor <= 1, "\(onFloor) plafonds sur neuf retombent sur le minimum")
}

@Test func uneMauvaiseNuitEtUneNuitMediocreNeSeConfondentPlus() {
    #expect(abs(width(ceiling: 58) - width(ceiling: 78)) > 0.2)
}

@Test func laLargeurCroitAvecLaQualiteDeLaNuit() {
    let poor = width(ceiling: 58, tau: 7)
    let fair = width(ceiling: 78, tau: 10.5)
    let good = width(ceiling: 96, tau: 13)
    #expect(poor < fair)
    #expect(fair < good)
}

// ── La qualification est un fait a part ──

@Test func laQualificationNeChangePasLaLargeur() {
    // Deux journees de largeur comparable peuvent l'une passer la barre et
    // l'autre non : c'est bien deux faits distincts.
    let good = Vigilance(ceilingAtWake: 96, pressureTau: 13)
    let poor = Vigilance(ceilingAtWake: 58, pressureTau: 7)

    #expect(good.windowQualifies)
    #expect(!poor.windowQualifies)
}

@Test func uneJourneeSansSeuilGardeUneFenetreUtile() {
    let poor = Vigilance(ceilingAtWake: 55, pressureTau: 7)
    let w = poor.window()
    #expect(w.end > w.start)
    // Et elle entoure bien le meilleur moment reel de la journee.
    let peak = poor.curve(from: 0.5, to: 15).max(by: { $0.clarity < $1.clarity })!
    #expect(peak.hoursAwake >= w.start - 0.3 && peak.hoursAwake <= w.end + 0.3)
}

// ── La courbe couvre une journee d'eveil longue ──

@Test func laCourbeNeCoupePasLaJourneeDUnMauvaisDormeur() {
    // Leve a 5 h apres une nuit courte, on depasse dix-sept heures d'eveil a
    // 22 h — soit le moment ou l'on decide d'aller se coucher.
    let curve = Vigilance(ceilingAtWake: 60, pressureTau: 7).curve()
    #expect((curve.last?.hoursAwake ?? 0) >= 19)
}
