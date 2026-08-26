import Foundation
import Testing

@testable import Optium

// ── Le premier lancement ──
//
// L'application demande d'apprendre une douzaine de mots inventes et n'a rien
// de mesure a dire avant plusieurs nuits. C'est la que la plupart des gens
// abandonnent.

private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Paris")!
    return c
}
private let day0 = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

private func night(_ day: Int) -> Night {
    let d = cal.date(byAdding: .day, value: day, to: day0)!
    let asleep = cal.startOfDay(for: d).addingTimeInterval(23 * 3600)
    return Night(asleepAt: asleep, wokeAt: asleep.addingTimeInterval(8 * 3600))
}

// ── La fenetre inventee ne sort plus ──
//
// `window` porte toujours un intervalle, y compris sans aucune nuit : il vaut
// « lever habituel + 2 h ». Il sortait par la carte, la notification
// quotidienne, le widget et l'intention, en se presentant partout comme un
// fait.

@Test func sansMesureAucuneFenetreNEstAffirmee() {
    for count in 0..<ClarityEngine.minimumNights {
        let nights = (0..<count).map { night($0) }
        let reading = ClarityEngine.reading(nights: nights, now: day0, calendar: cal)
        #expect(reading.measuredWindow == nil, "\(count) nuits : une fenetre est affirmee")
        // L'intervalle brut existe toujours — les vues en ont besoin pour
        // dessiner — mais rien ne doit l'affirmer.
        #expect(reading.window.duration > 0)
    }
}

@Test func desLeSeuilLaFenetreEstAffirmable() {
    let nights = (0..<ClarityEngine.minimumNights).map { night($0) }
    let now = nights.last!.wokeAt.addingTimeInterval(3 * 3600)
    #expect(ClarityEngine.reading(nights: nights, now: now, calendar: cal).measuredWindow != nil)
}

// ── La file des phrases ──

@MainActor
@Test func lesPhrasesSontOrdonneesEtLaRegleVientEnPremier() {
    // La regle est ce qui rend l'application utilisee ; la porte est ce qui la
    // rend defendable. Se presenter par son interdiction serait un mauvais
    // debut.
    #expect(Intro.rule.rank < Intro.clarity.rank)
    #expect(Intro.clarity.rank < Intro.gate.rank)
}

@MainActor
@Test func unePhraseNeSeMontreQuUneFois() {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let settings = AppSettings(defaults: defaults)

    #expect(!settings.hasSeen(.rule))
    settings.markSeen(.rule)
    #expect(settings.hasSeen(.rule))
    // Marquer deux fois ne casse rien.
    settings.markSeen(.rule)
    #expect(settings.hasSeen(.rule))
    #expect(!settings.hasSeen(.clarity))
}

@MainActor
@Test func laMigrationNeRejoueRienAuxAnciens() {
    // Qui avait deja vu le message de franchissement connait la porte : lui
    // rejouer sa phrase serait lui apprendre ce qu'il sait.
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    defaults.set(true, forKey: "hasSeenThreshold")
    let settings = AppSettings(defaults: defaults)

    #expect(settings.hasSeen(.gate))
    #expect(!settings.hasSeen(.rule))
}

@MainActor
@Test func lesPhrasesSurviventAUnRedemarrage() {
    let name = "test-\(UUID().uuidString)"
    let first = AppSettings(defaults: UserDefaults(suiteName: name)!)
    first.markSeen(.clarity)

    let second = AppSettings(defaults: UserDefaults(suiteName: name)!)
    #expect(second.hasSeen(.clarity))
}

// ── Aucun texte du premier lancement n'est imperatif ──

@MainActor
@Test func aucunePhraseNeDonneDOrdre() {
    let phrases = [
        "À droite, ta journée : du lever, en haut, au soir, en bas.",
        "La longueur d’une graduation dit ce que cette heure laisse passer de ce que ta nuit permet.",
        "C’est ce que tes nuits laissent passer à cette heure-ci.",
        "Optium t’arrêtera si tu essaies de fermer une décision quand tes nuits ne le permettent pas.",
    ]
    for phrase in phrases {
        let text = phrase.lowercased()
        for banned in ["tu dois", "il faut que tu", "pense à", "n’oublie pas", "essaie de"] {
            #expect(!text.contains(banned), "« \(banned) » dans : \(phrase)")
        }
    }
}
