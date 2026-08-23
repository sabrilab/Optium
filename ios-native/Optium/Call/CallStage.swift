import Foundation

/// Ce que l'ecran montre pendant que la voix parle.
///
/// **C'est le cœur de l'appel, pas sa decoration.** La premiere regle des
/// instructions dit qu'un modele qui rappelle est verifiable. Afficher la
/// donnee au moment ou on l'enonce transforme cette promesse en demonstration :
/// une invention deviendrait visible, faute d'avoir quelque chose a montrer.
///
/// C'est aussi la reponse au risque propre a la voix. Une parole qui passe ne
/// se verifie pas ; ce qui est montre, si.
enum CallExhibit: Sendable, Hashable {
    case clarity(word: String?, nights: Int, window: DateInterval)
    case thread(phrase: String, resumptions: Int, nights: Int, held: Int)
    case openThreads([String])
    /// **Le palier lui-meme, pas son libelle.** `ExhibitCard` reconstruisait
    /// le palier depuis le mot affiche — `Tier(rawValue: "cristallin")` — alors
    /// que les `rawValue` sont les cas anglais. La reconstruction renvoyait
    /// donc toujours `nil`, et l'embleme affichait un remplissage de 0,6 quel
    /// que soit le palier reel.
    case tier(Tier, share: String, days: Int?)
}

/// La scene de l'appel : une seule chose a la fois.
///
/// **Ce qui est montre remplace ce qui precedait.** Rien ne s'empile — un
/// empilement serait le fil de messages que l'appel s'interdit, sous une autre
/// forme. Quand l'appel se termine, la scene se vide et il ne reste rien a
/// faire defiler.
@MainActor
@Observable
final class CallStage {
    private(set) var exhibit: CallExhibit?

    func show(_ exhibit: CallExhibit) { self.exhibit = exhibit }
    func clear() { exhibit = nil }
}

// ── Ce que les outils ont le droit de consulter ──

/// Un fil ferme, reduit a ce qui se cite.
struct ClosedThreadFact: Sendable, Equatable {
    let phrase: String
    let resumptions: Int
    let nights: Int
    let held: Int
}

/// L'instantane passe aux outils.
///
/// **Une valeur, capturee avant l'appel.** Les outils doivent etre `Sendable`
/// et sont appeles hors du fil principal ; leur donner acces au contexte
/// SwiftData les rendrait dependants d'un acteur et transformerait chaque
/// consultation en aller-retour. L'instantane coute une copie de quelques
/// dizaines de lignes, une fois.
struct CallFacts: Sendable {
    let nightCount: Int
    let regularity: Double?
    let clarityWord: String?
    let window: DateInterval
    let closed: [ClosedThreadFact]
    let open: [String]
    let tier: Tier?
    let tierShare: String?
    let tierDays: Int?
    let memory: String
    /// Le projet dont on parle, ou `nil` pour tout.
    let scope: String?
}
