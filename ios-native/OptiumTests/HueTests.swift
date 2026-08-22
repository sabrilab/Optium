import SwiftUI
import Testing
import UIKit

@testable import Optium

// ── Une seule couleur par carte ──
//
// Une contre-teinte a ete introduite pour rendre les cartes vives : un ton
// etranger pose en bas de carte. Elle les rendait surtout multicolores et
// changeait la direction artistique, qui tient a un ton unique diffuse.
//
// La regle est tenue par construction — `accent` est calculee a partir de
// `tint` — mais ces tests la rendent visible si quelqu'un revient a deux
// couleurs choisies a la main.

private func hue(_ color: Color) -> Double {
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return Double(h)
}

private func brightness(_ color: Color) -> Double {
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return Double(b)
}

@Test func chaqueCarteNAQuUneTeinte() {
    for card in Ink.cardHues {
        // La roue est circulaire : entre 0,99 et 0,01 il y a deux centiemes.
        let gap = abs(hue(card.tint) - hue(card.accent))
        #expect(min(gap, 1 - gap) < 0.02,
                "l’accent n’est pas la même couleur que la teinte")
    }
}

@Test func lAccentEstPlusClairPasAutreChose() {
    // Sans ecart de valeur, la carte serait un aplat : l'accent existe pour
    // rallumer une arete, et l'ecart doit etre de clarte.
    for card in Ink.cardHues {
        #expect(brightness(card.accent) > brightness(card.tint))
    }
}

@Test func eclaircirNeDeriveJamaisLaTeinte() {
    for card in Ink.cardHues {
        for amount in [-0.3, -0.1, 0.1, 0.3, 0.5] {
            let gap = abs(hue(card.tint) - hue(card.tint.lightened(by: amount)))
            #expect(min(gap, 1 - gap) < 0.02)
        }
    }
}

@Test func lesSixTeintesSontDistinctes() {
    // Une seule couleur *par carte* ne veut pas dire une seule couleur dans
    // l'application : les six restent sans parente.
    let hues = Ink.cardHues.map { hue($0.tint) }
    for (index, first) in hues.enumerated() {
        for second in hues[(index + 1)...] {
            let gap = abs(first - second)
            #expect(min(gap, 1 - gap) > 0.03)
        }
    }
}
