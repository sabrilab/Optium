import Foundation
import FoundationModels

/// Les outils que le cerveau peut consulter.
///
/// **Ils remplacent l'empilement.** Le prompt entassait auparavant douze fils
/// fermes, tous les fils ouverts, la regularite et la clarte — que le modele
/// en ait besoin ou non. Deux gains a les remplacer par des outils, et le
/// second est le vrai :
///
/// 1. La fenetre de contexte, 8192 jetons sur l'appareil, ne sature plus.
/// 2. **Chaque affirmation du modele correspond a une consultation datee.**
///
/// Chaque outil publie aussi ce qu'il a trouve, pour que l'ecran le montre
/// pendant que la voix en parle. Voir `CallStage`.

/// Aucun argument.
///
/// Trois des quatre outils ne prennent rien : ils rendent un etat, pas une
/// recherche. Le schema vide se construit dynamiquement — le macro `@Generable`
/// veut au moins une propriete.
enum EmptyArguments {
    static let schema: GenerationSchema = {
        let root = DynamicGenerationSchema(name: "aucun", properties: [])
        // `try!` assume : la construction ne peut echouer que sur une
        // dependance manquante ou un cycle, et un schema sans propriete n'a ni
        // l'un ni l'autre. Le rendre optionnel obligerait chaque outil a gerer
        // un cas impossible.
        return try! GenerationSchema(root: root, dependencies: [])
    }()
}

// ── La clarte ──

struct ClarityTool: Tool {
    typealias Arguments = GeneratedContent

    let name = "clarte"
    let description = """
        Ma clarte en ce moment, la fenetre du jour, et combien de nuits j'ai \
        observees. A consulter avant toute affirmation sur mon etat.
        """
    var parameters: GenerationSchema { EmptyArguments.schema }

    let facts: CallFacts
    let show: @Sendable (CallExhibit) -> Void

    func call(arguments: GeneratedContent) async throws -> String {
        show(.clarity(word: facts.clarityWord, nights: facts.nightCount, window: facts.window))

        var lines = ["J’ai observé \(facts.nightCount) nuits."]
        lines.append(facts.clarityWord.map { "Ma clarté : \($0)." }
            ?? "Ma clarté n’est pas encore mesurable, mon historique est trop court.")
        if let regularity = facts.regularity {
            lines.append("Ma régularité : \(Int(regularity.rounded())) sur 100.")
        }
        lines.append("Ma fenêtre : \(Clock.hhmm(facts.window.start)) à \(Clock.hhmm(facts.window.end)).")
        return lines.joined(separator: " ")
    }
}

// ── Les fils fermes ──

struct ThreadHistoryTool: Tool {
    @Generable
    struct Arguments {
        @Guide(description: "Un mot du fil recherché. Laisser vide pour les plus récents.")
        var about: String
    }

    let name = "filsFermes"
    let description = """
        Ce que j’ai fermé : pour chaque fil, le nombre de reprises, de nuits \
        traversées et de fois où je l’ai retenu. C’est la seule source pour \
        parler du passé.
        """

    let facts: CallFacts
    let show: @Sendable (CallExhibit) -> Void

    func call(arguments: Arguments) async throws -> String {
        let needle = arguments.about.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matching = needle.isEmpty
            ? Array(facts.closed.suffix(5))
            : facts.closed.filter { $0.phrase.lowercased().contains(needle) }

        guard let first = matching.first else {
            // On ne montre rien : il n'y a rien a montrer, et c'est
            // precisement ce que la scene doit rendre visible.
            return needle.isEmpty
                ? "Je n’ai encore rien fermé."
                : "Je ne trouve aucun fil fermé qui parle de « \(arguments.about) »."
        }

        show(.thread(phrase: first.phrase, resumptions: first.resumptions,
                     nights: first.nights, held: first.held))

        return matching.prefix(5).map { fact in
            "« \(fact.phrase) » : j’y suis revenu \(fact.resumptions) fois, "
          + "j’ai traversé \(fact.nights) nuits dessus, je l’ai retenu \(fact.held) fois."
        }.joined(separator: " ")
    }
}

// ── Les fils ouverts ──

struct OpenThreadsTool: Tool {
    typealias Arguments = GeneratedContent

    let name = "filsOuverts"
    let description = "Ce que je porte encore, non fermé."
    var parameters: GenerationSchema { EmptyArguments.schema }

    let facts: CallFacts
    let show: @Sendable (CallExhibit) -> Void

    func call(arguments: GeneratedContent) async throws -> String {
        guard !facts.open.isEmpty else { return "Je ne porte aucun fil ouvert." }
        show(.openThreads(facts.open))
        return "Je porte encore : " + facts.open.joined(separator: " ; ") + "."
    }
}

// ── Le palier ──

struct TierTool: Tool {
    typealias Arguments = GeneratedContent

    let name = "palier"
    let description = "Mon palier de régularité, et depuis combien de jours j’y suis."
    var parameters: GenerationSchema { EmptyArguments.schema }

    let facts: CallFacts
    let show: @Sendable (CallExhibit) -> Void

    func call(arguments: GeneratedContent) async throws -> String {
        guard let tier = facts.tier, let share = facts.tierShare else {
            return "Je n’ai pas encore assez de nuits pour avoir un palier."
        }
        show(.tier(tier, share: share, days: facts.tierDays))

        var line = "Mon palier : \(tier.word). \(share)"
        if let days = facts.tierDays { line += " J’y suis depuis \(days) jours." }
        return line
    }
}
