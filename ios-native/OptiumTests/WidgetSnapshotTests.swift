import Foundation
import Testing

@testable import Optium

private let now = Date(timeIntervalSince1970: 1_780_000_000)

private func snapshot(fill: Double, graved: Double?, renderedAt: Date?) -> WidgetSnapshot {
    WidgetSnapshot(
        clarityWord: "haute", observedNights: 28, fill: fill, base: 0.9,
        windowStart: now, windowEnd: now.addingTimeInterval(3600),
        threadPhrase: nil, tierWord: nil, landingEarliest: nil, landingLatest: nil,
        brainImageFill: graved, brainImageRenderedAt: renderedAt
    )
}

// ── La peremption de la capture ──
//
// La clarte evolue dans la journee par la composante circadienne, alors que
// l'image reste figee depuis la derniere execution de l'application. Un
// cerveau en decalage avec le mot affiche juste a cote serait pire que pas de
// cerveau.

@Test func uneCaptureRecenteEtConcordanteEstMontree() {
    let s = snapshot(fill: 0.70, graved: 0.71, renderedAt: now.addingTimeInterval(-3600))
    #expect(s.brainImageIsFresh(at: now, fill: 0.70) == true)
}

@Test func unEcartDeRemplissageTropGrandFaitRetomberSurLaSilhouette() {
    let s = snapshot(fill: 0.70, graved: 0.60, renderedAt: now.addingTimeInterval(-60))
    #expect(s.brainImageIsFresh(at: now, fill: 0.70) == false)
}

@Test func uneCaptureDePlusDeSixHeuresFaitRetomberSurLaSilhouette() {
    let s = snapshot(fill: 0.70, graved: 0.70, renderedAt: now.addingTimeInterval(-7 * 3600))
    #expect(s.brainImageIsFresh(at: now, fill: 0.70) == false)
}

@Test func sansCaptureIlNYARienAMontrer() {
    let s = snapshot(fill: 0.70, graved: nil, renderedAt: nil)
    #expect(s.brainImageIsFresh(at: now, fill: 0.70) == false)
}

@Test func leSeuilDEcartEstBienDeTroisCentiemes() {
    let just = snapshot(fill: 0.70, graved: 0.729, renderedAt: now)
    let over = snapshot(fill: 0.70, graved: 0.74, renderedAt: now)

    #expect(just.brainImageIsFresh(at: now, fill: 0.70) == true)
    #expect(over.brainImageIsFresh(at: now, fill: 0.70) == false)
}

// ── Sans mesure, aucune capture n'est produite ──

@MainActor
@Test func aucuneCaptureNEstProduiteSansClarte() {
    // A l'arrivee, le widget doit montrer la silhouette vide plutot qu'un
    // cerveau invente.
    #expect(BrainSnapshot.render(fill: 0, base: 1, isDay: true) == nil)
}
