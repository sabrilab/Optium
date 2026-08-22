import Foundation

/// Deduire les nuits d'une suite de periodes d'immobilite.
///
/// Isole des frameworks a dessein : c'est la seule partie de la lecture du
/// sommeil qui contienne du jugement, donc la seule qui merite d'etre testee.
/// Le reste n'est qu'une interrogation d'API.
enum SleepInference {
    /// En deca, ce n'est pas une nuit — une sieste devant la television, un
    /// telephone pose une heure.
    static let minimumDuration: TimeInterval = 3 * 3600

    /// Au-dela, ce n'est plus quelqu'un qui dort : c'est un telephone oublie
    /// sur un meuble. Le compter comme une nuit parfaite serait le pire des
    /// cas — il recompenserait l'absence de donnees.
    static let maximumDuration: TimeInterval = 14 * 3600

    /// Plage d'**endormissement** — pas de la nuit entiere. De 18 h a 6 h,
    /// comptee depuis minuit du jour ou la nuit commence.
    ///
    /// La distinction compte : borner la nuit entiere laisserait passer une
    /// immobilite de trois heures commencee a 14 h, ce qui n'est pas un
    /// sommeil mais un apres-midi assis.
    static let onsetWindow: ClosedRange<Double> = 18...30

    static func nights(fromStillPeriods periods: [DateInterval], calendar: Calendar) -> [Night] {
        guard !periods.isEmpty else { return [] }

        // On regroupe par nuit : chaque periode appartient a la nuit du jour
        // ou elle a commence, ou a celle de la veille si elle commence apres
        // minuit.
        var byNight: [Date: [DateInterval]] = [:]
        for period in periods {
            guard let anchor = nightAnchor(of: period, calendar: calendar) else { continue }
            byNight[anchor, default: []].append(period)
        }

        return byNight.keys.sorted().compactMap { anchor in
            // Le plus long segment, et non la somme : un reveil au milieu peut
            // etre du sommeil comme une insomnie debout, et rien ne permet de
            // trancher. Additionner surestimerait systematiquement.
            guard let longest = byNight[anchor]?.max(by: { $0.duration < $1.duration }),
                  longest.duration >= minimumDuration,
                  longest.duration <= maximumDuration else { return nil }
            return Night(asleepAt: longest.start, wokeAt: longest.end)
        }
    }

    /// Le minuit qui precede la nuit a laquelle cette periode appartient.
    private static func nightAnchor(of period: DateInterval, calendar: Calendar) -> Date? {
        let midnight = calendar.startOfDay(for: period.start)
        let hour = period.start.timeIntervalSince(midnight) / 3600

        if hour >= onsetWindow.lowerBound {
            return midnight
        }
        if hour + 24 <= onsetWindow.upperBound {
            // Endormissement passe minuit : la nuit est celle de la veille.
            return calendar.date(byAdding: .day, value: -1, to: midnight)
        }
        return nil
    }
}
