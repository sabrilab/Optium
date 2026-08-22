import Foundation
import SwiftData

/// Le conteneur, partage entre l'application et les intentions.
///
/// Les intentions s'executent hors du cycle de vie de l'interface : elles ne
/// peuvent pas emprunter le `modelContainer` d'une vue. Un point d'acces
/// unique evite qu'elles n'ouvrent une seconde base, ce qui ferait diverger
/// silencieusement les deux.
enum OptiumContainer {
    static let schema = Schema([
        Project.self, WorkThread.self, Resumption.self,
        RecordedNight.self, CoffeeIntake.self, Calibration.self,
    ])

    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: schema)
        } catch {
            // Une base illisible ne doit pas empecher l'application de
            // demarrer : on repart a vide plutot que de refuser d'ouvrir.
            return try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }()
}
