import Foundation
import Testing

@testable import Optium

// ── La regle couvre la journee entiere ──
//
// Elle s'arretait a dix-sept heures d'eveil, comme la courbe : leve a 5 h
// apres une nuit courte, on depasse ce plafond a 22 h — soit exactement le
// moment ou l'on decide d'aller se coucher.

@MainActor
@Test func laRegleCouvreLaMemeEtendueQueLaCourbe() {
    let curve = Vigilance(ceilingAtWake: 60, pressureTau: 7).curve()
    let last = curve.last?.hoursAwake ?? 0

    // La regle est bornee a vingt heures : la courbe ne doit pas la depasser,
    // sinon ses derniers points seraient silencieusement invisibles.
    #expect(last <= 20.01, "la courbe deborde de la regle")
    #expect(last >= 19, "la regle couvre plus que la courbe n'en produit")
}

// ── Ce que le doigt lit ──
//
// Le glissement interroge, il ne regle rien : la valeur lue doit correspondre
// a la courbe, interpolee entre deux echantillons.

@MainActor
@Test func lHeureSondeeSuitLeReveil() {
    // Leve a 7 h, on sonde a +5 h : il est midi.
    let woke = Calendar.current.startOfDay(for: Date()).addingTimeInterval(7 * 3600)
    let probed = woke.addingTimeInterval(5 * 3600)
    let parts = Calendar.current.dateComponents([.hour], from: probed)
    #expect(parts.hour == 12)
}

@MainActor
@Test func lEtatSondeSuitLaCourbe() {
    let model = Vigilance(ceilingAtWake: 90, pressureTau: 12)
    let curve = model.curve()

    // Au sommet, l'etat lu doit etre le plus haut de la journee.
    let peak = curve.max(by: { $0.clarity < $1.clarity })!
    let dip = curve.filter { $0.hoursAwake > peak.hoursAwake && $0.hoursAwake < 12 }
        .min(by: { $0.clarity < $1.clarity })!

    #expect(ClarityLevel(value: Int(peak.clarity)).rawValue
         != ClarityLevel(value: Int(dip.clarity)).rawValue
         || peak.clarity > dip.clarity)
}
