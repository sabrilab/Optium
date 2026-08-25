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

    // ── Le modele, pour que le widget calcule lui-meme ──
    //
    // **C'est le modele qui traverse le pont, plus une valeur.** L'instantane
    // etait fige : le widget affichait l'etat de la derniere ouverture de
    // l'application, et une politique horaire ne changeait rien puisque la
    // valeur relue etait la meme.
    //
    // `Vigilance` est une struct pure et `nonisolated`, sans dependance a
    // HealthKit : l'extension peut l'evaluer elle-meme, a n'importe quel
    // instant, et produire une chronologie de plusieurs entrees dans la
    // journee. Le liquide monte alors sur l'ecran d'accueil sans qu'on ouvre
    // l'application.

    /// Le plafond au reveil, 0…100.
    var ceilingAtWake: Double?
    /// Vitesse d'accumulation de la pression, en heures.
    var pressureTau: Double?
    /// L'instant du reveil, origine de la journee.
    var wakeAnchor: Date?

    /// Le modele reconstitue, quand l'instantane le porte.
    var vigilance: Vigilance? {
        guard let ceilingAtWake, let pressureTau else { return nil }
        return Vigilance(ceilingAtWake: ceilingAtWake, pressureTau: pressureTau)
    }

    /// La clarte a un instant donne, calculee dans l'extension.
    ///
    /// - Returns: `nil` sans modele — l'instantane retombe alors sur ses
    ///   valeurs figees, qui restent vraies au moment ou elles ont ete
    ///   ecrites.
    func live(at date: Date) -> (fill: Double, base: Double, word: String)? {
        guard let vigilance, let wakeAnchor, clarityWord != nil else { return nil }
        let awake = max(0, date.timeIntervalSince(wakeAnchor) / 3600)
        let value = Int(min(100, max(0, vigilance.clarity(hoursAwake: awake).rounded())))
        return (
            Double(value) / 100,
            vigilance.ceiling(hoursAwake: awake) / 100,
            ClarityLevel(value: value).word
        )
    }

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
