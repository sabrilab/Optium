import Foundation

/// Ce que le moteur a lu, et ce qu'il sait de sa propre fiabilite.
struct ClarityReading {
    let clarity: Clarity
    /// Faux tant que l'historique est trop court pour affirmer quoi que ce
    /// soit. L'interface doit alors le dire plutot que d'annoncer un mot :
    /// un oracle qui a toujours une reponse ment en permanence.
    let isConfident: Bool
    let regularity: Double?
    let window: DateInterval
    /// 0…1 : ce que la cafeine encore active retirera a la nuit **prochaine**.
    let projectedNightPenalty: Double
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
    static let regularityWeight = 0.45
    static let durationWeight = 0.30
    static let circadianWeight = 0.25

    /// En deca, l'historique ne permet pas d'affirmer.
    static let confidenceThreshold = 14

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

    static func reading(
        nights: [Night],
        now: Date,
        coffees: [Date] = [],
        calendar: Calendar = .current
    ) -> ClarityReading {
        let recent = nights.sorted { $0.asleepAt < $1.asleepAt }
        let habitualWake = averageWake(of: recent, calendar: calendar) ?? defaultWake(now, calendar)
        let circadian = CircadianModel(habitualWake: habitualWake, calendar: calendar)
        let window = circadian.window(on: now)
        let penalty = caffeinePenalty(coffees: coffees, bedtime: projectedBedtime(habitualWake, calendar), now: now)

        guard let last = recent.last, recent.count >= 2 else {
            // Sans historique, on n'invente pas : on annonce la valeur mediane
            // et on dit qu'on ne sait pas.
            return ClarityReading(
                clarity: Clarity(value: 55),
                isConfident: false,
                regularity: nil,
                window: window,
                projectedNightPenalty: penalty
            )
        }

        let regularity = SleepRegularity.index(nights: recent, calendar: calendar) ?? 50
        let durations = recent.map(\.duration).sorted()
        let median = durations[durations.count / 2]
        let duration = durationScore(lastNight: last.duration, median: median)
        let phase = circadian.score(at: now)

        let value = regularityWeight * regularity
                  + durationWeight * duration
                  + circadianWeight * phase

        return ClarityReading(
            clarity: Clarity(value: Int(min(100, max(0, value.rounded())))),
            isConfident: recent.count >= confidenceThreshold,
            regularity: regularity,
            window: window,
            projectedNightPenalty: penalty
        )
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
