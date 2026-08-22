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
            return withUndo(try ModelContainer(for: schema))
        } catch {
            // Une base illisible ne doit pas empecher l'application de
            // demarrer : on repart a vide plutot que de refuser d'ouvrir.
            return withUndo(try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ))
        }
    }()

    /// Branche l'annulation sur le contexte principal.
    ///
    /// **Sans cette ligne, rien n'est annulable.** SwiftData enregistre les
    /// insertions, suppressions et modifications pour l'annulation — mais
    /// seulement si le contexte porte un `UndoManager`, et il n'en a aucun par
    /// defaut. C'est le mecanisme entier qui tient a cet appel.
    ///
    /// Les extensions — widgets, intentions — construisent leur propre
    /// `ModelContext` et n'heritent donc pas de l'annulation. C'est voulu :
    /// une action lancee depuis l'ecran verrouille n'a pas d'ecran ou offrir
    /// de la defaire.
    private static func withUndo(_ container: ModelContainer) -> ModelContainer {
        let manager = UndoManager()
        // Une profondeur bornee : l'annulation sert a rattraper une erreur qui
        // vient d'etre faite, pas a rejouer une semaine a l'envers.
        manager.levelsOfUndo = 20
        container.mainContext.undoManager = manager
        return container
    }
}
