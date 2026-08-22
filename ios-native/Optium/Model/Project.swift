import Foundation
import SwiftData

/// Un projet, a l'echelle de la semaine. Il contient des fils.
@Model
final class Project {
    var id: UUID = UUID()
    var title: String = ""
    var openedAt: Date = Date()
    var closedAt: Date?
    var colorIndex: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \WorkThread.project)
    var threads: [WorkThread] = []

    init(title: String, openedAt: Date = Date(), colorIndex: Int = 0) {
        self.id = UUID()
        self.title = title
        self.openedAt = openedAt
        self.colorIndex = colorIndex
    }

    var hue: Ink.CardHue { Ink.cardHues[colorIndex % Ink.cardHues.count] }

    var openThreads: [WorkThread] {
        threads.filter { $0.state != .closed }.sorted { $0.createdAt < $1.createdAt }
    }
}
