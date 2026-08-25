import Foundation

// Ce que la lecture donne au cerveau et aux widgets.
//
// Reste cote application : `ClarityReading` est produite par le moteur,
// qui depend des sources de sommeil. `ClarityLevel` et `Vigilance`, eux,
// sont purs et vivent dans le code partage pour que l'extension puisse les
// evaluer elle-meme.

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
