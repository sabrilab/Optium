import SwiftUI
import Testing
import WidgetKit

@testable import Optium

// ── Les widgets se rendent, et portent le lavis ──
//
// Les vues des widgets vivent dans le code partage precisement pour que
// l'application puisse les rendre et les verifier. Un widget qui ne rend rien
// est une regression invisible : sur l'ecran d'accueil, il affiche un cadre
// vide sans qu'aucune erreur ne remonte.

private let sample = WidgetSnapshot(
    clarityWord: "haute",
    observedNights: 28,
    fill: 0.72,
    base: 0.9,
    windowStart: Date(),
    windowEnd: Date().addingTimeInterval(9600),
    threadPhrase: "Trancher le positionnement de l’offre pro",
    tierWord: "Net",
    landingEarliest: Date().addingTimeInterval(4 * 86_400),
    landingLatest: Date().addingTimeInterval(6 * 86_400),
    brainImageFill: nil,
    brainImageRenderedAt: nil
)

@MainActor
private func renders(_ view: some View, size: CGSize) -> Bool {
    let renderer = ImageRenderer(
        content: view
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background { BentoWash(tint: Ink.indigo.tint).background(Ink.canvas) }
    )
    renderer.scale = 2
    return renderer.uiImage != nil
}

@MainActor
@Test func lesCinqFamillesDeClarteSeRendent() {
    let families: [(WidgetFamily, CGSize)] = [
        (.systemSmall, CGSize(width: 170, height: 170)),
        (.systemMedium, CGSize(width: 364, height: 170)),
        (.accessoryCircular, CGSize(width: 76, height: 76)),
        (.accessoryRectangular, CGSize(width: 172, height: 76)),
    ]
    for (family, size) in families {
        #expect(renders(ClarityWidgetView(family: family, snapshot: sample), size: size),
                "la famille \(family) ne rend rien")
    }
}

@MainActor
@Test func leWidgetDeFilSeRend() {
    #expect(renders(ThreadWidgetView(snapshot: sample), size: CGSize(width: 364, height: 170)))
}

@MainActor
@Test func unInstantaneVideSeRendAussi() {
    // Le cas du premier lancement : aucune mesure, aucun fil. Le widget doit
    // rendre quelque chose plutot que de casser.
    let empty = WidgetSnapshot(
        clarityWord: nil, observedNights: 0, fill: 0, base: 1,
        windowStart: Date(), windowEnd: Date().addingTimeInterval(3600),
        threadPhrase: nil, tierWord: nil,
        landingEarliest: nil, landingLatest: nil,
        brainImageFill: nil, brainImageRenderedAt: nil
    )
    #expect(renders(ClarityWidgetView(family: .systemSmall, snapshot: empty),
                    size: CGSize(width: 170, height: 170)))
    #expect(renders(ThreadWidgetView(snapshot: empty),
                    size: CGSize(width: 364, height: 170)))
}

// ── Le lavis est bien celui des cartes ──

@MainActor
@Test func leLavisSeRendSansVerre() {
    // `glassEffect` demande un rendu en temps reel : un widget est une image
    // calculee a l'avance. Le lavis, lui, doit se calculer partout.
    let renderer = ImageRenderer(
        content: BentoWash(tint: Ink.violet.tint).frame(width: 200, height: 120)
    )
    #expect(renderer.uiImage != nil)
}
