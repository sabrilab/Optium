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
    /// Corrigee a la main. **Aucune relecture ne l'ecrase.**
    var corrected: Bool = false
    /// Ce que la source annoncait avant correction, pour que l'application
    /// puisse apprendre de l'ecart — et pour pouvoir revenir en arriere.
    var originalWokeAt: Date?
    var originalAsleepAt: Date?

    /// Le temps **reellement endormi**, reveils intra-nuit deduits.
    ///
    /// **Il se perdait ici, et c'etait le bug le plus couteux du moteur.**
    /// `HealthSleepSource` calculait bien la somme des fragments, `Night` la
    /// portait — et `RecordedNight` ne l'enregistrait pas. Le getter
    /// reconstruisait un `Night` sans elle, `duration` retombait sur `span`,
    /// et chaque reveil de nuit redevenait du sommeil.
    ///
    /// Consequence en cascade : plafond au reveil trop haut, `pressureTau`
    /// trop long, donc une journee entiere calculee sur une nuit qui n'a pas
    /// eu lieu. Seuls les tests, qui construisent un `Night` a la main, y
    /// echappaient — le commentaire de `Night` affirmait un correctif qui
    /// n'atteignait jamais la production.
    ///
    /// `nil` pour les nuits deduites du mouvement, qui n'ont qu'un bloc.
    var sleptSeconds: Double?

    init(_ night: Night, measured: Bool) {
        self.id = UUID()
        self.asleepAt = night.asleepAt
        self.wokeAt = night.wokeAt
        self.measured = measured
        // La duree reelle n'est retenue que si elle differe de l'amplitude :
        // sinon `nil` dit la meme chose et laisse le getter la deriver.
        let span = night.wokeAt.timeIntervalSince(night.asleepAt)
        self.sleptSeconds = abs(night.duration - span) > 1 ? night.duration : nil
    }

    var night: Night {
        Night(
            asleepAt: asleepAt,
            wokeAt: wokeAt,
            origin: corrected ? .corrected : (measured ? .measured : .inferred),
            // **Une correction manuelle annule la duree mesuree.** Ce que
            // l'utilisateur a saisi est un couple coucher-lever ; garder a
            // cote une somme de fragments issue d'une lecture qu'il vient de
            // dementir donnerait une nuit dont la duree contredit les bornes.
            measuredSleep: corrected ? nil : sleptSeconds
        )
    }
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
