import Foundation

/// Le modele a deux processus, tenu separe.
///
/// **La clarte n'est pas un verdict du matin.** Elle l'etait : un mot pose au
/// reveil qui ne bougeait plus, parce que quatre-vingts pour cent du score
/// venait de la nuit et que seuls vingt points ondulaient. C'etait faux
/// physiologiquement, et surtout inutile — les jours ou l'on a mal dormi,
/// l'application annoncait qu'on etait en bas et n'avait rien d'autre a dire.
///
/// Deux forces se composent, et elles sont desormais separees dans le calcul
/// comme a l'ecran :
///
/// 1. **Ce que la nuit decide → le plafond.** Etabli au reveil par la
///    regularite et la duree, il **descend** ensuite a mesure que la pression
///    de sommeil s'accumule. C'est le terme de temps qui manquait.
/// 2. **Ce que l'heure decide → le niveau sous le plafond.** Le rythme
///    circadien, qui ondule independamment de la nuit passee. C'est
///    precisement pourquoi une mauvaise nuit comporte quand meme de bons
///    moments.
///
/// **La clarte de l'instant est ce que le plafond laisse passer de
/// l'oscillation** : au meilleur moment on touche le plafond, ailleurs on
/// tombe en dessous de l'amplitude du moment.
///
/// **Et l'amplitude croit avec la pression.** Mal dormir ne rend pas la
/// journee uniformement mauvaise : ca creuse l'ecart entre la meilleure et la
/// pire heure. Le *quand* compte davantage, pas moins. Une composition
/// multiplicative — plafond x oscillation — donnait l'inverse : elle aplatit
/// les mauvaises journees, ce qui contredit la litterature.
// `nonisolated` : un modele physiologique est une fonction pure du temps, et
// il doit pouvoir etre evalue hors du fil principal — le dessin de la courbe
// en echantillonne des dizaines de points.
nonisolated struct Vigilance {
    /// Le plafond au reveil, 0…100. Ce que la nuit a decide.
    let ceilingAtWake: Double
    /// Vitesse d'accumulation de la pression, en heures. **Plus la nuit est
    /// mauvaise, plus elle est courte** : le plafond part plus bas *et*
    /// descend plus vite.
    let pressureTau: Double

    // ── Les constantes du modele ──
    //
    // Calibrees numeriquement pour placer les trois moments que la
    // physiologie decrit : pic en fin de matinee, creux au milieu de
    // l'apres-midi, rebond en debut de soiree. Les modifier sans repasser par
    // `VigilanceTests` casse cette structure en silence.

    /// Ce que la journee entiere coute au plafond, a pression saturee.
    static let dayCost = 20.0
    /// Amplitude de l'oscillation a pression nulle, puis ce que la pression y
    /// ajoute. **Le second est le terme qui creuse les mauvaises journees.**
    static let amplitudeBase = 7.0
    static let amplitudeGain = 24.0
    /// L'inertie du reveil : forte au lever, dissipee en une heure et demie.
    /// Sans elle, le maximum de la journee tombe a l'instant du reveil.
    static let inertia = 20.0
    static let inertiaTau = 1.15

    // Deux harmoniques. La composante sur vingt-quatre heures porte le grand
    // mouvement ; celle sur douze creuse l'apres-midi et produit le rebond du
    // soir. Une seule sinusoide ne peut pas faire les deux.
    private static let weight24 = 0.55
    private static let phase24 = 6.0
    // Le poids de la 12 h decide de la profondeur du creux d'apres-midi et de
    // la hauteur du rebond. A 0,55 le rebond ne valait qu'un point : invisible,
    // donc inexistant pour l'utilisateur. A 0,95 il vaut 4,6 points apres une
    // bonne nuit et 7,2 apres une mauvaise — plus marque quand la nuit a ete
    // mauvaise, ce qui est precisement la propriete a montrer.
    private static let weight12 = 0.95
    private static let phase12 = 2.0

    /// Bornes du rythme brut, pour le ramener a 0…1.
    private static let rhythmBounds: (min: Double, max: Double) = {
        let samples = stride(from: 0.0, through: 24.0, by: 0.05).map(rawRhythm)
        return (samples.min() ?? -1, samples.max() ?? 1)
    }()

    private static func rawRhythm(_ hoursAwake: Double) -> Double {
        weight24 * cos(2 * .pi * (hoursAwake - phase24) / 24)
      + weight12 * cos(2 * .pi * (hoursAwake - phase12) / 12)
    }

    // ── Les trois grandeurs ──

    /// La pression de sommeil, 0…1. Monte depuis le reveil, de facon
    /// monotone. Elle ne redescend qu'en dormant.
    func pressure(hoursAwake: Double) -> Double {
        1 - exp(-max(0, hoursAwake) / pressureTau)
    }

    /// **Le plafond a cet instant** : ce que la nuit permet, moins ce que la
    /// journee a deja coute.
    func ceiling(hoursAwake: Double) -> Double {
        max(0, min(100, ceilingAtWake - Self.dayCost * pressure(hoursAwake: hoursAwake)))
    }

    /// L'oscillation circadienne, 0…1. **Independante de la nuit passee** —
    /// c'est ce qui garantit qu'une mauvaise nuit garde de bons moments.
    func rhythm(hoursAwake: Double) -> Double {
        let bounds = Self.rhythmBounds
        return (Self.rawRhythm(hoursAwake) - bounds.min) / (bounds.max - bounds.min)
    }

    /// De combien l'oscillation peut faire descendre sous le plafond.
    func amplitude(hoursAwake: Double) -> Double {
        Self.amplitudeBase + Self.amplitudeGain * pressure(hoursAwake: hoursAwake)
    }

    /// **La clarte de l'instant.**
    func clarity(hoursAwake: Double) -> Double {
        let below = amplitude(hoursAwake: hoursAwake) * (1 - rhythm(hoursAwake: hoursAwake))
        let inertia = Self.inertia * exp(-max(0, hoursAwake) / Self.inertiaTau)
        return max(0, min(100, ceiling(hoursAwake: hoursAwake) - below - inertia))
    }

    // ── La journee entiere ──

    /// La courbe, echantillonnee. Sert au dessin et a la derivation de la
    /// fenetre.
    func curve(from: Double = 0, to: Double = 17, step: Double = 0.25) -> [(hoursAwake: Double, clarity: Double)] {
        stride(from: from, through: to, by: step).map { ($0, clarity(hoursAwake: $0)) }
    }

    /// **La fenetre, derivee de la courbe** et non codee en dur.
    ///
    /// Elle valait auparavant « reveil + 2 h, pendant 2 h 40 », identique tous
    /// les jours, en ignorant le modele qui se trouvait juste a cote. Elle
    /// entoure desormais le sommet de la journee, et se retrecit d'elle-meme
    /// apres une mauvaise nuit — sans qu'aucune regle ne le dise.
    ///
    /// Le plancher est le plus exigeant des deux : le seuil de clarte haute,
    /// ou le sommet moins huit points. Le second existe pour les journees ou
    /// rien n'atteint le seuil : la fenetre s'y reduit a la crete, ce qui est
    /// honnete — c'est bien le meilleur moment disponible, meme s'il n'est pas
    /// bon.
    ///
    /// - Returns: `(debut, fin)` en heures depuis le reveil.
    func window(minimumDuration: Double = 0.75) -> (start: Double, end: Double) {
        let samples = curve(from: 0.5, to: 15)
        guard let peak = samples.max(by: { $0.clarity < $1.clarity }) else { return (2, 4.67) }

        let floor = max(Double(ClarityLevel.highThreshold), peak.clarity - 8)
        guard let peakIndex = samples.firstIndex(where: { $0.hoursAwake == peak.hoursAwake })
        else { return (2, 4.67) }

        var low = peakIndex, high = peakIndex
        while low > 0, samples[low - 1].clarity >= floor { low -= 1 }
        while high < samples.count - 1, samples[high + 1].clarity >= floor { high += 1 }

        var start = samples[low].hoursAwake
        var end = samples[high].hoursAwake
        // Une fenetre vide n'aiderait personne : on garde la crete, meme
        // etroite. « Ta fenetre est plus etroite aujourd'hui » est une
        // information ; « tu n'as aucune fenetre » n'en est pas une.
        if end - start < minimumDuration {
            let half = minimumDuration / 2
            start = max(0.5, peak.hoursAwake - half)
            end = start + minimumDuration
        }
        return (start, end)
    }
}
