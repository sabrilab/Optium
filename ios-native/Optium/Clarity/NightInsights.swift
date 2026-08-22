import Foundation

/// Ce qu'on peut honnetement tirer de `asleepAt` et `wokeAt`, et rien d'autre.
///
/// **Le calcul vit ici, separe des vues.** Chaque module d'analyse est une
/// fonction pure sur des nuits : il se teste sans interface, et une erreur de
/// modele ne se cache pas derriere un joli graphique.
///
/// **Trois interdits, herites des garde-fous du projet.**
///
/// 1. Rien de predictif. « Tu dormiras mal demain » serait une prophetie ; on
///    ne montre que ce qui a eu lieu.
/// 2. Aucune note, aucun score global, aucune serie a ne pas briser. Le risque
///    d'orthosomnie est reel : transformer le sommeil en performance a
///    optimiser degrade le sommeil.
/// 3. Aucun conseil. Les modules posent un fait ; ce qu'on en fait n'appartient
///    pas a l'application.
enum NightInsights {

    // ── 1. L'empreinte : ou tombent les nuits dans la journee ──

    /// Une ligne de l'empreinte : un jour, et les tranches ou l'on dormait.
    ///
    /// Les bornes sont en **fraction d'un axe de vingt-quatre heures qui
    /// commence a 18 h**, et non a minuit. Sur un axe partant de minuit, une
    /// nuit ordinaire — coucher 23 h, lever 7 h — se coupe en deux morceaux
    /// aux extremites du graphique, et l'oeil ne voit plus une nuit mais deux
    /// fragments. Decalee de six heures, elle tient d'un seul tenant au
    /// milieu, et c'est la derive du bloc qu'on lit.
    struct RasterRow: Equatable, Identifiable {
        let day: Date
        /// 0…1 sur l'axe 18 h → 18 h. Une seule tranche dans le cas ordinaire.
        let spans: [ClosedRange<Double>]
        let inferred: Bool

        var id: Date { day }
    }

    static let axisStartHour = 18.0

    static func raster(
        nights: [Night],
        days: Int = 28,
        calendar: Calendar = .current
    ) -> [RasterRow] {
        let recent = nights.sorted { $0.wokeAt < $1.wokeAt }.suffix(days)

        return recent.map { night in
            let day = calendar.startOfDay(for: night.wokeAt)
            // L'axe d'une ligne commence a 18 h la veille du lever.
            let origin = day.addingTimeInterval((axisStartHour - 24) * 3600)
            let start = night.asleepAt.timeIntervalSince(origin) / 86_400
            let end = night.wokeAt.timeIntervalSince(origin) / 86_400

            return RasterRow(
                day: day,
                spans: clip(from: start, to: end),
                inferred: night.origin == .inferred
            )
        }
    }

    /// Ramene une tranche dans 0…1, en la coupant si elle deborde.
    private static func clip(from start: Double, to end: Double) -> [ClosedRange<Double>] {
        let low = max(0, min(1, start))
        let high = max(0, min(1, end))
        guard high > low else { return [] }
        return [low...high]
    }

    // ── 2. Le milieu de nuit, et le decalage social ──

    /// Le milieu de la nuit, en heures depuis minuit.
    ///
    /// C'est la grandeur de reference en chronobiologie : plus stable que
    /// l'heure du coucher, qui depend de ce qu'on faisait avant, et que
    /// l'heure du lever, qui depend souvent d'un reveil.
    static func midSleepHour(_ night: Night, calendar: Calendar = .current) -> Double {
        let middle = night.asleepAt.addingTimeInterval(night.duration / 2)
        let parts = calendar.dateComponents([.hour, .minute], from: middle)
        return Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
    }

    /// Le decalage social : l'ecart de milieu de nuit entre jours libres et
    /// jours travailles.
    ///
    /// Mesure etablie (Wittmann et Roenneberg) : vivre en semaine a une heure
    /// et le week-end a une autre revient a changer de fuseau horaire chaque
    /// vendredi.
    ///
    /// **L'approximation est a dire, pas a cacher** : l'application ne sait pas
    /// quels jours sont travailles. Elle prend samedi et dimanche pour les
    /// jours libres, ce qui est faux pour qui travaille le week-end.
    ///
    /// - Returns: `nil` s'il manque des nuits de l'un ou l'autre groupe.
    static func socialJetLag(nights: [Night], calendar: Calendar = .current) -> TimeInterval? {
        var free = [Double](), work = [Double]()
        for night in nights {
            let weekday = calendar.component(.weekday, from: night.wokeAt)
            // 1 = dimanche, 7 = samedi dans le calendrier gregorien.
            if weekday == 1 || weekday == 7 {
                free.append(midSleepHour(night, calendar: calendar))
            } else {
                work.append(midSleepHour(night, calendar: calendar))
            }
        }
        guard free.count >= 2, work.count >= 3 else { return nil }
        return abs(circularMean(free) - circularMean(work)) * 3600
    }

    /// Moyenne circulaire sur vingt-quatre heures.
    ///
    /// Additionner 23 h et 1 h donnerait midi ; ces heures-la sont exactement
    /// celles qui nous interessent.
    static func circularMean(_ hours: [Double]) -> Double {
        guard !hours.isEmpty else { return 0 }
        var x = 0.0, y = 0.0
        for hour in hours {
            let angle = hour / 24 * 2 * .pi
            x += cos(angle); y += sin(angle)
        }
        var angle = atan2(y / Double(hours.count), x / Double(hours.count))
        if angle < 0 { angle += 2 * .pi }
        return angle / (2 * .pi) * 24
    }

    // ── 3. Les levers, un par jour ──

    struct WakePoint: Equatable, Identifiable {
        let day: Date
        /// Heure de lever, en heures depuis minuit.
        let hour: Double
        let inferred: Bool

        var id: Date { day }
    }

    static func wakePoints(
        nights: [Night],
        days: Int = 28,
        calendar: Calendar = .current
    ) -> [WakePoint] {
        nights.sorted { $0.wokeAt < $1.wokeAt }.suffix(days).map { night in
            let parts = calendar.dateComponents([.hour, .minute], from: night.wokeAt)
            return WakePoint(
                day: calendar.startOfDay(for: night.wokeAt),
                hour: Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60,
                inferred: night.origin == .inferred
            )
        }
    }

    // ── 4. Les durees ──

    struct DurationSummary: Equatable {
        let median: TimeInterval
        let shortest: TimeInterval
        let longest: TimeInterval
        /// Part des nuits dans la cible 7–9 h.
        let inTargetShare: Double
        let count: Int
    }

    static func durations(nights: [Night]) -> DurationSummary? {
        guard !nights.isEmpty else { return nil }
        let sorted = nights.map(\.duration).sorted()
        let inTarget = sorted.count { ClarityEngine.targetRange.contains($0) }
        return DurationSummary(
            median: sorted[sorted.count / 2],
            shortest: sorted.first!,
            longest: sorted.last!,
            inTargetShare: Double(inTarget) / Double(sorted.count),
            count: sorted.count
        )
    }

    // ── 5. Le cafe et la nuit qui suit ──

    /// Compare les nuits qui suivent un cafe tardif aux autres.
    ///
    /// **C'est le seul module qui relie deux choses**, et il ne conclut rien :
    /// il pose deux medianes cote a cote. Une difference n'est pas une cause —
    /// les jours a cafe tardif sont souvent les jours charges, et c'est
    /// peut-etre la charge qui raccourcit la nuit. La vue doit le dire.
    struct CoffeeComparison: Equatable {
        /// Mediane des nuits suivant un cafe pris dans les huit heures avant
        /// le coucher.
        let afterLateCoffee: TimeInterval
        let afterNone: TimeInterval
        let lateNights: Int
        let otherNights: Int

        var gap: TimeInterval { afterNone - afterLateCoffee }
    }

    static func coffeeEffect(
        nights: [Night],
        coffees: [Date],
        calendar: Calendar = .current
    ) -> CoffeeComparison? {
        var late = [TimeInterval](), none = [TimeInterval]()

        for night in nights {
            let horizon = night.asleepAt.addingTimeInterval(-ClarityEngine.caffeineHorizon)
            let hadLate = coffees.contains { $0 > horizon && $0 < night.asleepAt }
            if hadLate { late.append(night.duration) } else { none.append(night.duration) }
        }

        // Trois nuits de chaque cote au minimum : en dessous, une mediane n'est
        // qu'une valeur isolee deguisee.
        guard late.count >= 3, none.count >= 3 else { return nil }
        return CoffeeComparison(
            afterLateCoffee: late.sorted()[late.count / 2],
            afterNone: none.sorted()[none.count / 2],
            lateNights: late.count,
            otherNights: none.count
        )
    }
}
