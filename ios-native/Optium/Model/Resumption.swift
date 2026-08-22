import Foundation
import SwiftData

/// Un moment passe sur un fil.
///
/// Elle reference son fil par relation et non par identifiant : une reprise
/// n'a aucun sens sans lui.
@Model
final class Resumption {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var clarityAtStart: ClarityLevel = ClarityLevel.medium
    /// Vrai si la reprise a demarre dans la fenetre du jour. C'est la mesure
    /// qui compte pour les comparaisons : elle porte sur la discipline, pas
    /// sur le volume.
    var inWindow: Bool = false
    var thread: WorkThread?

    init(startedAt: Date, clarityAtStart: ClarityLevel, inWindow: Bool) {
        self.id = UUID()
        self.startedAt = startedAt
        self.clarityAtStart = clarityAtStart
        self.inWindow = inWindow
    }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }
}
