import Foundation

/// Ce que l'application laisse aux widgets.
///
/// Un instantane plutot qu'un acces a la base : le widget n'a pas besoin de
/// savoir calculer une clarte, seulement de l'afficher. Lui donner le moteur
/// entier l'obligerait a partager le modele, les sources de sommeil et le
/// calendrier — pour un rendu qui tient en quatre valeurs.
///
/// Ecrit dans le groupe d'applications a chaque rafraichissement, lu par les
/// widgets et par la Live Activity a leur reveil.
struct WidgetSnapshot: Codable, Sendable {
    var clarityWord: String
    var isConfident: Bool
    /// 0…1
    var fill: Double
    /// 0…1
    var base: Double
    var windowStart: Date
    var windowEnd: Date
    var threadPhrase: String?
    var tierWord: String?
    var landingEarliest: Date?
    var landingLatest: Date?

    static let group = "group.com.sabrilab.optium.native"
    private static let key = "widget.snapshot"

    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(
            clarityWord: "haute", isConfident: true, fill: 0.78, base: 0.9,
            windowStart: Date(), windowEnd: Date().addingTimeInterval(2.67 * 3600),
            threadPhrase: "Choisir le modèle de tarification",
            tierWord: "Net", landingEarliest: nil, landingLatest: nil
        )
    }

    static func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: group),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return placeholder }
        return snapshot
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.group),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
