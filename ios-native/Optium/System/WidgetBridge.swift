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
        // La capture est produite dans le meme chemin de code que
        // l'instantane : image et valeurs sont ainsi coherentes par
        // construction, et ne peuvent pas se desynchroniser.
        let fill = reading.brainFill
        let graved = BrainSnapshot.render(fill: fill, base: reading.brainBase, isDay: true)

        WidgetSnapshot(
            clarityWord: reading.clarity == nil ? nil : reading.level.word,
            observedNights: reading.observedNights,
            fill: reading.clarity.map { Double($0.value) / 100 } ?? 0,
            base: reading.regularity.map { min(1, 0.45 + $0 / 100 * 0.55) } ?? 1,
            windowStart: reading.window.start,
            windowEnd: reading.window.end,
            threadPhrase: threadPhrase,
            tierWord: tier?.word,
            landingEarliest: landing?.earliest,
            landingLatest: landing?.latest,
            brainImageFill: graved,
            brainImageRenderedAt: graved == nil ? nil : Date()
        ).save()

        WidgetCenter.shared.reloadAllTimelines()
    }
}
