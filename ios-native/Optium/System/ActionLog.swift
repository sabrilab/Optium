import Foundation
import Observation

/// Ce qui vient d'etre fait, et qui peut encore etre defait.
///
/// **L'annulation ne suffit pas si elle est invisible.** SwiftData sait defaire
/// une insertion, une suppression ou une modification des lors que son contexte
/// porte un `UndoManager` — mais un mecanisme que rien n'annonce n'existe pas
/// pour l'utilisateur. Ce type ne conserve donc pas l'action : il conserve
/// **la phrase qui la nomme**, pour qu'une bande discrete puisse l'offrir.
///
/// **Elle s'efface d'elle-meme.** Une commande d'annulation permanente en bas
/// d'ecran finirait par etre lue comme un element d'interface, donc ignoree.
/// Six secondes : le temps de s'apercevoir qu'on s'est trompe, pas le temps de
/// s'y habituer.
@MainActor
@Observable
final class ActionLog {
    /// Ce que la bande annonce, ou `nil` quand il n'y a rien a defaire.
    private(set) var pending: String?

    /// Combien de fois une action a ete enregistree. Sert aux vues a se
    /// declencher sans comparer des chaines.
    private(set) var revision = 0

    static let lifetime: Duration = .seconds(6)

    @ObservationIgnored private var expiry: Task<Void, Never>?

    /// - Parameter label: au passe compose, tel qu'il s'affichera —
    ///   « Fil ouvert », « Café noté », « Fil supprimé ».
    func record(_ label: String) {
        pending = label
        revision += 1
        expiry?.cancel()
        expiry = Task { [weak self] in
            try? await Task.sleep(for: Self.lifetime)
            guard !Task.isCancelled else { return }
            self?.pending = nil
        }
    }

    /// Apres une annulation, ou quand l'utilisateur ecarte la bande.
    func clear() {
        expiry?.cancel()
        expiry = nil
        pending = nil
    }
}
