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

extension ClarityReading {
    /// Remplissage du cerveau, 0 sans mesure : la forme est presente, elle
    /// n'est pas encore renseignee.
    var brainFill: Double { clarity.map { Double($0.value) / 100 } ?? 0 }

    /// Plafond permis par la nuit. Sans regularite mesuree il n'y a pas de
    /// plafond a montrer — la ligne disparait plutot que d'etre inventee.
    /// **Le plafond, et il descend maintenant dans la journee.**
    ///
    /// Il valait `0,45 + regularite x 0,55` : une constante etablie au reveil,
    /// sans aucun terme de temps. C'etait le manque principal — la ligne du
    /// cerveau ne bougeait pas de la journee, alors qu'elle represente ce que
    /// la nuit permet *encore*.
    var brainBase: Double { (ceiling ?? 0) / 100 }

    /// Une lecture forcee, pour l'outil de developpement.
    ///
    /// Ses manques sont fabriques pour que la porte ait quelque chose a citer :
    /// sans eux, forcer la clarte basse ouvrirait une porte muette.
    static func forced(_ level: ClarityLevel, window: DateInterval) -> ClarityReading {
        let value = switch level {
        case .low: 28
        case .medium: 55
        case .high: 82
        }
        return ClarityReading(
            clarity: Clarity(value: value),
            observedNights: 28,
            // L'outil de developpement simule une mesure complete : ce qu'il
            // sert a eprouver, c'est la porte, pas l'absence de donnees.
            inferredNights: 0,
            regularity: Double(value),
            window: window,
            projectedNightPenalty: 0,
            lastNightDuration: 5.2 * 3600,
            wakeSpread: 2.1 * 3600,
            shortfalls: [
                ClarityShortfall(component: .duration, amount: Double(100 - value) * 0.30),
                ClarityShortfall(component: .regularity, amount: Double(100 - value) * 0.20),
                ClarityShortfall(component: .circadian, amount: Double(100 - value) * 0.10),
            ],
            // L'outil de developpement force un niveau : il simule une journee
            // deja entamee, plafond au-dessus de la valeur forcee.
            ceiling: Double(min(100, value + 12)),
            hoursAwake: 4,
            wokeAt: Date().addingTimeInterval(-4 * 3600),
            curve: [],
            level: level
        )
    }
}
