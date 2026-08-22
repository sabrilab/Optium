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

    static func prompt(_ question: String, _ context: Context) -> String {
        // **Les faits sont ecrits a la premiere personne, et ce n'est pas
        // cosmetique.** Formules en tiers neutre — « Regularite du sommeil :
        // 81 sur 100 » — ils invitaient le modele a les rapporter, donc a
        // parler de la personne a la deuxieme personne. Enonces comme les
        // siens, ils se prolongent naturellement en « je ».
        var facts = ["J’ai observé \(context.nightCount) nuits."]
        if let regularity = context.regularity {
            facts.append("Ma régularité de sommeil : \(Int(regularity.rounded())) sur 100.")
        }
        facts.append(context.clarity.map { "Ma clarté en ce moment : \($0.word)." }
            ?? "Ma clarté : pas encore mesurable, mon historique est trop court.")

        if !context.closedThreads.isEmpty {
            facts.append("Ce que j’ai fermé :")
            for thread in context.closedThreads.suffix(12) {
                facts.append("- « \(thread.phrase) » : j’y suis revenu \(thread.resumptions) fois, "
                           + "j’ai traversé \(thread.nights) nuits dessus, je l’ai retenu \(thread.held) fois.")
            }
        }
        if !context.openPhrases.isEmpty {
            facts.append("Ce que je porte encore : " + context.openPhrases.joined(separator: " ; ") + ".")
        }
        if !context.memory.isEmpty {
            facts.append("Ma mémoire de ce projet :\n\(context.memory)")
        }

        return """
        Voici ce que tu sais de toi. N'utilise rien d'autre.

        \(facts.joined(separator: "\n"))

        La personne te demande : \(question)

        Reponds a la premiere personne, en commencant par « je ». Le « je » de
        la question est le sien ; celui de ta reponse est le tien.
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
