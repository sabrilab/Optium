import Testing

@testable import Optium

// ── Le corpus scientifique ──
//
// La credibilite vient de ce qu'on refuse d'affirmer, pas de ce qu'on affirme.
// Une application qui cite trois etudes pour se donner de l'autorite est
// ordinaire ; une qui dit « cette partie repose sur un effet conteste » ne
// l'est pas.

@Test func chaqueEntreeDitCeQueLEtudeNEtablitPas() {
    // **Le champ le plus important, et celui qui manque partout ailleurs.**
    for evidence in EvidenceLibrary.all {
        #expect(evidence.doesNotShow.count > 60,
                "« \(evidence.id) » n’a pas de limite déclarée")
    }
}

@Test func chaqueEntreePorteSonNiveauDePreuve() {
    for evidence in EvidenceLibrary.all {
        #expect(!evidence.verification.caution.isEmpty)
        #expect(!evidence.reference.isEmpty)
    }
}

@Test func lesNiveauxFaiblesLeDisent() {
    // Une source secondaire ne doit jamais se presenter comme une preuve.
    #expect(Evidence.Verification.secondary.caution.contains("pas une preuve") == false)
    // La phrase dit « pas comme une preuve » : c'est la nuance qui compte.
    #expect(Evidence.Verification.secondary.caution.contains("pas comme une preuve"))
    #expect(Evidence.Verification.abstract.caution.contains("résumé"))
}

@Test func lEntreeLaPlusImportanteEstCelleQuiConteste() {
    // Le circadien est la brique la plus fragile du calcul, et sa modale doit
    // le dire — c'est ce qui distingue Optium d'une application qui ne cite
    // que ce qui l'arrange.
    let circadian = EvidenceLibrary.circadian
    #expect(circadian.doesNotShow.contains("absence"))
    #expect(circadian.usedFor.contains("oscillation"))
}

@Test func aucuneEntreeNeSurvendUneEtude() {
    for evidence in EvidenceLibrary.all {
        let text = (evidence.shows + evidence.usedFor).lowercased()
        for banned in ["prouve que", "démontre définitivement", "il est établi que le jugement"] {
            #expect(!text.contains(banned), "« \(banned) » dans \(evidence.id)")
        }
    }
}

@Test func lesIdentifiantsSontUniques() {
    #expect(Set(EvidenceLibrary.all.map(\.id)).count == EvidenceLibrary.all.count)
}

@Test func laPomodoroNeDitPasQueCaNeMarchePas() {
    // La seule entree lue en texte integral, et celle ou la tentation de
    // surinterpreter est la plus forte : c'est l'angle commercial du produit.
    let pomodoro = EvidenceLibrary.pomodoro
    #expect(pomodoro.verification == .fullText)
    #expect(pomodoro.doesNotShow.contains("ne marche pas"))
    #expect(pomodoro.doesNotShow.contains("signal"))
}
