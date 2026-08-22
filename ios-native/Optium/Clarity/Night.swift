import Foundation

/// Une nuit observee.
///
/// Ni saisie ni declaree : deduite du sommeil enregistre quand il existe, du
/// mouvement du telephone sinon.
struct Night: Equatable, Hashable {
    /// D'ou vient une nuit.
    ///
    /// **La distinction n'est pas cosmetique, elle decide de ce que
    /// l'application a le droit d'affirmer.** Le projet pose comme regle de
    /// n'afficher que des faits verifiables par l'utilisateur : « tu as dormi
    /// 5 h 10 » se controle dans Sante, « ta regularite est de 71 » nulle
    /// part. Or une nuit deduite du mouvement du telephone **ne se controle
    /// pas non plus dans Sante** — l'annoncer comme un fait mesure violait la
    /// regle en croyant la respecter.
    enum Origin: String, Codable, Sendable {
        /// Enregistree par Sante. Verifiable hors de l'application.
        case measured
        /// Deduite de l'immobilite du telephone. Une estimation, et elle doit
        /// se presenter comme telle.
        case inferred
    }

    let asleepAt: Date
    let wokeAt: Date
    var origin: Origin = .measured

    /// Le temps **reellement endormi**, reveils intra-nuit deduits.
    ///
    /// **L'amplitude n'est pas la duree, et les confondre gonflait toutes les
    /// nuits.** Une nuit arrive de Sante en dizaines de fragments ; se
    /// reveiller quarante minutes a 3 h laisse un trou que le recollage
    /// franchit, et l'ecart coucher-lever comptait ce trou comme du sommeil.
    ///
    /// Vaut l'amplitude par defaut : les nuits deduites du mouvement n'ont
    /// qu'un bloc, et les tests qui construisent une nuit a la main decrivent
    /// un sommeil continu.
    private var measuredSleep: TimeInterval?

    /// Ce qui alimente le score de duree : le sommeil, pas le temps passe au
    /// lit.
    var duration: TimeInterval { measuredSleep ?? span }

    /// Du coucher au lever, trous compris. C'est elle qui situe la nuit dans
    /// la journee, donc elle qui alimente la regularite.
    var span: TimeInterval { wokeAt.timeIntervalSince(asleepAt) }

    init(asleepAt: Date, wokeAt: Date, origin: Origin = .measured,
         measuredSleep: TimeInterval? = nil) {
        self.asleepAt = asleepAt
        self.wokeAt = wokeAt
        self.origin = origin
        self.measuredSleep = measuredSleep
    }

    func contains(_ date: Date) -> Bool {
        date >= asleepAt && date < wokeAt
    }
}

/// L'indice de regularite du sommeil.
///
/// La probabilite, en pourcentage, d'etre dans le meme etat — endormi ou
/// eveille — a deux instants separes de vingt-quatre heures.
///
/// C'est le socle du barème pour trois raisons : il est publie et calculable,
/// il recompense la discipline et non le volume, et il fournit une
/// distribution de population reelle, ce qui resout le demarrage a froid.
///
/// Reference : Windred et al., *Sleep* (2023), doi 10.1093/sleep/zsad253.
/// Mediane 81 sur 60 977 participants de la UK Biobank, intervalle
/// interquartile 73,8-86,3. La regularite y predit mieux la mortalite que la
/// duree, et se corrige plus facilement.
enum SleepRegularity {
    /// Pas d'echantillonnage. Cinq minutes suffisent : la mesure porte sur la
    /// coincidence de deux journees, pas sur la minute d'endormissement.
    static let epoch: TimeInterval = 300

    /// - Returns: `nil` si la periode couvre moins de deux jours — il faut
    ///   deux journees pour en comparer une a la suivante.
    static func index(nights: [Night], calendar: Calendar) -> Double? {
        guard let first = nights.map(\.asleepAt).min(),
              let last = nights.map(\.wokeAt).max() else { return nil }

        // La grille part du premier endormissement, pas de minuit. Les heures
        // qui precedent la premiere nuit ne sont pas observees : les compter
        // comme de l'eveil les ferait passer pour des desaccords, et une
        // personne parfaitement reguliere ne pourrait jamais atteindre 100.
        let total = Int(last.timeIntervalSince(first) / epoch)
        let perDay = Int(86_400 / epoch)
        guard total > perDay else { return nil }

        var asleep = [Bool](repeating: false, count: total)
        for index in 0..<total {
            let instant = first.addingTimeInterval(Double(index) * epoch)
            asleep[index] = nights.contains { $0.contains(instant) }
        }

        // On ne compare que les paires dont les deux instants sont observes :
        // la derniere journee n'a pas de lendemain dans l'enregistrement.
        var agreements = 0
        let comparisons = total - perDay
        for index in 0..<comparisons where asleep[index] == asleep[index + perDay] {
            agreements += 1
        }

        // -100 + 200 x part d'accord : l'echelle publiee va de -100 a 100, on
        // la ramene a 0-100 comme le fait la litterature appliquee.
        let raw = -100.0 + 200.0 * Double(agreements) / Double(comparisons)
        return min(100, max(0, raw))
    }

    /// Le rang de population d'un indice, 0…100.
    ///
    /// **Un SRI n'est pas un pourcentage, et le lire comme tel fausse tout.**
    /// Son echelle utile est etroite : la moitie de la UK Biobank tient entre
    /// 73,8 et 86,3. Un indice de 68 designe donc le cinquieme le moins
    /// regulier de la population — mais entre brut dans une somme ponderee, il
    /// vaut « 68 sur 100 », c'est-a-dire une mention honorable. Toute la
    /// distribution de clarte s'en trouvait tassee vers le haut : un profil se
    /// couchant entre 19 h et 3 h obtenait une clarte haute.
    ///
    /// Cette fonction rend a l'indice son rang. Les points d'appui sont les
    /// quartiles publies — 73,8 / 81 / 86,3 — places a 25, 50 et 75, et non
    /// des seuils choisis. Les extremites, 60 et 95, bornent la plage
    /// observable ; elles sont les deux seules valeurs decidees ici.
    ///
    /// L'interpolation est lineaire par morceaux : la vraie courbe cumulative
    /// n'est pas publiee, et lui substituer une sigmoide inventee ajouterait
    /// une precision que la source ne porte pas.
    static func populationScore(_ index: Double) -> Double {
        let anchors: [(sri: Double, rank: Double)] = [
            (60, 0), (73.8, 25), (81, 50), (86.3, 75), (95, 100),
        ]
        if index <= anchors[0].sri { return 0 }
        if index >= anchors[anchors.count - 1].sri { return 100 }
        for (low, high) in zip(anchors, anchors.dropFirst()) where index <= high.sri {
            let share = (index - low.sri) / (high.sri - low.sri)
            return low.rank + share * (high.rank - low.rank)
        }
        return 100
    }
}
