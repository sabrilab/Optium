import Foundation

/// Une composante du calcul, et ce qui lui manque.
enum ClarityComponent: String, CaseIterable {
    case regularity, duration, circadian
}

/// Ce qu'une composante a coute a la lecture.
///
/// `amount = poids × (1 − valeur normalisee)` : la contribution qu'elle
/// aurait apportee en plus si elle avait ete au maximum. C'est ce qui permet
/// de citer, a la porte, le fait qui pese le plus — et non le plus bas en
/// valeur absolue, qui pourrait etre la composante la moins ponderee.
struct ClarityShortfall {
    let component: ClarityComponent
    let amount: Double
}

/// Ce que le moteur a lu, et ce qu'il sait de sa propre fiabilite.
struct ClarityReading {
    /// **Absente** tant que trop peu de nuits ont ete observees.
    ///
    /// Optionnelle et non pas « moyenne par defaut » : une valeur inventee se
    /// propagerait dans le cerveau, dans les widgets et jusqu'a la porte, ou
    /// elle produirait un refus injustifiable.
    let clarity: Clarity?
    let observedNights: Int
    /// Combien de ces nuits ont ete **devinees** plutot que mesurees.
    ///
    /// Elle existe pour que l'affichage puisse le dire. Une lecture qui repose
    /// sur des nuits deduites du mouvement du telephone reste utilisable —
    /// c'est la seule source pour qui n'enregistre pas son sommeil — mais elle
    /// ne peut pas etre presentee comme un fait verifiable dans Sante.
    let inferredNights: Int
    let regularity: Double?
    let window: DateInterval
    /// 0…1 : ce que la cafeine encore active retirera a la nuit **prochaine**.
    let projectedNightPenalty: Double

    // ── Faits mesures ──
    //
    // Des entrees, jamais des sorties. « Tu as dormi 5 h 10 » est verifiable
    // par l'utilisateur dans Sante ; « ta regularite est de 71 » ne l'est
    // nulle part, et c'est ce qui le disqualifie a l'affichage.

    /// Duree du dernier sommeil observe.
    let lastNightDuration: TimeInterval?
    /// Amplitude des trois derniers levers. Un fait, la ou le SRI est un score.
    let wakeSpread: TimeInterval?

    /// Les manques, du plus grand au plus petit.
    let shortfalls: [ClarityShortfall]

    // ── Ce que le modele a deux processus rend en plus ──

    /// **Le plafond a cet instant**, 0…100 : ce que la nuit permet, moins ce
    /// que la journee a deja coute. `nil` sans mesure.
    let ceiling: Double?
    /// Heures ecoulees depuis le reveil. Sert a situer le present sur la
    /// courbe.
    let hoursAwake: Double

    /// **La fenetre, quand elle est mesuree.** `nil` sous le seuil.
    ///
    /// `window` porte toujours un intervalle, y compris sans aucune nuit : il
    /// vaut alors « lever habituel + 2 h, pendant 2 h 40 », une valeur que
    /// personne n'a mesuree. Elle sortait par quatre portes — la carte, la
    /// notification quotidienne, le widget et l'intention — en se presentant
    /// partout comme un fait.
    ///
    /// **Tout ce qui affirme doit lire celle-ci** ; `window` ne reste que pour
    /// les vues qui ont besoin d'un intervalle a dessiner.
    var measuredWindow: DateInterval? { clarity == nil ? nil : window }

    /// L'instant du reveil, pour convertir « heures depuis le lever » en heure
    /// d'horloge. **C'est la seule facon d'ecrire une heure lisible** sur une
    /// echelle dont l'origine est le lever et non minuit.
    let wokeAt: Date?

    /// Un point de la journee.
    struct CurvePoint: Equatable, Identifiable {
        let at: Date
        let hoursAwake: Double
        let clarity: Double
        let ceiling: Double

        var id: Double { hoursAwake }
    }

    /// La journee entiere, echantillonnee. **C'est elle qu'on dessine** : le
    /// creux de l'apres-midi doit se voir comme passager, avec un rebond
    /// derriere.
    let curve: [CurvePoint]

    /// Le niveau **avec hysteresis**, qui peut differer du seuil brut.
    ///
    /// Depuis que la clarte evolue dans la journee, elle traverse les seuils :
    /// sans hysteresis, la porte s'ouvrirait et se fermerait autour de 42 ou
    /// de 70. Voir `ClarityLevel.level(value:previous:)`.
    var level: ClarityLevel = .medium

    /// La lecture repose-t-elle entierement sur des nuits devinees.
    ///
    /// Le cas ordinaire de quelqu'un sans montre : ce n'est pas un defaut, et
    /// l'application doit continuer de fonctionner. Mais elle doit le dire —
    /// et la porte, quand elle refuse, doit nommer sa source.
    var restsOnInference: Bool {
        observedNights > 0 && inferredNights == observedNights
    }

    /// Les manques que la porte a le droit de citer.
    ///
    /// Un seul, sauf si le deuxieme est a moins de 15 % du premier. Jamais
    /// trois : au-dela de deux faits, la phrase cesse d'expliquer et se met a
    /// accabler.
    var citedShortfalls: [ClarityShortfall] {
        guard let first = shortfalls.first else { return [] }
        guard let second = shortfalls.dropFirst().first,
              first.amount - second.amount <= first.amount * 0.15 else { return [first] }
        return [first, second]
    }
}

/// Le calcul de la clarte.
///
/// **La formule n'est pas validee.** Aucune litterature ne relie directement
/// le sommeil a la qualite du jugement. Ce qui est etabli, c'est la
/// hierarchie des atteintes : la meta-analyse de Lim & Dinges (2010,
/// *Psychological Bulletin* 136, 375-389 — 70 articles, 147 tests cognitifs)
/// trouve les tailles d'effet les plus grandes sur les lapsus d'attention
/// simple, et les plus faibles, non significatives, sur l'exactitude du
/// raisonnement.
///
/// **Conséquence : Optium mesure un proxy de vigilance, pas d'intelligence.**
/// Les poids suivent les tailles d'effet, et l'ensemble doit etre traite comme
/// une hypothese instrumentee, pas comme une verite.
///
/// La ponderation d'origine reservait 40 % aux bascules entre applications.
/// Ce signal exige l'habilitation Family Controls, soumise a approbation
/// d'Apple, et son rapport tourne dans une extension muree qui ne peut pas le
/// renvoyer a l'application. Il a donc ete abandonne, et son poids reparti.
enum ClarityEngine {
    // **Ce que la nuit decide, et rien d'autre.**
    //
    // Les trois composantes etaient moyennees en un seul nombre — regularite
    // 0,5, duree 0,3, circadien 0,2. C'est la raison mecanique pour laquelle
    // rien ne bougeait dans la journee : quatre-vingts pour cent du score
    // etait fige au reveil, et il ne restait que vingt points de marge.
    //
    // Le circadien a quitte la somme : il n'est plus une composante mais
    // l'oscillation elle-meme, dans `Vigilance`. Les deux qui restent gardent
    // leur rapport et sont renormalisees — la regularite domine toujours,
    // parce que Windred et coll. (2023) la trouvent plus predictive que la
    // duree.
    static let regularityWeight = 0.5 / 0.8
    static let durationWeight = 0.3 / 0.8

    /// En deca, la clarte n'existe pas.
    ///
    /// Trois nuits est le minimum pour qu'une amplitude de levers ait un sens.
    /// Le seuil est bas a dessein : les sources rendent leur historique des la
    /// premiere seconde — HealthKit sur des mois, CoreMotion sur sept jours —
    /// donc quelqu'un qui installe l'application a deja des nuits. Un seuil
    /// haut le rendrait muet alors que la mesure existe.
    static let minimumNights = 3

    /// Bornes de la cible de duree.
    ///
    /// La mediane personnelle informe la cible, elle ne la definit pas seule.
    /// Sans ces bornes, quelqu'un qui dort chroniquement cinq heures voit sa
    /// mediane s'aligner dessus et obtient toujours un bon score — c'est
    /// exactement le piege que l'application cherche a nommer : en restriction
    /// chronique, la somnolence ressentie plafonne alors que la performance
    /// continue de decliner, et les gens perdent la capacite de se juger.
    static let targetRange = (7.0 * 3600)...(9.0 * 3600)

    /// Score de duree, 0…100.
    ///
    /// **Penalise dans les deux sens.** La relation duree/mortalite est en U :
    /// recompenser lineairement le sommeil long serait faux, et pousserait au
    /// mauvais comportement.
    static func durationScore(lastNight: TimeInterval, median: TimeInterval) -> Double {
        let target = min(max(median, targetRange.lowerBound), targetRange.upperBound) / 3600
        // Une heure et demie d'ecart coute environ un tiers du score.
        let deviation = (lastNight / 3600 - target) / 1.5
        return 100 * exp(-deviation * deviation)
    }

    /// Vitesse d'accumulation de la pression, en heures.
    ///
    /// **C'est la duree de la nuit qui la decide**, pas la regularite : une
    /// nuit courte laisse une dette qui fait monter la pression plus vite le
    /// lendemain. La regularite, elle, joue sur le point de depart.
    ///
    /// De 6 h 30 apres une nuit tres courte a 13 h 30 apres une nuit pleine.
    static func pressureTau(durationScore: Double) -> Double {
        6.5 + max(0, min(100, durationScore)) / 100 * 7
    }

    /// Heures ecoulees depuis le reveil.
    ///
    /// Le vrai lever quand il est connu et date d'aujourd'hui ; le lever
    /// habituel sinon. **Jamais une valeur negative** : consulte l'application
    /// avant son lever habituel, on est encore dans la nuit precedente.
    static func hoursAwake(
        now: Date, lastNight: Night?, habitualWake: Date, calendar: Calendar
    ) -> Double {
        if let woke = lastNight?.wokeAt, now > woke, now.timeIntervalSince(woke) < 24 * 3600 {
            return now.timeIntervalSince(woke) / 3600
        }
        let parts = calendar.dateComponents([.hour, .minute], from: habitualWake)
        let wakeHour = Double(parts.hour ?? 7) + Double(parts.minute ?? 0) / 60
        let nowParts = calendar.dateComponents([.hour, .minute], from: now)
        let hour = Double(nowParts.hour ?? 0) + Double(nowParts.minute ?? 0) / 60
        var awake = hour - wakeHour
        if awake < 0 { awake += 24 }
        return awake
    }

    /// Le modele du jour, sans l'evaluer.
    ///
    /// Expose separement pour que `ClarityStore` puisse le garder et
    /// reevaluer la clarte a la minute sans relire Sante.
    static func vigilance(nights: [Night], calendar: Calendar = .current) -> Vigilance? {
        let recent = nights.sorted { $0.asleepAt < $1.asleepAt }
        guard recent.count >= minimumNights, let last = recent.last else { return nil }

        let regularity = SleepRegularity.index(nights: recent, calendar: calendar) ?? 81
        let regularityScore = SleepRegularity.populationScore(regularity)
        let durations = recent.map(\.duration).sorted()
        let median = durations[durations.count / 2]
        let duration = durationScore(lastNight: last.duration, median: median)

        return Vigilance(
            ceilingAtWake: regularityWeight * regularityScore + durationWeight * duration,
            pressureTau: pressureTau(durationScore: duration)
        )
    }

    /// - Parameter previousLevel: le niveau affiche juste avant, pour
    ///   l'hysteresis. `nil` a la premiere lecture.
    static func reading(
        nights: [Night],
        now: Date,
        coffees: [Date] = [],
        calendar: Calendar = .current,
        previousLevel: ClarityLevel? = nil
    ) -> ClarityReading {
        let recent = nights.sorted { $0.asleepAt < $1.asleepAt }
        let habitualWake = averageWake(of: recent, calendar: calendar) ?? defaultWake(now, calendar)
        let penalty = caffeinePenalty(coffees: coffees, bedtime: projectedBedtime(habitualWake, calendar), now: now)

        let lastNight = recent.last?.duration
        let spread = wakeSpread(of: recent.suffix(3), calendar: calendar)
        let awake = hoursAwake(now: now, lastNight: recent.last, habitualWake: habitualWake, calendar: calendar)

        guard recent.count >= minimumNights, let last = recent.last else {
            // Sans mesure, la fenetre reste celle du lever habituel : c'est la
            // seule chose vraie qu'on puisse en dire.
            return ClarityReading(
                clarity: nil,
                observedNights: recent.count,
                inferredNights: recent.count { $0.origin == .inferred },
                regularity: nil,
                window: defaultWindow(habitualWake: habitualWake, now: now, calendar: calendar),
                projectedNightPenalty: penalty,
                lastNightDuration: lastNight,
                wakeSpread: spread,
                shortfalls: [],
                ceiling: nil,
                hoursAwake: awake,
                wokeAt: nil,
                curve: []
            )
        }

        // Le SRI brut est conserve pour l'affichage et les faits ; c'est son
        // rang de population qui entre dans le plafond. Voir
        // `SleepRegularity.populationScore`.
        let regularity = SleepRegularity.index(nights: recent, calendar: calendar) ?? 81
        let regularityScore = SleepRegularity.populationScore(regularity)
        let durations = recent.map(\.duration).sorted()
        let median = durations[durations.count / 2]
        let duration = durationScore(lastNight: last.duration, median: median)

        // **Ce que la nuit decide : le plafond au reveil.**
        let ceilingAtWake = regularityWeight * regularityScore + durationWeight * duration
        let vigilance = Vigilance(
            ceilingAtWake: ceilingAtWake,
            pressureTau: pressureTau(durationScore: duration)
        )

        let value = vigilance.clarity(hoursAwake: awake)
        let ceiling = vigilance.ceiling(hoursAwake: awake)

        // La fenetre est derivee de la courbe, jamais codee en dur.
        let bounds = vigilance.window()
        let wakeMoment = recent.last.map { $0.wokeAt } ?? habitualWake
        let anchor = now.addingTimeInterval(-awake * 3600)
        let windowStart = anchor.addingTimeInterval(bounds.start * 3600)
        _ = wakeMoment

        let shortfalls = [
            ClarityShortfall(component: .regularity, amount: regularityWeight * (100 - regularityScore)),
            ClarityShortfall(component: .duration, amount: durationWeight * (100 - duration)),
            // Le circadien ne pese plus dans une somme : ce qu'il « coute »,
            // c'est ce que l'oscillation retire au plafond a cet instant.
            ClarityShortfall(component: .circadian, amount: max(0, ceiling - value)),
        ].sorted { $0.amount > $1.amount }

        return ClarityReading(
            clarity: Clarity(value: Int(min(100, max(0, value.rounded())))),
            observedNights: recent.count,
            inferredNights: recent.count { $0.origin == .inferred },
            regularity: regularity,
            window: DateInterval(start: windowStart, duration: (bounds.end - bounds.start) * 3600),
            projectedNightPenalty: penalty,
            lastNightDuration: lastNight,
            wakeSpread: spread,
            shortfalls: shortfalls,
            ceiling: ceiling,
            hoursAwake: awake,
            wokeAt: anchor,
            curve: vigilance.curve().map {
                ClarityReading.CurvePoint(
                    at: anchor.addingTimeInterval($0.hoursAwake * 3600),
                    hoursAwake: $0.hoursAwake,
                    clarity: $0.clarity,
                    ceiling: vigilance.ceiling(hoursAwake: $0.hoursAwake)
                )
            },
            level: ClarityLevel.level(value: Int(min(100, max(0, value.rounded()))), previous: previousLevel)
        )
    }

    /// La fenetre par defaut, quand aucune mesure n'existe.
    private static func defaultWindow(habitualWake: Date, now: Date, calendar: Calendar) -> DateInterval {
        let parts = calendar.dateComponents([.hour, .minute], from: habitualWake)
        let wakeHour = Double(parts.hour ?? 7) + Double(parts.minute ?? 0) / 60
        let start = calendar.startOfDay(for: now).addingTimeInterval((wakeHour + 2) * 3600)
        return DateInterval(start: start, duration: 2.67 * 3600)
    }

    /// Amplitude des levers : l'ecart entre le plus tot et le plus tard.
    ///
    /// Un fait mesure, la ou le SRI est un score. C'est lui qu'on affiche.
    static func wakeSpread(of nights: some Collection<Night>, calendar: Calendar) -> TimeInterval? {
        guard nights.count >= 2 else { return nil }
        let minutes = nights.map { night -> Double in
            let parts = calendar.dateComponents([.hour, .minute], from: night.wokeAt)
            return Double(parts.hour ?? 0) * 60 + Double(parts.minute ?? 0)
        }
        guard let low = minutes.min(), let high = minutes.max() else { return nil }
        // Ecart circulaire : entre 23 h et 1 h il y a deux heures, pas vingt-deux.
        let direct = high - low
        return min(direct, 1440 - direct) * 60
    }

    // ── Details ──

    /// Le lever habituel, moyenne des heures de reveil reelles.
    ///
    /// Moyenne circulaire : additionner 23 h et 1 h donnerait midi.
    private static func averageWake(of nights: [Night], calendar: Calendar) -> Date? {
        guard !nights.isEmpty else { return nil }
        var x = 0.0, y = 0.0
        for night in nights {
            let parts = calendar.dateComponents([.hour, .minute], from: night.wokeAt)
            let hour = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
            let angle = hour / 24 * 2 * .pi
            x += cos(angle); y += sin(angle)
        }
        var angle = atan2(y / Double(nights.count), x / Double(nights.count))
        if angle < 0 { angle += 2 * .pi }
        let hour = angle / (2 * .pi) * 24

        let base = calendar.startOfDay(for: nights.last!.wokeAt)
        return base.addingTimeInterval(hour * 3600)
    }

    private static func defaultWake(_ now: Date, _ calendar: Calendar) -> Date {
        calendar.startOfDay(for: now).addingTimeInterval(7 * 3600)
    }

    private static func projectedBedtime(_ habitualWake: Date, _ calendar: Calendar) -> Date {
        // Huit heures avant le prochain lever.
        habitualWake.addingTimeInterval(24 * 3600 - 8 * 3600)
    }

    /// Ce que la cafeine encore active retirera a la nuit prochaine.
    ///
    /// **Le cafe est un modificateur, pas une composante.** Une prise moins de
    /// huit heures avant le coucher vise abaisse la nuit projetee — donc la
    /// clarte de *demain*. Jamais celle d'aujourd'hui : c'est la seule facon
    /// que le geste enseigne quelque chose plutot que de punir.
    ///
    /// Demi-vie de cinq heures, et **seuil de huit heures** : au-dela, ce qui
    /// reste ne perturbe pas le sommeil de facon mesurable, et le compter
    /// ferait de chaque cafe du matin une faute.
    static let caffeineHorizon: TimeInterval = 8 * 3600

    static func caffeinePenalty(coffees: [Date], bedtime: Date, now: Date) -> Double {
        let remaining = coffees.reduce(0.0) { total, taken in
            let ahead = bedtime.timeIntervalSince(taken)
            guard ahead > 0, ahead < caffeineHorizon else { return total }
            return total + pow(0.5, ahead / 3600 / 5.0)
        }
        return min(1, remaining)
    }
}
