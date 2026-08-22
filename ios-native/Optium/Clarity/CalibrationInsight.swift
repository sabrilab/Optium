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
/// qu'on ressent et ce qui est mesure, accumule jusqu'a devenir visible.
///
/// **Aucune direction n'est presumee, et c'est une correction.** Le recit
/// courant veut que le fatigue se croie performant ; la revue systematique de
/// Bermudez et coll. (*Sleep Medicine Reviews*, 2021, 28 etudes) ne le
/// soutient pas — les participants prives de sommeil donnent typiquement des
/// estimations **plus conservatrices** de leur performance, et une revue
/// distincte (*Metacognition and Learning*, 2017) ne trouve pas d'effet sur
/// les jugements de confiance.
///
/// Ce qui se degrade de facon constante, c'est la **detection de ses propres
/// erreurs**. On ne devient pas aveugle a sa fatigue : on devient moins
/// capable d'attraper ses erreurs. C'est un argument plus fort pour la porte,
/// pas plus faible — savoir qu'on est fatigue ne suffit alors pas, il faut
/// une interruption au moment de conclure.
///
/// Les deux sens sont donc comptes a part, affiches cote a cote, et **aucune
/// phrase ne dit lequel trompe le plus**.
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
    ///
    /// **Jamais non plus une explication de l'ecart.** Les versions
    /// precedentes ajoutaient « c'est l'ecart qui se voit le moins de
    /// l'interieur » a la surestimation et « une nuit courte isolee trompe
    /// souvent dans ce sens » a la sous-estimation. Les deux presupposaient
    /// une direction que la litterature ne soutient pas. Le compte se suffit :
    /// c'est lui, repete, qui enseigne — pas le commentaire qui l'accompagne.
    private static func sentence(over: Int, under: Int, agree: Int, total: Int) -> String {
        if over == 0 && under == 0 {
            return "Sur \(total) fois, ton ressenti et ma mesure ont toujours dit la même chose."
        }
        if over > under {
            return "Sur \(total) fois, tu t’es senti clair \(over) fois pendant que je mesurais bas."
        }
        if under > over {
            return "Sur \(total) fois, tu t’es senti émoussé \(under) fois pendant que je mesurais haut."
        }
        return "Sur \(total) fois, tes écarts vont autant dans un sens que dans l’autre."
    }
}
