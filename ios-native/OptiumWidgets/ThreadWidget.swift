import SwiftUI
import WidgetKit

/// Le fil en cours et l'atterrissage.
struct ThreadWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ThreadWidget", provider: SnapshotProvider()) { entry in
            ThreadWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Ink.canvas }
        }
        .configurationDisplayName("Fil en cours")
        .description("La phrase du fil ouvert, et quand il devrait atterrir.")
        .supportedFamilies([.systemMedium])
    }
}
