import Foundation

/// Ce sur quoi une affirmation de l'application repose.
///
/// **La crédibilité vient de ce qu'on refuse d'affirmer, pas de ce qu'on
/// affirme.** Une application de sommeil qui cite trois études pour se donner
/// de l'autorité est ordinaire ; une qui dit « cette partie repose sur un
/// effet contesté » ne l'est pas — et c'est ce que le corpus permet, parce que
/// la vérification qui l'a produit était honnête.
///
/// Trois règles tenues dans chaque entrée :
///
/// 1. **Le niveau de preuve est dit**, jamais sous-entendu. Une méta-analyse
///    sur 60 977 participants et un rapport de source secondaire ne pèsent pas
///    pareil, et le lecteur a le droit de le savoir.
/// 2. **Ce que l'étude ne montre pas est dit aussi.** C'est la partie qui
///    manque partout ailleurs, et celle qui vaut le plus.
/// 3. **Aucune image d'illustration.** Une photo de chercheur ou de laboratoire
///    qui n'a rien à voir avec le travail cité emprunte une autorité au lieu de
///    l'établir. Le texte porte tout.
struct Evidence: Identifiable, Sendable {
    let id: String
    /// Ce que l'application affirme, et qui a besoin d'être fondé.
    let claim: String
    /// La référence, telle qu'on la citerait.
    let reference: String
    /// Le niveau de vérification, repris du document de vérification.
    let verification: Verification
    /// Ce que le travail établit.
    let shows: String
    /// **Ce qu'il n'établit pas.** Champ obligatoire.
    let doesNotShow: String
    /// Comment l'application s'en sert.
    let usedFor: String

    enum Verification: String, Sendable {
        case fullText = "Texte intégral lu"
        case abstract = "Résumé lu"
        case secondary = "Rapporté par une source secondaire"

        /// Ce que ce niveau autorise à dire.
        var caution: String {
            switch self {
            case .fullText: "La lecture est de première main."
            case .abstract: "Seul le résumé a été lu — les méthodes n’ont pas été vérifiées ligne à ligne."
            case .secondary: "La source primaire n’a pas été lue. À traiter comme un signal, pas comme une preuve."
            }
        }
    }
}

/// Le corpus, tiré de `docs/etudes-fondements.md`.
///
/// **Il n'est pas exhaustif et ne cherche pas à l'être.** Une entrée n'existe
/// que là où l'application affirme quelque chose qu'un lecteur pourrait
/// légitimement contester.
enum EvidenceLibrary {
    static let regularity = Evidence(
        id: "regularity",
        claim: "La régularité du sommeil pèse plus que sa durée.",
        reference: "Windred et coll., « Sleep regularity is a stronger predictor of mortality risk than sleep duration », *Sleep*, 2023. 60 977 participants de la UK Biobank. doi 10.1093/sleep/zsad253",
        verification: .abstract,
        shows: "La régularité des horaires prédit mieux le risque de mortalité que le nombre d’heures dormies. C’est ce qui lui vaut le poids le plus élevé dans le calcul — 0,5 contre 0,3 pour la durée.",
        doesNotShow: "Rien sur le jugement, la décision ou la clarté mentale. Le lien entre régularité et qualité d’une décision n’est établi nulle part, et Optium le pose comme hypothèse, pas comme fait.",
        usedFor: "Le poids de la régularité dans le plafond, et l’échelle des paliers — dont la médiane, 81, et l’écart interquartile, 73,8 à 86,3, viennent de cette cohorte."
    )

    static let vigilance = Evidence(
        id: "vigilance",
        claim: "Ce que le manque de sommeil atteint, c’est la vigilance — pas l’intelligence.",
        reference: "Lim & Dinges, « A meta-analysis of the impact of short-term sleep deprivation on cognitive variables », *Psychological Bulletin*, 2010, 136, 375-389. 70 articles, 147 tests cognitifs.",
        verification: .abstract,
        shows: "Les tailles d’effet les plus grandes portent sur les lapsus d’attention simple. Les plus faibles, non significatives, portent sur l’exactitude du raisonnement.",
        doesNotShow: "Que la qualité du raisonnement s’effondre. C’est précisément ce que l’étude écarte — et c’est pourquoi Optium ne dit jamais « tu réfléchis moins bien », mais mesure un proxy de vigilance.",
        usedFor: "Le cadrage entier du produit : Optium mesure une disponibilité, jamais une capacité."
    )

    static let errorDetection = Evidence(
        id: "error-detection",
        claim: "On ne devient pas aveugle à sa fatigue. On devient moins capable d’attraper ses propres erreurs.",
        reference: "Bermudez et coll., *Sleep Medicine Reviews*, 2021. Revue systématique et méta-analyse, 28 études retenues, 11 exploitables. PubMed 33894599.",
        verification: .abstract,
        shows: "La détection d’erreur est dégradée après privation de sommeil, de façon constante à travers les études.",
        doesNotShow: "Que le fatigué se croit performant. **La revue trouve l’inverse** : les estimations de sa propre performance sont plutôt plus conservatrices. Le récit courant est contredit, et une revue distincte (*Metacognition and Learning*, 2017) ne trouve pas non plus d’effet sur les jugements de confiance.",
        usedFor: "La porte. Si savoir qu’on est fatigué suffisait, une notification ferait l’affaire — c’est parce qu’on peut le savoir et rater l’erreur quand même qu’une interruption au moment de conclure a un sens."
    )

    static let circadian = Evidence(
        id: "circadian",
        claim: "L’heure de la journée compte, mais c’est la partie la moins établie du calcul.",
        reference: "*Collabra: Psychology*, 2023, sur l’effet de synchronie heure du jour × chronotype.",
        verification: .abstract,
        shows: "L’effet de synchronie — mieux performer à l’heure qui correspond à son chronotype — est largement admis et soutenu par plusieurs travaux sur la fonction exécutive.",
        doesNotShow: "**Un gain cognitif général et robuste.** Cet article conclut à son absence, et évoque un possible artéfact méthodologique. C’est pourquoi le poids du circadien a été abaissé de 0,25 à 0,2, au profit de la régularité.",
        usedFor: "L’oscillation de la journée : le pic du matin, le creux de l’après-midi, le rebond du soir."
    )

    static let stages = Evidence(
        id: "stages",
        claim: "Optium ne lit que l’heure du coucher, celle du lever, et la durée — jamais les stades de sommeil.",
        reference: "Validations 2024 de montres grand public contre polysomnographie, dont une étude sur 127 adultes (Apple Watch Series 8).",
        verification: .secondary,
        shows: "Sommeil contre éveil : au-dessus de 95 % de sensibilité. Durée totale : à ± 12 minutes environ. C’est très bon, et c’est exactement ce qu’Optium utilise.",
        doesNotShow: "**Que les stades soient fiables.** Le sommeil profond est détecté entre 50 et 64 % seulement, le paradoxal autour de 82 %. Une « durée de sommeil profond » bâtirait sur la seule partie non fiable de la mesure.",
        usedFor: "Une interdiction inscrite dans le code : aucune composante du moteur ne doit jamais reposer sur les stades."
    )

    static let pomodoro = Evidence(
        id: "pomodoro",
        claim: "Découper le temps ne dit rien de l’état dans lequel on l’aborde.",
        reference: "Smits, Wenzel & de Bruin, *Behavioral Sciences*, 2025, 15(7), 861. 94 étudiants, session de deux heures, trois conditions. doi 10.3390/bs15070861",
        verification: .fullText,
        shows: "Aucune différence significative sur l’achèvement des tâches (p = 0,854) ni sur le flow (p = 0,774) entre pauses auto-régulées, Pomodoro et Flowtime. La fatigue monte plus vite sous Pomodoro, et la motivation décline plus vite.",
        doesNotShow: "**Que le Pomodoro ne marche pas.** Les auteurs précisent que ces différences de pente n’ont pas produit d’écart sur les moyennes globales. Échantillon de 94 étudiants, deux heures, contexte scolaire. C’est un signal, pas une réfutation.",
        usedFor: "Le positionnement du produit, et rien d’autre : Optium ne découpe pas le temps, il lit l’état."
    )

    static let orthosomnia = Evidence(
        id: "orthosomnia",
        claim: "Optium n’affiche aucun score de sommeil, aucune série à ne pas briser.",
        reference: "Baron et coll., 2017, sur l’orthosomnie — la recherche perfectionniste d’un sommeil parfait, induite par les traqueurs.",
        verification: .secondary,
        shows: "Le suivi chiffré du sommeil peut produire l’anxiété qu’il prétend mesurer, et dégrader le sommeil qu’il observe.",
        doesNotShow: "La référence exacte n’a pas été revérifiée lors de la vérification des fondements. **Le garde-fou est maintenu quand même** : le risque est plausible et le coût de s’en prémunir est nul.",
        usedFor: "Trois interdits tenus partout : aucun score global, aucune série, rien de prédictif sur le sommeil."
    )

    static let all: [Evidence] = [
        regularity, vigilance, errorDetection, circadian, stages, pomodoro, orthosomnia,
    ]
}
