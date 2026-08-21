import Foundation
import SwiftData

/// Une session menee, de concentration ou de repos.
///
/// Le projet et la tache sont references par identifiant plutot que par
/// relation : supprimer un projet ne doit pas effacer l'historique du temps
/// deja passe dessus.
@Model
final class FocusSession {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var durationSeconds: Int = 0
    var isFocus: Bool = true
    var projectID: UUID?
    var taskID: UUID?
    var latitude: Double?
    var longitude: Double?

    init(
        durationSeconds: Int,
        isFocus: Bool,
        projectID: UUID?,
        taskID: UUID?,
        createdAt: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = UUID()
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.isFocus = isFocus
        self.projectID = projectID
        self.taskID = taskID
        self.latitude = latitude
        self.longitude = longitude
    }
}
