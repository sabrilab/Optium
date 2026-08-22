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

private let sample = BrainCall.Context(
    nightCount: 28,
    regularity: 81,
    clarity: .high,
    closedThreads: [(phrase: "Choisir le palier", resumptions: 3, nights: 2, held: 1)],
    openPhrases: ["Trancher le positionnement"],
    memory: ""
)

@Test func lesFaitsSontEnoncesALaPremierePersonne() {
    let prompt = BrainCall.prompt("Qu’est-ce que j’ai appris ?", sample)

    #expect(prompt.contains("J’ai observé 28 nuits."))
    #expect(prompt.contains("Ma régularité"))
    #expect(prompt.contains("Ma clarté"))
    #expect(prompt.contains("j’y suis revenu 3 fois"))
}

@Test func aucunFaitNEstAdresseALaDeuxiemePersonne() {
    let prompt = BrainCall.prompt("Qu’est-ce que j’ai appris ?", sample)
    // On ne teste que le bloc de faits : la consigne finale, elle, s'adresse
    // legitimement au modele en « tu ».
    let facts = prompt.components(separatedBy: "La personne te demande")[0]

    for banned in ["Ta régularité", "Ta clarté", "Tu as observé", "ton cerveau"] {
        #expect(!facts.contains(banned), "« \(banned) » dans les faits")
    }
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
