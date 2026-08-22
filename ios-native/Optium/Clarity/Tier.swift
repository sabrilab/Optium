import Foundation

/// Le palier de regularite.
///
/// Ancre sur la distribution reelle de la UK Biobank tant que la population
/// d'Optium est insuffisante — c'est ce qui resout le demarrage a froid :
/// un utilisateur du premier jour se situe deja par rapport a soixante mille
/// personnes plutot que par rapport a rien.
///
/// **L'embleme de chaque palier est le cerveau lui-meme**, a un taux de
/// remplissage croissant. Pas de medaille, pas de badge : le meme objet, plus
/// plein.
// `nonisolated` : un palier est une valeur pure, calculee a partir d'un
// indice. L'isolation par defaut du projet le rattachait au fil principal, ce
// qui empechait les outils de l'appel -- `Sendable`, consultes hors de ce
// fil -- de le construire.
nonisolated enum Tier: String, CaseIterable, Comparable {
    case murky, veiled, clear, limpid, crystalline

    /// Seuil bas de regularite, et part de la population au-dessus.
    var threshold: Double {
        switch self {
        case .crystalline: 87
        case .limpid: 82
        case .clear: 76
        case .veiled: 68
        case .murky: 0
        }
    }

    var word: String {
        switch self {
        case .crystalline: "Cristallin"
        case .limpid: "Limpide"
        case .clear: "Net"
        case .veiled: "Voilé"
        case .murky: "Trouble"
        }
    }

    /// Part de la population dans ce palier, d'apres la UK Biobank.
    var populationShare: Int {
        switch self {
        case .crystalline: 14
        case .limpid: 23
        case .clear: 26
        case .veiled: 22
        case .murky: 15
        }
    }

    /// Ou l'on se situe — en distribution, jamais par rapport a des personnes.
    ///
    /// Trois regles absolues : jamais de noms ni de profils, jamais le volume,
    /// et seulement les mesures reellement comparables.
    ///
    /// Elle vit ici et non dans un ecran : le journal l'affiche, et l'appel la
    /// lit par `TierTool`. Deux copies finiraient par dire deux choses.
    var situation: String {
        let above = Tier.allCases
            .filter { $0 > self }
            .reduce(0) { $0 + $1.populationShare }
        if above == 0 { return "Le palier le plus régulier. \(populationShare) % des gens y sont." }
        return "\(above) % des gens dorment plus régulièrement. \(populationShare) % sont à ton palier."
    }

    /// Ce que le palier **decrit**, jamais comment y arriver.
    ///
    /// **La frontiere est ici, et elle est mince.** Expliquer ce qu'un palier
    /// mesure informe ; expliquer comment monter d'un cran transforme le
    /// sommeil en score a optimiser, ce qui est exactement le mecanisme de
    /// l'orthosomnie. Aucune de ces phrases ne contient de conseil, de verbe a
    /// l'imperatif, ni de comparaison entre paliers en termes de merite.
    var explanation: String {
        switch self {
        case .crystalline:
            "Tes heures de sommeil se répètent presque à l’identique d’un jour sur l’autre. C’est la régularité la plus élevée que l’indice sache décrire — pas un objectif, un constat."
        case .limpid:
            "Tes horaires tiennent d’un jour sur l’autre, avec des écarts qui restent courts. Les décalages existent mais ne s’installent pas."
        case .clear:
            "Tes horaires se ressemblent la plupart du temps, avec des journées qui sortent du rang. C’est le palier le plus habité : un quart des gens s’y trouve."
        case .veiled:
            "Tes heures de coucher et de lever se déplacent nettement d’un jour sur l’autre. L’indice le voit sans pouvoir en dire la cause — un travail posté et des nuits blanches se ressemblent, vus d’ici."
        case .murky:
            "Tes horaires varient assez pour que deux journées consécutives se ressemblent peu. C’est ce que mesure l’indice, et rien de plus : il ne dit ni pourquoi, ni si c’est un problème pour toi."
        }
    }

    /// La probabilite d'etre dans le meme etat — endormi ou eveille — a la meme
    /// heure d'un jour sur l'autre, en pourcentage.
    ///
    /// C'est la definition litterale de l'indice, et elle est bien plus
    /// parlante que le score : l'echelle publiee va de -100 a 100, ramenee a
    /// 0-100, donc `part = (indice + 100) / 2`.
    var agreementShare: Int {
        Int(((threshold + 100) / 2).rounded())
    }

    /// L'etendue de l'indice couverte par ce palier.
    var range: ClosedRange<Double> {
        let above = Tier.allCases.filter { $0.threshold > threshold }.map(\.threshold).min()
        return threshold...(above ?? 100)
    }

    /// Remplissage de l'embleme, 0…1.
    var fill: Double {
        switch self {
        case .crystalline: 0.96
        case .limpid: 0.80
        case .clear: 0.60
        case .veiled: 0.38
        case .murky: 0.16
        }
    }

    init(regularity: Double) {
        self = Tier.allCases
            .sorted { $0.threshold > $1.threshold }
            .first { regularity >= $0.threshold } ?? .murky
    }

    /// Sur une mediane glissante, jamais sur la derniere valeur.
    ///
    /// C'est ce qui empeche d'y monter par gavage — une seule bonne nuit ne
    /// deplace pas une mediane de vingt-huit — et ce qui fait redescendre en
    /// cas d'arret.
    init?(rollingRegularity values: [Double]) {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        self.init(regularity: sorted[sorted.count / 2])
    }

    static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.fill < rhs.fill }
}
