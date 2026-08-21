import Foundation

/// Le cas de repos s'appelle `.rest` : `break` est un mot-cle Swift, et
/// l'echapper en `` `break` `` alourdirait chaque site d'appel.
enum TimerMode: Identifiable {
    case focus
    case rest

    var id: Self { self }

    var label: String {
        switch self {
        case .focus: "Deep Focus"
        case .rest: "Pause"
        }
    }
}
