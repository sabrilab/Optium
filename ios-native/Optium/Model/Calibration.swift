import Foundation
import SwiftData

/// Le retour sur erreur.
///
/// Deux fois par semaine au maximum. Une tape, deux reponses : « je suis
/// clair » ou « je suis emousse ». L'application compare la reponse a ce
/// qu'elle a mesure, et **l'ecart est ce que l'utilisateur apprend**.
///
/// Fondement : en restriction chronique, la somnolence ressentie plafonne
/// alors que la performance objective continue de decliner. Les gens perdent
/// la capacite de se juger — c'est cette capacite que la calibration entraine.
///
/// **Ne jamais demander de predire une duree.** C'est une estimation, le biais
/// de planification la rend fausse, et cela ajouterait une saisie avant chaque
/// reprise.
@Model
final class Calibration {
    var id: UUID = UUID()
    var askedAt: Date = Date()
    /// Ce que la personne a repondu.
    var feltClear: Bool = true
    /// Ce que l'application avait mesure au meme instant.
    var measured: ClarityLevel = ClarityLevel.medium

    init(askedAt: Date = Date(), feltClear: Bool, measured: ClarityLevel) {
        self.id = UUID()
        self.askedAt = askedAt
        self.feltClear = feltClear
        self.measured = measured
    }

    /// Vrai quand le ressenti et la mesure divergent. C'est le seul cas qui
    /// enseigne quelque chose.
    var disagrees: Bool {
        feltClear ? measured == .low : measured == .high
    }
}
