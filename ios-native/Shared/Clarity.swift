import Foundation

/// La disponibilite du cerveau pour comprendre et reflechir.
///
/// Lue, jamais saisie. **La valeur numerique n'est jamais affichee** :
/// l'interface montre un mot. La regle est esthetique autant que
/// reglementaire — un score chiffre de performance cognitive s'approche d'un
/// diagnostic, ce que cette application ne pose pas.
// `nonisolated` : un seuil est une constante, et `Vigilance` — pur, evalue
// hors du fil principal — en a besoin pour deriver la fenetre.
nonisolated enum ClarityLevel: String, Codable, CaseIterable {
    case low, medium, high

    /// Seuils du document : basse < 42 ≤ moyenne < 70 ≤ haute.
    static let mediumThreshold = 42
    static let highThreshold = 70

    init(value: Int) {
        switch value {
        case ..<Self.mediumThreshold: self = .low
        case ..<Self.highThreshold: self = .medium
        default: self = .high
        }
    }

    /// Le niveau, **avec hysteresis**.
    ///
    /// **Depuis que la clarte evolue dans la journee, elle traverse les
    /// seuils.** Une valeur qui oscille autour de 42 ou de 70 ferait clignoter
    /// le mot affiche, et surtout la porte : une decision refusee puis
    /// autorisee puis refusee dans la meme minute detruirait la confiance dans
    /// le refus.
    ///
    /// Un basculement doit donc **tenir** : pour changer d'etat, il faut
    /// depasser le seuil de la marge, pas seulement l'atteindre. Monter de
    /// moyenne a haute demande 73 ; redescendre demande 67.
    ///
    /// C'est asymetrique par construction, et c'est le principe meme d'une
    /// hysteresis : le seuil depend du sens dans lequel on le franchit.
    static let hysteresis = 3

    static func level(value: Int, previous: ClarityLevel?) -> ClarityLevel {
        guard let previous else { return ClarityLevel(value: value) }
        switch previous {
        case .low:
            return value >= mediumThreshold + hysteresis ? ClarityLevel(value: value) : .low
        case .high:
            return value < highThreshold - hysteresis ? ClarityLevel(value: value) : .high
        case .medium:
            if value >= highThreshold + hysteresis { return .high }
            if value < mediumThreshold - hysteresis { return .low }
            return .medium
        }
    }

    var word: String {
        switch self {
        case .low: "basse"
        case .medium: "moyenne"
        case .high: "haute"
        }
    }
}

struct Clarity {
    let value: Int
    var level: ClarityLevel { ClarityLevel(value: value) }
}
