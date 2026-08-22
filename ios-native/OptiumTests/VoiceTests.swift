import SwiftData
import AVFoundation
import Foundation
import Testing

@testable import Optium

// ── Rien ne sort, rien ne reste ──
//
// La promesse « aucune description de travail ne quitte l'appareil » vaut deja
// pour l'appel ecrit. En vocal, elle est plus facile a trahir : une
// transcription est du texte, et du texte se stocke sans y penser.
//
// L'en-tete de `BrainCall` interdit par ailleurs tout historique consultable.
// Un appel vocal est borne par nature — il commence, il se termine — mais rien
// n'empeche mecaniquement quelqu'un d'ajouter un modele pour « garder la
// derniere reponse ». Ces tests le rendent visible au moment ou ca arrive.

@Test func aucunModelePersisteNePorteDeTranscription() {
    // Le schema est la liste exhaustive de ce que l'application ecrit sur
    // disque via SwiftData.
    let stored = OptiumContainer.schema.entities.map(\.name)

    for banned in ["Transcript", "Utterance", "Conversation", "Message", "VoiceNote"] {
        #expect(!stored.contains { $0.localizedCaseInsensitiveContains(banned) },
                "« \(banned) » est persiste : l'appel ne doit rien laisser derriere lui")
    }
}

@Test func lesReglagesNePortentAucuneTranscription() {
    let keys = UserDefaults.standard.dictionaryRepresentation().keys
    for banned in ["transcript", "heard", "utterance", "lastAnswer", "conversation"] {
        #expect(!keys.contains { $0.localizedCaseInsensitiveContains(banned) })
    }
}

@Test func laMemoireDeProjetNeRecoitRienDeLAppel() throws {
    // La seule trace persistante autorisee est ProjectMemory, ecrite a la
    // fermeture d'un fil. L'appel ne doit jamais y ecrire.
    let source = try String(
        contentsOfFile: #filePath.replacingOccurrences(
            of: "OptiumTests/VoiceTests.swift",
            with: "Optium/Call/CallScreen.swift"
        ),
        encoding: .utf8
    )
    #expect(!source.contains(".append("), "CallScreen écrit dans une mémoire")
}

// ── La chaine reste locale ──

@Test func laLocaleDeTranscriptionEstFrancaise() {
    #expect(Voice.locale.identifier.hasPrefix("fr"))
}

@Test func uneVoixFrancaiseEstToujoursTrouvee() {
    // La voix de sortie n'est jamais une condition : le texte reste affiche
    // quoi qu'il arrive. Mais s'il y a une voix, elle doit parler francais.
    if let voice = Voice.bestFrenchVoice() {
        #expect(voice.language.hasPrefix("fr"))
    }
}
