import Foundation

/// Depuis combien de temps on tient son palier.
///
/// **Retrospectif, jamais predictif.** « Tu es a Net depuis neuf jours »
/// recompense un resultat deja acquis. « Tu passes Net dans six jours »
/// serait un compte a rebours vers un score de sommeil — c'est-a-dire le
/// levier meme de l'orthosomnie, cette poursuite anxieuse d'un bon score qui
/// degrade le sommeil qu'elle pretend ameliorer.
///
/// Reference du risque : Baron et coll., *Journal of Clinical Sleep Medicine*,
/// 2017.
enum TierHistory {
    /// Il faut au moins la fenetre de l'indice, plus quelques jours a comparer.
    static let minimumNights = 20

    /// - Returns: le nombre de jours consecutifs passes au palier courant, ou
    ///   `nil` si l'historique ne permet pas de le dire.
    static func daysAtCurrentTier(nights: [Night], now: Date, calendar: Calendar = .current) -> Int? {
        guard nights.count >= minimumNights else { return nil }

        let sorted = nights.sorted { $0.asleepAt < $1.asleepAt }
        guard let current = tier(endingAt: now, nights: sorted, calendar: calendar) else { return nil }

        var days = 0
        // On remonte jour par jour en recalculant le palier tel qu'il etait :
        // le stocker au fil de l'eau serait plus rapide, mais rendrait
        // l'historique dependant de l'ouverture de l'application.
        for offset in 1...nights.count {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now),
                  let past = tier(endingAt: day, nights: sorted, calendar: calendar),
                  past == current else { break }
            days += 1
        }
        return days
    }

    private static func tier(endingAt date: Date, nights: [Night], calendar: Calendar) -> Tier? {
        let horizon = calendar.date(byAdding: .day, value: -28, to: date) ?? date
        let window = nights.filter { $0.wokeAt <= date && $0.wokeAt >= horizon }
        guard window.count >= 3,
              let regularity = SleepRegularity.index(nights: window, calendar: calendar)
        else { return nil }
        return Tier(regularity: regularity)
    }
}
