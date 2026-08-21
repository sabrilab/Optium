import Foundation
import SwiftData

/// Nomme `ProjectTask` et non `Task` : `Task` est le type de Swift Concurrency,
/// et l'ombrer rendrait toute utilisation de `Task { }` ambigue dans le module.
@Model
final class ProjectTask {
    var id: UUID = UUID()
    var title: String = ""
    var estimatedPomodoros: Int = 1
    var completedPomodoros: Int = 0
    var isDone: Bool = false
    var order: Int = 0
    var project: Project?

    init(title: String, estimatedPomodoros: Int, order: Int) {
        self.id = UUID()
        self.title = title
        self.estimatedPomodoros = max(1, estimatedPomodoros)
        self.order = order
    }

    /// Une session de concentration terminee sur cette tache.
    func incrementPomodoro() {
        completedPomodoros += 1
        if completedPomodoros >= estimatedPomodoros { isDone = true }
    }
}
