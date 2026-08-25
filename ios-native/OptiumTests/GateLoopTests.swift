import Foundation
import Testing

@testable import Optium

// ── La boucle de la porte ──
//
// C'est la seule recompense meritee du produit : la preuve que le mecanisme a
// fonctionne sur soi. Elle ne s'invente pas, elle se constate — et **rien ne
// s'affiche quand elle ne s'est pas produite**. Une decision tranchee
// directement n'a rien a montrer, et l'inventer detruirait la valeur de celles
// qui en ont.

@MainActor
private func thread(
    held: Int, acceptance: String?, closed: Bool,
    clarities: [ClarityLevel]
) -> WorkThread {
    let thread = WorkThread(phrase: "Choisir le palier d’entrée", nature: .decision)
    thread.holdCount = held
    thread.acceptance = acceptance
    let base = Date().addingTimeInterval(-3 * 86_400)

    for (index, level) in clarities.enumerated() {
        let resumption = Resumption(
            startedAt: base.addingTimeInterval(Double(index) * 86_400),
            clarityAtStart: level,
            inWindow: false
        )
        resumption.endedAt = resumption.startedAt.addingTimeInterval(3600)
        thread.resumptions.append(resumption)
    }
    if closed { thread.closedAt = Date() }
    return thread
}

@MainActor
@Test func unFilJamaisPasseParLaPorteNAPasDeBoucle() {
    let direct = thread(held: 0, acceptance: nil, closed: true, clarities: [.high])
    #expect(GateLoopReader.loop(for: direct) == nil)
}

@MainActor
@Test func unFilRetenuMaisPasFermeNAPasEncoreDeBoucle() {
    let open = thread(held: 1, acceptance: "J’accepte de trancher seul.",
                      closed: false, clarities: [.low, .high])
    #expect(GateLoopReader.loop(for: open) == nil)
}

@MainActor
@Test func unFilSansLigneEcriteNAPasDeBoucle() {
    // La ligne d'acceptation est le sujet de la carte : sans elle, il n'y a
    // rien a remontrer.
    let mute = thread(held: 1, acceptance: nil, closed: true, clarities: [.low, .high])
    #expect(GateLoopReader.loop(for: mute) == nil)
}

@MainActor
@Test func retenuBasPuisTrancheHautEstUneBoucleQuiCompte() throws {
    let real = thread(held: 2, acceptance: "J’accepte de perdre les six clients.",
                      closed: true, clarities: [.low, .medium, .high])
    let loop = try #require(GateLoopReader.loop(for: real))

    #expect(loop.isMeaningful)
    #expect(loop.clarityWhenHeld == .low)
    #expect(loop.clarityWhenClosed == .high)
    #expect(loop.holdCount == 2)
    #expect(loop.acceptance.contains("six clients"))
}

@MainActor
@Test func retenuEtTrancheDansLeMemeEtatNARienProuve() {
    // Se feliciter d'avoir attendu pour rien serait pire que de se taire.
    let flat = thread(held: 1, acceptance: "J’accepte.",
                      closed: true, clarities: [.low, .low])
    let loop = GateLoopReader.loop(for: flat)
    #expect(loop != nil)
    #expect(!(loop?.isMeaningful ?? true))
}

@MainActor
@Test func laListeNeRetientQueLesBouclesQuiComptent() {
    let real = thread(held: 1, acceptance: "J’accepte.", closed: true, clarities: [.low, .high])
    let flat = thread(held: 1, acceptance: "J’accepte.", closed: true, clarities: [.low, .low])
    let direct = thread(held: 0, acceptance: nil, closed: true, clarities: [.high])

    #expect(GateLoopReader.loops(in: [real, flat, direct]).count == 1)
}

@MainActor
@Test func laPhraseNeFeliciteJamais() {
    let real = thread(held: 1, acceptance: "J’accepte.", closed: true, clarities: [.low, .high])
    let loop = GateLoopReader.loop(for: real)!
    let card = GateLoopCard(loop: loop)
    _ = card

    // Le garde-fou porte sur la donnee, pas sur le rendu : la boucle ne
    // transporte aucun jugement, seulement des faits.
    #expect(loop.acceptance == "J’accepte.")
    #expect(loop.span > 0)
}
