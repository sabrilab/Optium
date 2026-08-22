import Foundation

/// Ce qu'on sait des fils fermes, reduit a ce dont les preuves ont besoin.
///
/// Un type a part plutot que les modeles SwiftData : les regles de deblocage
/// se testent alors sans base de donnees, et ne peuvent pas se mettre a
/// dependre de quoi que ce soit d'autre.
struct ProofFacts {
    struct ClosedThread {
        let nature: ThreadNature
        let holdCount: Int
        let inWindowCount: Int
        let resumptionCount: Int
        let nightsCrossed: Int
    }

    /// Dans l'ordre de fermeture, du plus ancien au plus recent.
    let threads: [ClosedThread]
    var regularNights: Int = 0
    var soberDays: Int = 0
    var earlyResumptions: Int = 0
}

/// Un deblocage.
///
/// **Toutes recompensent la retenue, jamais le volume.** Une preuve
/// n'apparait qu'a la fermeture d'un fil — jamais pendant, jamais par
/// notification. Ce qui varie est *laquelle*, pas le moment : sans cette
/// regle, l'application se met a interrompre pour feliciter.
struct Proof: Identifiable {
    let id: String
    let word: String
    let requirement: String
    private let check: (ProofFacts) -> Bool

    func isEarned(by facts: ProofFacts) -> Bool { check(facts) }

    static let restraint = Proof(
        id: "restraint",
        word: "Retenue",
        requirement: "5 décisions retenues au lieu d’être validées à clarté basse",
        check: { facts in
        facts.threads.filter { $0.nature == .decision }.reduce(0) { $0 + $1.holdCount } >= 5
    })

    static let window = Proof(
        id: "window",
        word: "Fenêtre",
        requirement: "10 décisions d’affilée prises dans la fenêtre",
        check: { facts in
        var streak = 0
        for thread in facts.threads where thread.nature == .decision {
            // Une decision compte comme « dans la fenetre » si au moins une de
            // ses reprises l'etait : c'est la ou elle s'est jouee.
            streak = thread.inWindowCount > 0 ? streak + 1 : 0
            if streak >= 10 { return true }
        }
        return false
    })

    static let crossing = Proof(
        id: "crossing",
        word: "Traversée",
        requirement: "Un fil fermé après avoir traversé 5 nuits",
        check: { facts in
        facts.threads.contains { $0.nightsCrossed >= 5 }
    })

    static let regular = Proof(
        id: "regular",
        word: "Régulier",
        requirement: "14 nuits d’affilée à ±20 min près",
        check: { $0.regularNights >= 14 })

    static let morning = Proof(
        id: "morning",
        word: "Matin",
        requirement: "20 premières reprises entamées avant 10:00",
        check: { $0.earlyResumptions >= 20 })

    static let sobriety = Proof(
        id: "sobriety",
        word: "Sobriété",
        requirement: "10 jours sans café après 14:00",
        check: { $0.soberDays >= 10 })

    static let all = [restraint, window, crossing, regular, morning, sobriety]
}
