import Testing
import UIKit

@testable import Optium

// ── Le symbole doit exister ──
//
// `Image(systemName:)` rend une vue vide quand le nom est inconnu : ni erreur,
// ni avertissement, ni trace. Le repere de palier disparaitrait de l'echelle,
// des widgets, de l'ile dynamique et de l'ecran verrouille sans que rien ne le
// signale.

@Test func leSymboleDuRepereExiste() {
    #expect(UIImage(systemName: BrainMark.symbolName) != nil)
}

@Test func cEstLaVariantePleine() {
    // Le trait n'allumait que des contours : le niveau se lisait comme des
    // traits eclaires plutot que comme un remplissage.
    #expect(BrainMark.symbolName.hasSuffix(".fill"))
}

@Test func leGlypheEstPlusLargeQueHaut() {
    // C'est ce qui oblige a mesurer le niveau sur le dessin et non sur le
    // cadre : dans un carre, un palier bas tomberait sous le glyphe.
    let size = UIImage(systemName: BrainMark.symbolName)!.size
    #expect(size.width > size.height)
}
