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
    private static let instructions = """
    Tu es la voix d'un cerveau — celui de la personne qui te parle. Tu reponds
    en francais, en deux ou trois phrases, jamais plus.

    Trois regles absolues :

    1. Tu te souviens, tu ne conseilles pas. Un modele qui predit invente ; un
       modele qui rappelle est verifiable. Dis « la derniere fois que tu as
       tranche ca, tu avais dormi cinq heures », jamais « tu devrais attendre
       demain ».

    2. Tu parles de toi, jamais de la personne a l'imperatif. Dis « je tourne
       a deux tiers depuis mardi », jamais « tu devrais te coucher plus tot ».
       Tu es un organe, pas un coach.

    3. Tu sais dire que tu ne sais pas. Si les donnees fournies ne suffisent
       pas, dis-le et arrete-toi la. Un oracle qui a toujours une reponse ment
       en permanence.

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

    /// Ce que le cerveau sait, rassemble avant l'appel.
    struct Context {
        let nightCount: Int
        let regularity: Double?
        let clarity: ClarityLevel?
        let closedThreads: [(phrase: String, resumptions: Int, nights: Int, held: Int)]
        let openPhrases: [String]
        let memory: String
    }

    func ask(_ question: String, context: Context) async {
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
        let session = LanguageModelSession(instructions: Self.instructions)

        do {
            let response = try await session.respond(to: Self.prompt(question, context))
            state = .answered(response.content)
        } catch {
            state = .unavailable("L’appel n’a pas abouti.")
        }
    }

    func reset() { state = .idle }

    private static func prompt(_ question: String, _ context: Context) -> String {
        var facts = ["Nuits observées : \(context.nightCount)."]
        if let regularity = context.regularity {
            facts.append("Régularité du sommeil : \(Int(regularity.rounded())) sur 100.")
        }
        facts.append(context.clarity.map { "Clarté actuelle : \($0.word)." }
            ?? "Clarté : pas encore mesurable, l’historique est trop court.")

        if !context.closedThreads.isEmpty {
            facts.append("Fils fermés :")
            for thread in context.closedThreads.suffix(12) {
                facts.append("- « \(thread.phrase) » : \(thread.resumptions) reprises, "
                           + "\(thread.nights) nuits traversées, \(thread.held) retenues.")
            }
        }
        if !context.openPhrases.isEmpty {
            facts.append("Fils ouverts : " + context.openPhrases.joined(separator: " ; ") + ".")
        }
        if !context.memory.isEmpty {
            facts.append("Mémoire du projet :\n\(context.memory)")
        }

        return """
        Voici ce que tu sais. N'utilise rien d'autre.

        \(facts.joined(separator: "\n"))

        Question : \(question)
        """
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
