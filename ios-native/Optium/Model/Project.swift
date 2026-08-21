import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    /// L'objectif du projet. Nomme `detail` et non `description`, qui est deja
    /// pris par la conformance CustomStringConvertible de toute classe Swift.
    var detail: String = ""
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var colorHex: String = Project.palette[0]

    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project)
    var tasks: [ProjectTask] = []

    init(name: String, detail: String, createdAt: Date = Date(), colorHex: String? = nil) {
        self.id = UUID()
        self.name = name
        self.detail = detail
        self.createdAt = createdAt
        self.colorHex = colorHex ?? Project.palette[0]
    }

    /// Couleurs d'identification des projets, reprises telles quelles de la
    /// version Expo pour que les deux applications restent comparables a l'oeil.
    static let palette = [
        "#5B9BD5", "#70AD47", "#FFC000", "#ED7D31",
        "#A855F7", "#EC4899", "#14B8A6", "#F97316",
    ]

    /// Les taches dans l'ordre d'ajout : SwiftData ne garantit pas l'ordre d'une relation.
    var orderedTasks: [ProjectTask] {
        tasks.sorted { $0.order < $1.order }
    }
}
