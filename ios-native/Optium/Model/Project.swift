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

    /// Couleurs d'identification des projets.
    ///
    /// Ecart assume avec la version Expo, dont la palette — bleu ciel, vert
    /// pomme, jaune, orange vif — datait du modele et jurait avec la retenue
    /// du reste. Celle-ci reste a huit teintes distinctes, mais toutes
    /// sombres et desaturees : elles doivent identifier un projet d'un coup
    /// d'oeil sans jamais dominer l'ecran.
    ///
    /// Les projets deja crees gardent la valeur enregistree dans leur modele :
    /// changer cette liste ne les repeint pas.
    static let palette = [
        "#5B5BD6", "#7C5CD6", "#A855C4", "#C0567F",
        "#B5654A", "#8E8244", "#3E8F7C", "#3F7BA8",
    ]

    /// Les taches dans l'ordre d'ajout : SwiftData ne garantit pas l'ordre d'une relation.
    var orderedTasks: [ProjectTask] {
        tasks.sorted { $0.order < $1.order }
    }
}
