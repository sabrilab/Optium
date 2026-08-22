import Foundation

/// Quand le travail restant devrait atterrir.
struct Landing {
    let earliest: Date
    let latest: Date

    var span: TimeInterval { latest.timeIntervalSince(earliest) }
}

/// **Le seul nombre de toute l'application.**
///
/// Trois regles, et aucune n'est negociable :
///
/// 1. **Ponderer par les reprises observees**, jamais par le nombre de fils —
///    un fil peut valoir vingt fois un autre.
/// 2. **Toujours une fourchette qui se resserre**, jamais une date unique.
/// 3. **Compter en heures de fenetre**, pas en heures brutes — une heure dans
///    le creux de l'apres-midi ne vaut pas une heure du matin.
///
/// Les deux termes sont **observes**, aucun n'est devine. Un modele n'estime
/// jamais une duree ici : il decoupe et qualifie, l'historique personnel fait
/// le reste.
enum LandingEstimator {
    /// - Parameters:
    ///   - closedResumptions: nombre de reprises qu'a pris chaque fil ferme.
    ///   - openThreads: fils encore ouverts.
    ///   - dailyCapacity: reprises menees par jour actif, observees.
    /// - Returns: `nil` tant qu'il n'y a rien a extrapoler. Se taire vaut
    ///   mieux qu'inventer une date.
    static func estimate(
        closedResumptions: [Int],
        openThreads: Int,
        dailyCapacity: Double,
        from now: Date,
        calendar: Calendar = .current
    ) -> Landing? {
        guard !closedResumptions.isEmpty, openThreads > 0, dailyCapacity > 0 else { return nil }

        let sorted = closedResumptions.sorted()
        // Premier et troisieme quartile : la fourchette vient de la dispersion
        // reelle des fils passes, pas d'une marge arbitraire. Elle se resserre
        // donc d'elle-meme a mesure que l'historique se regularise.
        let low = Double(sorted[max(0, (sorted.count - 1) / 4)])
        let high = Double(sorted[min(sorted.count - 1, (sorted.count - 1) * 3 / 4 + 1)])

        let optimistic = low * Double(openThreads) / dailyCapacity
        let pessimistic = high * Double(openThreads) / dailyCapacity

        // Au moins un jour d'ecart : une fourchette d'une heure serait une
        // fausse precision.
        let earliest = calendar.date(byAdding: .day, value: Int(optimistic.rounded(.up)), to: now) ?? now
        let latest = calendar.date(
            byAdding: .day,
            value: max(Int(optimistic.rounded(.up)) + 1, Int(pessimistic.rounded(.up))),
            to: now
        ) ?? now

        return Landing(earliest: earliest, latest: latest)
    }
}
