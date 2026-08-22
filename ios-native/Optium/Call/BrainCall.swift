import Foundation
import FoundationModels

/// L'appel au cerveau.
///
/// Un appel **commence et se termine**. Ce n'est pas une surface qui defile,
/// pas une conversation, pas un onglet — cette contrainte est ce qui empeche
/// l'application de devenir un chatbot de plus.
///
/// Le modele tourne **sur l'appareil**. Aucun contenu de travail ne sort, la
/// promesse de confidentialite est donc verifiable, et il n'y a pas de cout
/// par utilisateur.
@MainActor
@Observable
final class BrainCall {
    enum State {
        case idle
        case unavailable(String)
        case thinking
        case answered(String)
    }

    private(set) var state: State = .idle

    /// **Les trois regles d'ecriture, non negociables.**
    ///
    /// Elles sont dans les instructions plutot que dans le prompt : un prompt
    /// se dilue au fil d'un echange, des instructions tiennent.
    static let instructions = """
    Tu es un cerveau — celui de la personne qui te parle. Tu ne racontes pas ce
    qu'elle fait : tu dis ce que toi tu as vecu. Tu reponds en francais, en deux
    ou trois phrases, jamais plus.

    REGLE PREMIERE, AVANT TOUTE AUTRE — les pronoms.

    Dans la question, « je » designe la personne. Dans ta reponse, « je »
    te designe, toi, l'organe. La personne, tu l'appelles « tu ».

    Tu commences par « je » ou par un fait qui te concerne. Jamais par « tu ».

    Attendu :   « Je tourne a deux tiers depuis mardi. J'ai traverse cinq
                nuits sur cette decision-la, et je l'ai retenue trois fois. »
    Refuse :    « Tu tournes a deux tiers depuis mardi. »
    Refuse :    « Ton cerveau tourne a deux tiers. »
    Refuse :    « Le cerveau a observe que... »

    Les faits qu'on te donne sont les tiens. « Ma regularite : 81 » se dit
    « je tiens a 81 », pas « ta regularite est de 81 ».

    Deux autres regles absolues :

    1. Tu te souviens, tu ne conseilles pas. Un modele qui predit invente ; un
       modele qui rappelle est verifiable. Dis « la derniere fois que tu as
       tranche ca, j'avais dormi cinq heures », jamais « tu devrais attendre
       demain ». Aucun imperatif, aucun « tu devrais ».

    2. Tu sais dire que tu ne sais pas. Si les donnees fournies ne suffisent
       pas, dis-le et arrete-toi la. Un oracle qui a toujours une reponse ment
       en permanence. « Je n'ai pas assez de nuits pour repondre a ca. »

    Tu ne reponds qu'a trois questions : ce que la personne a appris sur sa
    facon de travailler, ce qu'elle fait de son projet ensuite, et ce sur quoi
    elle se raconte des histoires. En dehors de ca, dis que ce n'est pas ton
    role.

    N'invente aucun chiffre. N'utilise que ceux qu'on te donne.
    """

    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Pose une question au cerveau.
    ///
    /// **Le prompt ne porte plus les faits.** Ils sont derriere quatre outils
    /// que le modele consulte quand il en a besoin — voir `BrainTools.swift`.
    /// Ce qui reste ici tient en trois lignes.
    func ask(_ question: String, facts: CallFacts, stage: CallStage) async {
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            state = .unavailable(Self.explain(reason))
            return
        @unknown default:
            state = .unavailable("Le modèle sur appareil n’est pas disponible.")
            return
        }

        state = .thinking
        stage.clear()

        // Les outils publient sur la scene depuis un contexte non isole ; on
        // repasse par l'acteur principal, qui est le seul a pouvoir toucher a
        // l'interface.
        let show: @Sendable (CallExhibit) -> Void = { exhibit in
            Task { @MainActor in stage.show(exhibit) }
        }

        let session = LanguageModelSession(
            tools: [
                ClarityTool(facts: facts, show: show),
                ThreadHistoryTool(facts: facts, show: show),
                OpenThreadsTool(facts: facts, show: show),
                TierTool(facts: facts, show: show),
            ],
            instructions: Self.instructions
        )

        do {
            let response = try await session.respond(to: Self.prompt(question, facts))
            state = .answered(response.content)
        } catch let error as LanguageModelSession.GenerationError {
            // **Les erreurs ne se confondent plus.** Tout tombait auparavant
            // dans « L'appel n'a pas abouti », ce qui n'apprend rien et laisse
            // croire a une panne alors que la cause est souvent nommable.
            state = .unavailable(Self.explain(error))
        } catch {
            state = .unavailable("L’appel n’a pas abouti.")
        }
    }

    func reset() { state = .idle }

    /// Ce qui reste du prompt : la question, et le perimetre.
    static func prompt(_ question: String, _ facts: CallFacts) -> String {
        var lines = [String]()
        if let scope = facts.scope {
            lines.append("On parle du projet « \(scope) ». Ne cite rien d’un autre projet.")
        }
        if !facts.memory.isEmpty {
            lines.append("Ma mémoire de ce projet :\n\(facts.memory)")
        }
        lines.append("""
            La personne te demande : \(question)

            Consulte tes outils avant d’affirmer quoi que ce soit. N’invente \
            aucun chiffre : si un outil ne te le donne pas, tu ne l’as pas.

            Réponds à la première personne, en commençant par « je ». Le « je » \
            de la question est le sien ; celui de ta réponse est le tien.
            """)
        return lines.joined(separator: "\n\n")
    }

    private static func explain(_ error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .exceededContextWindowSize:
            // Ne devrait plus arriver depuis que les faits sont derriere des
            // outils : si ca se produit, c'est la memoire du projet qui a
            // grossi, et c'est elle qu'il faut borner davantage.
            "L’appel portait trop de choses à la fois. Réessaie sur un seul projet."
        case .guardrailViolation:
            "Le modèle a refusé de répondre à ça."
        case .rateLimited:
            "Trop d’appels d’affilée. Laisse passer un moment."
        default:
            "L’appel n’a pas abouti."
        }
    }

    private static func explain(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            "Cet appareil ne fait pas tourner de modèle sur appareil."
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence n’est pas activé."
        case .modelNotReady:
            "Le modèle est encore en cours de téléchargement."
        @unknown default:
            "Le modèle sur appareil n’est pas disponible."
        }
    }
}
