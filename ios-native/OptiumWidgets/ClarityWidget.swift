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
        let snapshot = WidgetSnapshot.load()
        let now = Date()

        // **Plusieurs entrees dans la journee, pas une seule relue chaque
        // heure.** L'instantane portant desormais le modele, l'extension
        // evalue elle-meme la clarte a chaque instant : le liquide monte et
        // descend sur l'ecran d'accueil sans qu'on ouvre l'application.
        //
        // Le pas de trente minutes est un compromis assume : le systeme
        // budgete le nombre de rafraichissements par jour, et une entree par
        // minute serait refusee. Une demi-heure suffit pour que le creux de
        // l'apres-midi et le rebond du soir se voient.
        guard snapshot.vigilance != nil else {
            completion(Timeline(entries: [SnapshotEntry(date: now, snapshot: snapshot)],
                                policy: .after(now.addingTimeInterval(3600))))
            return
        }

        let entries = stride(from: 0.0, through: 12 * 3600, by: 1800).map { offset in
            SnapshotEntry(date: now.addingTimeInterval(offset), snapshot: snapshot)
        }
        // La chronologie est reconstruite avant d'etre epuisee : l'ancre du
        // reveil change chaque matin, et une journee entiere d'avance
        // continuerait de deriver sur le lever de la veille.
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(10 * 3600))))
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
