import Foundation

/// Ce que la porte a produit sur un fil, quand elle a produit quelque chose.
///
/// **C'est la seule recompense meritee du produit.** La these d'Optium est que
/// le sommeil decide de la clarte, et la clarte des decisions. L'application ne
/// refermait jamais cette boucle : quelqu'un retenait une decision un mardi a
/// clarte basse, la tranchait le jeudi a clarte haute, et rien nulle part ne le
/// lui remontrait.
///
/// Tout etait deja enregistre — `acceptance`, `holdCount`, `heldUntil`,
/// `clarityAtStart`, `closedAt`. Il manquait seulement de les rapprocher.
///
/// **Elle ne s'invente pas, elle se constate.** D'ou les trois interdits :
/// aucune notification, aucune felicitation, et **rien quand la boucle ne s'est
/// pas produite**. Une decision tranchee directement n'a rien a montrer, et
/// l'inventer detruirait la valeur de celles qui en ont.
struct GateLoop: Equatable {
    /// La ligne ecrite a la porte : ce qu'on avait accepte.
    let acceptance: String
    /// Combien de fois le fil a ete retenu.
    let holdCount: Int
    /// L'etat de la reprise qui a bute sur la porte.
    let clarityWhenHeld: ClarityLevel
    /// L'etat de la reprise qui a conclu.
    let clarityWhenClosed: ClarityLevel
    /// Le temps entre la premiere retenue et la fermeture.
    let span: TimeInterval

    /// La boucle a-t-elle vraiment change quelque chose.
    ///
    /// **Le cas qui merite d'etre montre** : retenu en clarte basse, tranche
    /// plus haut. Une decision retenue puis tranchee dans le meme etat n'a rien
    /// prouve — et le dire quand meme reviendrait a se feliciter d'avoir
    /// attendu pour rien.
    var isMeaningful: Bool {
        clarityWhenHeld == .low && clarityWhenClosed != .low
    }
}

enum GateLoopReader {
    /// - Returns: `nil` quand le fil n'est jamais passe par la porte.
    static func loop(for thread: WorkThread) -> GateLoop? {
        // Trois conditions, et aucune ne se devine : le fil a ete retenu, il
        // porte une ligne d'acceptation, et il est ferme.
        guard thread.holdCount > 0,
              let acceptance = thread.acceptance,
              !acceptance.isEmpty,
              let closedAt = thread.closedAt
        else { return nil }

        let ordered = thread.resumptions.sorted { $0.startedAt < $1.startedAt }
        guard let first = ordered.first, let last = ordered.last else { return nil }

        return GateLoop(
            acceptance: acceptance,
            holdCount: thread.holdCount,
            clarityWhenHeld: first.clarityAtStart,
            clarityWhenClosed: last.clarityAtStart,
            span: closedAt.timeIntervalSince(first.startedAt)
        )
    }

    /// Les boucles refermees, de la plus recente a la plus ancienne.
    static func loops(in threads: [WorkThread]) -> [(thread: WorkThread, loop: GateLoop)] {
        threads
            .compactMap { thread in loop(for: thread).map { (thread, $0) } }
            .filter { $0.1.isMeaningful }
            .sorted { ($0.0.closedAt ?? .distantPast) > ($1.0.closedAt ?? .distantPast) }
    }
}
