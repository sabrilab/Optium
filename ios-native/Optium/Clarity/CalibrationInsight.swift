import Foundation

/// Une calibration, detachee de SwiftData.
///
/// Un type a part pour que le calcul se teste sans base de donnees, comme
/// `ProofFacts`.
struct CalibrationRecord {
    let askedAt: Date
    let feltClear: Bool
    let measured: ClarityLevel
}

/// Ce que la calibration a appris.
///
/// **C'est l'element le plus metacognitif du produit** : l'ecart entre ce
/// qu'on ressent et ce qui est mesure. En restriction chronique, la
/// somnolence ressentie plafonne alors que la performance continue de
/// decliner — les gens perdent la capacite de se juger. C'est elle qu'on
/// entraine, et elle ne s'entraine qu'en voyant l'ecart s'accumuler.
struct CalibrationSummary {
    /// Se sentir clair alors que la mesure est basse.
    let overestimates: Int
    /// Se sentir emousse alors que la mesure est haute.
    let underestimates: Int
    let agreements: Int
    let sentence: String

    var total: Int { overestimates + underestimates + agreements }
}

enum CalibrationInsight {
    /// En deca, il n'y a pas de tendance, seulement des reponses.
    static let minimum = 2

    static func summary(of records: [CalibrationRecord], calendar: Calendar = .current) -> CalibrationSummary? {
        guard records.count >= minimum else { return nil }

        var over = 0, under = 0, agree = 0
        for record in records {
            switch (record.feltClear, record.measured) {
            case (true, .low): over += 1
            case (false, .high): under += 1
            // Une mesure moyenne ne contredit rien : elle ne compte ni pour ni
            // contre. Compter l'accord sur elle gonflerait artificiellement la
            // concordance.
            case (_, .medium): break
            default: agree += 1
            }
        }

        return CalibrationSummary(
            overestimates: over,
            underestimates: under,
            agreements: agree,
            sentence: sentence(over: over, under: under, agree: agree, total: records.count)
        )
    }

    /// Elle enonce un ecart. Jamais un jugement, jamais une felicitation :
    /// l'un accable, l'autre transforme la calibration en recompense, et une
    /// recompense fausserait les reponses suivantes.
    private static func sentence(over: Int, under: Int, agree: Int, total: Int) -> String {
        if over == 0 && under == 0 {
            return "Sur \(total) fois, ton ressenti et ma mesure ont toujours dit la même chose."
        }
        if over > under {
            return "Sur \(total) fois, tu t’es senti clair \(over) fois pendant que je mesurais bas. "
                 + "C’est l’écart qui se voit le moins de l’intérieur."
        }
        if under > over {
            return "Sur \(total) fois, tu t’es senti émoussé \(under) fois pendant que je mesurais haut. "
                 + "Une nuit courte isolée trompe souvent dans ce sens."
        }
        return "Sur \(total) fois, tes écarts vont autant dans un sens que dans l’autre."
    }
}
