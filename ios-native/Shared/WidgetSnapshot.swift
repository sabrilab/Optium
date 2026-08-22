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
    /// Absent tant qu'aucune mesure n'existe. L'instantane porte alors le
    /// nombre de nuits deja observees, qui est la seule chose vraie a dire.
    var clarityWord: String?
    var observedNights: Int
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

    /// Le remplissage grave dans la derniere capture Metal.
    ///
    /// La clarte evolue dans la journee par la composante circadienne, alors
    /// que l'image reste figee depuis la derniere execution de l'application.
    /// Un cerveau en decalage avec le mot affiche juste a cote serait pire que
    /// pas de cerveau — d'ou ces deux champs, qui permettent de retomber sur
    /// la silhouette.
    var brainImageFill: Double?
    var brainImageRenderedAt: Date?

    /// Vrai si la capture peut etre montree telle quelle.
    func brainImageIsFresh(at date: Date, fill: Double) -> Bool {
        guard let graved = brainImageFill, let rendered = brainImageRenderedAt else { return false }
        return abs(fill - graved) < 0.03 && date.timeIntervalSince(rendered) < 6 * 3600
    }

    /// Le fichier de capture, dans le conteneur du groupe.
    static var brainImageURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("brain.png")
    }

    static let group = "group.com.sabrilab.optium.native"
    private static let key = "widget.snapshot"

    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(
            clarityWord: "haute", observedNights: 21, fill: 0.78, base: 0.9,
            windowStart: Date(), windowEnd: Date().addingTimeInterval(2.67 * 3600),
            threadPhrase: "Choisir le modèle de tarification",
            tierWord: "Net", landingEarliest: nil, landingLatest: nil,
            brainImageFill: nil, brainImageRenderedAt: nil
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
