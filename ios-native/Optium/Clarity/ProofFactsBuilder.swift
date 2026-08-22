import Foundation

/// Assemble les faits dont les preuves ont besoin.
///
/// Separe de `Proof` a dessein : les regles de deblocage ne doivent connaitre
/// ni SwiftData ni le calendrier, sans quoi elles deviendraient intestables.
enum ProofFactsBuilder {
    /// La plus longue serie de nuits consecutives dont les levers tiennent
    /// dans une fourchette de vingt minutes.
    static func regularNightStreak(_ nights: [Night], calendar: Calendar) -> Int {
        let sorted = nights.sorted { $0.wokeAt < $1.wokeAt }
        guard !sorted.isEmpty else { return 0 }

        func minutes(_ date: Date) -> Double {
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return Double(parts.hour ?? 0) * 60 + Double(parts.minute ?? 0)
        }

        var best = 1
        var current = 1
        for (previous, night) in zip(sorted, sorted.dropFirst()) {
            let consecutive = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: previous.wokeAt),
                to: calendar.startOfDay(for: night.wokeAt)
            ).day == 1
            let close = abs(minutes(night.wokeAt) - minutes(previous.wokeAt)) <= 20

            current = consecutive && close ? current + 1 : 1
            best = max(best, current)
        }
        return best
    }

    /// Nombre de jours, parmi les `days` derniers, sans aucune prise apres
    /// quatorze heures.
    static func soberDays(_ coffees: [Date], through end: Date, days: Int, calendar: Calendar) -> Int {
        var count = 0
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { continue }
            let start = calendar.startOfDay(for: day)
            let cutoff = start.addingTimeInterval(14 * 3600)
            let next = start.addingTimeInterval(86_400)
            let late = coffees.contains { $0 >= cutoff && $0 < next }
            if !late { count += 1 }
        }
        return count
    }

    /// Reprises entamees avant dix heures.
    static func earlyResumptions(_ resumptions: [Resumption], calendar: Calendar) -> Int {
        resumptions.filter { calendar.component(.hour, from: $0.startedAt) < 10 }.count
    }

    static func facts(
        closed: [WorkThread],
        nights: [Night],
        coffees: [Date],
        resumptions: [Resumption],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ProofFacts {
        let ordered = closed
            .filter { $0.closedAt != nil }
            .sorted { ($0.closedAt ?? .distantPast) < ($1.closedAt ?? .distantPast) }
            .map { thread -> ProofFacts.ClosedThread in
                let summary = thread.summary(calendar: calendar)
                return ProofFacts.ClosedThread(
                    nature: thread.nature,
                    holdCount: summary.holdCount,
                    inWindowCount: summary.inWindowCount,
                    resumptionCount: summary.resumptionCount,
                    nightsCrossed: summary.nightsCrossed
                )
            }

        return ProofFacts(
            threads: ordered,
            regularNights: regularNightStreak(nights, calendar: calendar),
            soberDays: soberDays(coffees, through: now, days: 10, calendar: calendar),
            earlyResumptions: earlyResumptions(resumptions, calendar: calendar)
        )
    }
}
