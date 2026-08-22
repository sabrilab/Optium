import Foundation

/// La disponibilite du cerveau pour comprendre et reflechir.
///
/// Lue, jamais saisie. **La valeur numerique n'est jamais affichee** :
/// l'interface montre un mot. La regle est esthetique autant que
/// reglementaire — un score chiffre de performance cognitive s'approche d'un
/// diagnostic, ce que cette application ne pose pas.
enum ClarityLevel: String, Codable, CaseIterable {
    case low, medium, high

    /// Seuils du document : basse < 42 ≤ moyenne < 70 ≤ haute.
    init(value: Int) {
        switch value {
        case ..<42: self = .low
        case ..<70: self = .medium
        default: self = .high
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

extension ClarityReading {
    /// Une lecture forcee, pour l'outil de developpement.
    static func forced(_ level: ClarityLevel, window: DateInterval) -> ClarityReading {
        let value = switch level {
        case .low: 28
        case .medium: 55
        case .high: 82
        }
        return ClarityReading(
            clarity: Clarity(value: value),
            isConfident: true,
            regularity: nil,
            window: window,
            projectedNightPenalty: 0
        )
    }
}
