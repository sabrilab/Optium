import Foundation
import SwiftData

/// Une nuit conservee.
///
/// Les sources ne gardent pas assez loin : CoreMotion s'arrete a sept jours,
/// et l'indice de regularite en demande vingt-huit. Sans accumulation, la
/// mesure ne murirait jamais — elle repartirait de sept jours a chaque fois.
///
/// On enregistre donc ce qu'on a vu, une fois par nuit, et on n'y revient pas.
@Model
final class RecordedNight {
    var id: UUID = UUID()
    var asleepAt: Date = Date()
    var wokeAt: Date = Date()
    /// Vrai si la nuit vient d'un enregistrement de sommeil, faux si elle a ete
    /// deduite du mouvement. Une nuit mesuree ne se laisse pas remplacer par
    /// une nuit devinee.
    var measured: Bool = false

    init(_ night: Night, measured: Bool) {
        self.id = UUID()
        self.asleepAt = night.asleepAt
        self.wokeAt = night.wokeAt
        self.measured = measured
    }

    var night: Night { Night(asleepAt: asleepAt, wokeAt: wokeAt) }
}

/// Une prise de cafe.
///
/// **Le seul geste declaratif de toute l'application.** Tout le reste est lu.
/// Il agit sur la nuit projetee, donc sur la clarte de demain — jamais sur
/// celle d'aujourd'hui : c'est ce qui en fait un enseignement plutot qu'une
/// punition.
@Model
final class CoffeeIntake {
    var id: UUID = UUID()
    var takenAt: Date = Date()

    init(takenAt: Date = Date()) {
        self.id = UUID()
        self.takenAt = takenAt
    }
}
