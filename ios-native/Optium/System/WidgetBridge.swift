import Foundation
import WidgetKit

/// Ce que l'application laisse aux widgets.
///
/// Un instantane, ecrit a chaque rafraichissement. Les widgets ne lisent pas
/// la base : ils n'ont pas besoin de savoir calculer une clarte, seulement de
/// l'afficher, et leur donner le moteur entier les obligerait a partager le
/// modele et les sources de sommeil pour un rendu qui tient en quatre valeurs.
enum WidgetBridge {
    static func publish(
        reading: ClarityReading,
        threadPhrase: String?,
        tier: Tier?,
        landing: Landing?
    ) {
        WidgetSnapshot(
            clarityWord: reading.clarity.level.word,
            isConfident: reading.isConfident,
            fill: Double(reading.clarity.value) / 100,
            base: reading.regularity.map { min(1, 0.45 + $0 / 100 * 0.55) } ?? 1,
            windowStart: reading.window.start,
            windowEnd: reading.window.end,
            threadPhrase: threadPhrase,
            tierWord: tier?.word,
            landingEarliest: landing?.earliest,
            landingLatest: landing?.latest
        ).save()

        WidgetCenter.shared.reloadAllTimelines()
    }
}
