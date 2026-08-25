import Testing

@testable import Optium

// ── Les trois bandes ──
//
// Le lexique n'a aucun ordre intuitif : sans le tableau sous les yeux,
// personne ne sait si *Net* est au-dessus ou en dessous de *Limpide*. Les
// bandes donnent cet ordre par la position, sans ajouter de vocabulaire.

@Test func lesBandesSuiventLOrdreDesPaliers() {
    let ordered = Tier.allCases.sorted()
    for (lower, upper) in zip(ordered, ordered.dropFirst()) {
        #expect(lower.band <= upper.band, "\(lower.word) devrait être sous \(upper.word)")
    }
}

@Test func ilYAExactementTroisBandes() {
    #expect(Set(Tier.allCases.map(\.band)).count == 3)
}

@Test func lesBandesRepartissentLaPopulationEnTroisTiers() {
    // 37 % en haut, 26 % au milieu, 37 % en bas — la répartition UK Biobank.
    var parts = [Int: Int]()
    for tier in Tier.allCases {
        parts[tier.band, default: 0] += tier.populationShare
    }
    #expect(parts[2] == 37)
    #expect(parts[1] == 26)
    #expect(parts[0] == 37)
}

@Test func laBandeNaPasDeNom() {
    // C'est tout son intérêt : nommer les bandes créerait une seconde échelle
    // à trois crans à côté de celle de la clarté, qui ne mesure pas la même
    // chose. Le type est un entier, et ça doit le rester.
    #expect(Tier.crystalline.band == 2)
    #expect(Tier.murky.band == 0)
}
