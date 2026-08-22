import SwiftUI
import WidgetKit

/// Le cerveau seul, et un mot.
///
/// **Image fixe, jamais animee.** Un widget se rafraichit par plages
/// accordees par le systeme ; y mettre du mouvement le ferait saccader ou
/// vider la batterie. Le fluide ne bouge que dans la Live Activity et dans
/// l'application.
struct ClarityWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClarityWidget", provider: SnapshotProvider()) { entry in
            ClarityEntryView(snapshot: entry.snapshot)
                // **Le meme lavis que les cartes de l'application.** Le noir
                // plat qui etait la ne ressemblait a rien de ce qu'on voit en
                // ouvrant l'app, alors que c'est le meme objet pose ailleurs.
                //
                // Les familles `accessory*` ignorent ce fond : le systeme les
                // rend en masque teinte sur l'ecran verrouille, et un degrade y
                // serait aplati en tache.
                .containerBackground(for: .widget) {
                    BentoWash(tint: Ink.indigo.tint)
                        .background(Ink.canvas)
                }
        }
        .configurationDisplayName("Clarté")
        .description("Le cerveau, et un mot. Jamais un chiffre.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular,
        ])
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: Date(), snapshot: .load())
        // Une heure : la clarte ne bouge pas plus vite, et demander davantage
        // au systeme le ferait simplement refuser.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
}

/// Lit la famille depuis l'environnement et la transmet a la vue partagee.
private struct ClarityEntryView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        ClarityWidgetView(family: family, snapshot: snapshot)
    }
}
