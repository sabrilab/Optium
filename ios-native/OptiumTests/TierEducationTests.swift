import Testing

@testable import Optium

// ── Expliquer, jamais faire monter ──
//
// La frontiere est mince : expliquer ce qu'un palier mesure informe, expliquer
// comment monter d'un cran transforme le sommeil en score a optimiser — le
// mecanisme meme de l'orthosomnie, contre lequel le produit se garde.

@Test func aucuneExplicationNeDonneDeConseil() {
    for tier in Tier.allCases {
        let text = tier.explanation.lowercased()
        for banned in ["devrais", "essaie", "il faut", "pour monter", "améliore",
                      "mieux vaut", "conseil", "objectif de"] {
            #expect(!text.contains(banned), "« \(banned) » dans \(tier.word)")
        }
    }
}

@Test func aucuneExplicationNeJugeLePalier() {
    for tier in Tier.allCases {
        let text = tier.explanation.lowercased()
        for banned in ["mauvais", "bon palier", "meilleur", "pire", "insuffisant", "excellent"] {
            #expect(!text.contains(banned), "« \(banned) » dans \(tier.word)")
        }
    }
}

@Test func chaquePalierExpliqueQuelqueChose() {
    for tier in Tier.allCases {
        #expect(tier.explanation.count > 80)
    }
}

// ── L'indice, traduit ──

@Test func laPartDAccordSuitLaDefinitionDeLIndice() {
    // L'echelle publiee va de -100 a 100, ramenee a 0-100 : la part d'accord
    // vaut (indice + 100) / 2.
    #expect(Tier.crystalline.agreementShare == 94)  // seuil 87
    #expect(Tier.veiled.agreementShare == 84)       // seuil 68
    #expect(Tier.murky.agreementShare == 50)        // seuil 0
}

@Test func lesEtenduesSeSuiventSansTrou() {
    let ordered = Tier.allCases.sorted()
    for (lower, upper) in zip(ordered, ordered.dropFirst()) {
        #expect(lower.range.upperBound == upper.range.lowerBound)
    }
    #expect(ordered.last?.range.upperBound == 100)
    #expect(ordered.first?.range.lowerBound == 0)
}

@Test func lEtenduePlusHauteCommenceAuSeuilLePlusEleve() {
    #expect(Tier.crystalline.range.lowerBound == 87)
    #expect(Tier.crystalline.range.upperBound == 100)
}

// ── L'embleme de l'appel montre le bon palier ──
//
// `ExhibitCard` reconstruisait le palier depuis son libelle affiche —
// `Tier(rawValue: "cristallin")` — alors que les `rawValue` sont les cas
// anglais. La reconstruction renvoyait toujours `nil` et l'embleme affichait
// un remplissage constant de 0,6, quel que soit le palier reel.

@Test func unLibelleFrancaisNeReconstruitPasUnPalier() {
    // Le piege, garde comme trace : c'est ce qui rendait le bug invisible.
    for tier in Tier.allCases {
        #expect(Tier(rawValue: tier.word.lowercased()) == nil)
    }
}

@Test func chaquePalierAUnRemplissageDistinct() {
    let fills = Set(Tier.allCases.map(\.fill))
    #expect(fills.count == Tier.allCases.count)
}
