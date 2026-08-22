import ActivityKit
import Foundation

/// La reprise en cours, telle que l'ile dynamique et l'ecran verrouille la
/// voient.
///
/// L'etat voyage entier a chaque mise a jour : une Live Activity ne partage
/// pas la memoire de l'application, et ne peut rien aller chercher elle-meme.
struct OptiumActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var fill: Double
        var base: Double
        var clarityWord: String
        var resumptionNumber: Int
        var startedAt: Date
        var windowEnd: Date
        /// Fourchette d'atterrissage, deja mise en forme — l'extension ne
        /// refait aucun calcul.
        var landing: String?
    }

    var phrase: String
    var isDecision: Bool
}
