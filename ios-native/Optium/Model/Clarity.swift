import Foundation

/// La disponibilite du cerveau pour comprendre et reflechir.
///
/// Lue, jamais saisie. **La valeur numerique n'est jamais affichee** :
/// l'interface montre un mot. La regle est esthetique autant que
/// reglementaire — un score chiffre de performance cognitive s'approche d'un
/// diagnostic, ce que cette application ne pose pas.
enum ClarityLevel: String, Codable, CaseIterable {
    case low, medium, high

    /// Seuils du document : basse < 42 ≤ moyenne < 70 ≤ haute.
    init(value: Int) {
        switch value {
        case ..<42: self = .low
        case ..<70: self = .medium
        default: self = .high
        }
    }

    var word: String {
        switch self {
        case .low: "basse"
        case .medium: "moyenne"
        case .high: "haute"
        }
    }
}

struct Clarity {
    let value: Int
    var level: ClarityLevel { ClarityLevel(value: value) }
}

/// D'ou vient la clarte.
///
/// Le moteur reel — regularite 45 %, duree 30 %, circadien 25 %, alimente par
/// HealthKit avec CoreMotion en repli — se branchera ici sans que rien d'autre
/// ne bouge. C'est la raison d'etre de ce protocole : la porte doit pouvoir
/// etre eprouvee avant que la mesure n'existe.
protocol ClaritySource {
    func current() -> Clarity
    /// La fenetre du jour : le creneau ou une decision tient.
    func window(on day: Date) -> DateInterval
}

/// Source simulee, pilotee depuis les reglages.
///
/// Elle existe pour une raison precise : le moteur reel demande vingt-huit
/// nuits de donnees avant de vouloir dire quoi que ce soit, et la porte doit
/// etre testable aujourd'hui.
struct SimulatedClaritySource: ClaritySource {
    let level: ClarityLevel
    var calendar: Calendar = .current

    func current() -> Clarity {
        switch level {
        case .low: Clarity(value: 28)
        case .medium: Clarity(value: 55)
        case .high: Clarity(value: 82)
        }
    }

    /// Fenetre fixe du matin. Le placement circadien viendra avec le moteur.
    func window(on day: Date) -> DateInterval {
        let start = calendar.date(bySettingHour: 9, minute: 40, second: 0, of: day) ?? day
        let end = calendar.date(bySettingHour: 12, minute: 20, second: 0, of: day) ?? day
        return DateInterval(start: start, end: max(start, end))
    }
}
