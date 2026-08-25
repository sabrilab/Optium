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
    /// **Vingt heures, pas dix-sept.** La courbe s'arretait a dix-sept heures
    /// d'eveil, ce qui coupe la journee d'un mauvais dormeur avant qu'elle ne
    /// finisse : leve a 5 h apres une nuit courte, on depasse ce plafond a
    /// 22 h — soit exactement le moment ou l'on decide d'aller se coucher.
    func curve(from: Double = 0, to: Double = 20, step: Double = 0.25) -> [(hoursAwake: Double, clarity: Double)] {
        stride(from: from, through: to, by: step).map { ($0, clarity(hoursAwake: $0)) }
    }

    /// **La fenetre, derivee de la courbe** et non codee en dur.
    ///
    /// Elle valait auparavant « reveil + 2 h, pendant 2 h 40 », identique tous
    /// les jours, en ignorant le modele qui se trouvait juste a cote.
    ///
    /// **Piege corrige, et c'etait la fenetre codee en dur revenue sous une
    /// autre constante.** Le plancher valait `max(seuil de clarte haute,
    /// pic - 8)`. Le `max` faisait gagner le seuil de 70 des que le pic
    /// tombait sous 78 : aucun echantillon ne qualifiait, et toutes les nuits
    /// mediocres recevaient la meme fenetre minimale. Mesure : plafond 85 →
    /// 5 h ; 80 → 3 h 15 ; 78 → 2 h 15 ; **76 et tout ce qui est en dessous →
    /// 45 min, identiques**. Une nuit mediocre et une nuit catastrophique ne
    /// se distinguaient plus.
    ///
    /// Deux faits distincts avaient ete fusionnes, et ils sont desormais
    /// separes :
    ///
    /// - **ou est le meilleur moment** → une part du sommet. C'est la
    ///   fenetre, et elle varie continument avec la forme de la journee ;
    /// - **est-ce qu'il passe la barre** → le seuil de clarte haute. Ca
    ///   *qualifie* la fenetre — voir `qualifies` — ca ne la definit pas.
    ///
    /// - Returns: `(debut, fin)` en heures depuis le reveil.
    func window(minimumDuration: Double = 0.75) -> (start: Double, end: Double) {
        let samples = curve(from: 0.5, to: 15)
        guard let peak = samples.max(by: { $0.clarity < $1.clarity }) else { return (2, 4.67) }

        // **Un plancher proportionnel, pas soustractif.** « Huit points sous
        // le sommet » n'a pas de sens quand le sommet est a vingt : la marge
        // passe sous zero, la courbe ecretee y reste, et toute la journee
        // qualifie — une nuit catastrophique recevait ainsi la fenetre la plus
        // large de toutes. Mesure du defaut : 4,50 h identiques pour tous les
        // plafonds sous 74, contre 4,25 → 3,25 h en proportionnel.
        //
        // « A un dixieme du sommet » garde le meme sens a toute echelle, et
        // fait varier la largeur continument : la marge se resserre quand la
        // journee est basse, ce qui est exactement ce qu'on veut dire.
        let floor = peak.clarity * Self.windowFloorRatio
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

    /// La part du sommet au-dessus de laquelle un moment appartient encore a
    /// la fenetre.
    static let windowFloorRatio = 0.90

    /// La fenetre atteint-elle le seuil de clarte haute.
    ///
    /// **C'est une qualification, pas une definition.** Elle dit si le
    /// meilleur moment de la journee passe la barre, sans influer sur la
    /// largeur du creneau — les confondre etait le defaut precedent.
    var windowQualifies: Bool {
        let bounds = window()
        return clarity(hoursAwake: (bounds.start + bounds.end) / 2)
            >= Double(ClarityLevel.highThreshold)
    }
}
