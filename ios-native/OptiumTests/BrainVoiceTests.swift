import Foundation
import Testing

@testable import Optium

// ── Le cerveau parle de lui ──
//
// Les trois questions proposees sont ecrites au « je » de l'utilisateur —
// « qu'est-ce que j'ai appris sur ma facon de travailler ». Le pronom est donc
// pris, et un modele a qui l'on demande par ailleurs de dire « je » pour
// lui-meme tranche la collision en se rabattant sur « tu ». Les faits qu'on lui
// donne doivent etre les siens, sans quoi il ne fait que les rapporter.

private let sample = CallFacts(
    nightCount: 28,
    regularity: 81,
    clarityWord: "haute",
    window: DateInterval(start: Date(), duration: 9600),
    closed: [ClosedThreadFact(phrase: "Choisir le palier", resumptions: 3, nights: 2, held: 1)],
    open: ["Trancher le positionnement"],
    tierWord: "Net",
    tierShare: "26 % sont à ton palier.",
    tierDays: 9,
    memory: "",
    scope: nil
)

// ── Les faits ont quitte le prompt ──
//
// Ils sont derriere quatre outils. Le prompt ne porte plus que la question, le
// perimetre et la levee d'ambiguite des pronoms.

@Test func lePromptNePorteplusLesFaits() {
    let prompt = BrainCall.prompt("Qu’est-ce que j’ai appris ?", sample)

    #expect(!prompt.contains("28"))
    #expect(!prompt.contains("81"))
    #expect(!prompt.contains("Choisir le palier"))
    // Il tient en quelques lignes : c'est tout l'objet du tool calling.
    #expect(prompt.count < 700)
}

@Test func lePromptRappelleLePerimetreQuandIlYEnAUn() {
    var scoped = sample
    let prompt = BrainCall.prompt("Et ensuite ?", CallFacts(
        nightCount: scoped.nightCount, regularity: scoped.regularity,
        clarityWord: scoped.clarityWord, window: scoped.window,
        closed: scoped.closed, open: scoped.open,
        tierWord: scoped.tierWord, tierShare: scoped.tierShare, tierDays: scoped.tierDays,
        memory: "", scope: "Refonte tarifaire"
    ))

    #expect(prompt.contains("Refonte tarifaire"))
    #expect(prompt.contains("Ne cite rien d’un autre projet"))
    _ = scoped
}

@Test func lePromptExigeLaConsultationAvantTouteAffirmation() {
    let prompt = BrainCall.prompt("Qu’est-ce que j’ai appris ?", sample)
    #expect(prompt.contains("Consulte tes outils"))
    #expect(prompt.contains("N’invente"))
}

@Test func laConsigneDesambiguiseLesDeuxJe() {
    // Sans cette levee d'ambiguite, la regle de la premiere personne entre en
    // conflit avec la formulation des questions et perd.
    #expect(BrainCall.instructions.contains("« je » designe la personne"))
    #expect(BrainCall.instructions.contains("te designe, toi"))
    #expect(BrainCall.instructions.contains("Jamais par « tu »"))
}

@Test func laConsigneInterditDeConseiller() {
    let rules = BrainCall.instructions.lowercased()
    #expect(rules.contains("tu ne conseilles pas"))
    #expect(rules.contains("aucun imperatif"))
}
