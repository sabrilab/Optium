import SwiftUI
import WidgetKit

/// Le fil en cours et l'atterrissage.
struct ThreadWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ThreadWidget", provider: SnapshotProvider()) { entry in
            ThreadWidgetView(snapshot: entry.snapshot)
                // Une teinte differente de celle du widget de clarte : poses
                // cote a cote sur l'ecran d'accueil, deux lavis identiques se
                // liraient comme un seul widget coupe en deux.
                .containerBackground(for: .widget) {
                    BentoWash(tint: Ink.violet.tint)
                        .background(Ink.canvas)
                }
        }
        .configurationDisplayName("Fil en cours")
        .description("La phrase du fil ouvert, et quand il devrait atterrir.")
        .supportedFamilies([.systemMedium])
    }
}
