import Foundation

/// La justesse de **l'application**, pas celle de l'utilisateur.
///
/// La calibration existe deja, mais elle mesure l'ecart entre ce que la
/// personne ressent et ce qui est mesure — c'est-a-dire, implicitement, sa
/// justesse a elle. Personne ne mesurait celle du produit.
///
/// **On retourne la mesure** : sur les trente derniers jours, combien de fois
/// ce que l'application annoncait a correspondu a ce que la personne a
/// effectivement ressenti. Les enregistrements portent deja `askedAt`,
/// `feltClear` et `measured`.
///
/// Deux conditions font toute la valeur de la chose :
///
/// 1. **Si le resultat est mauvais, il s'affiche quand meme.** Une application
///    qui publie son propre taux d'erreur devient verifiable au lieu d'etre
///    crue sur parole.
/// 2. **Ce n'est pas un score a ameliorer.** C'est le bulletin de
///    l'application, pas celui de l'utilisateur : aucune incitation, aucune
///    serie, rien a optimiser. Il n'y a d'ailleurs rien que l'utilisateur
///    puisse faire pour le faire monter, et c'est voulu.
enum OwnAccuracy {
    /// En deca, un taux n'est qu'une impression chiffree.
    static let minimum = 5
    static let horizon: TimeInterval = 30 * 86_400

    struct Verdict: Equatable {
        /// Combien de fois la mesure et le ressenti se sont accordes.
        let agreed: Int
        /// Combien de fois ils se sont contredits.
        let disagreed: Int

        var total: Int { agreed + disagreed }
        /// 0…1.
        var rate: Double { total == 0 ? 0 : Double(agreed) / Double(total) }

        /// Ce que l'application dit d'elle-meme.
        ///
        /// **Aucune de ces phrases ne s'excuse ni ne se vante.** Elle constate,
        /// y compris quand le constat est mauvais — c'est precisement ce qui la
        /// rend verifiable.
        var sentence: String {
            let share = Int((rate * 100).rounded())
            if rate >= 0.75 {
                return "Sur \(total) fois, ce que je t’annonçais a correspondu à ton ressenti \(share) fois sur 100."
            }
            if rate >= 0.5 {
                return "Sur \(total) fois, je suis tombé juste \(share) fois sur 100. C’est peu."
            }
            return "Sur \(total) fois, je me suis trompé plus souvent que l’inverse : \(share) fois justes sur 100."
        }
    }

    /// - Returns: `nil` tant que trop peu de calibrations existent.
    static func verdict(from records: [CalibrationRecord], now: Date = Date()) -> Verdict? {
        let recent = records.filter { now.timeIntervalSince($0.askedAt) <= horizon }
        guard recent.count >= minimum else { return nil }

        var agreed = 0, disagreed = 0
        for record in recent {
            switch (record.feltClear, record.measured) {
            // Une mesure moyenne ne contredit rien et ne confirme rien : la
            // compter d'un cote ou de l'autre gonflerait artificiellement le
            // taux, dans un sens comme dans l'autre.
            case (_, .medium): continue
            case (true, .high), (false, .low): agreed += 1
            default: disagreed += 1
            }
        }

        guard agreed + disagreed >= minimum else { return nil }
        return Verdict(agreed: agreed, disagreed: disagreed)
    }
}
