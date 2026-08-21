import Foundation

struct DayStat: Identifiable, Equatable {
    let date: Date
    let seconds: Int
    let count: Int

    var id: Date { date }
}

struct Stats {
    let days: [DayStat]
    let todaySeconds: Int
    let todayCount: Int
    let streak: Int
    let averageSeconds: Int
    let averageCount: Double
    let best: DayStat?
}

/// Calculs statistiques, sans dependance a SwiftUI ni a SwiftData : c'est ce
/// qui les rend testables sans lancer d'interface.
enum StatsBuilder {
    static let windowDays = 14

    static func build(
        sessions: [FocusSession],
        today: Date,
        calendar: Calendar = .current
    ) -> Stats {
        let focus = sessions.filter(\.isFocus)
        let startOfToday = calendar.startOfDay(for: today)

        let days: [DayStat] = (0..<windowDays).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - (windowDays - 1), to: startOfToday)!
            let sameDay = focus.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            return DayStat(
                date: date,
                seconds: sameDay.reduce(0) { $0 + $1.durationSeconds },
                count: sameDay.count
            )
        }

        // Serie en cours : on remonte jour par jour tant qu'une session existe.
        // Le jour courant ne casse pas la serie s'il est encore vide — sinon
        // la serie de chacun tomberait a zero chaque matin.
        var streak = 0
        for index in stride(from: days.count - 1, through: 0, by: -1) {
            if days[index].count > 0 {
                streak += 1
            } else if index != days.count - 1 {
                break
            }
        }

        let activeDays = days.filter { $0.count > 0 }
        let totalSeconds = days.reduce(0) { $0 + $1.seconds }
        let totalCount = days.reduce(0) { $0 + $1.count }
        let best = days.max { $0.seconds < $1.seconds }

        return Stats(
            days: days,
            todaySeconds: days.last?.seconds ?? 0,
            todayCount: days.last?.count ?? 0,
            streak: streak,
            // Moyennes sur les seuls jours actifs : inclure les jours vides
            // ferait mentir le chiffre.
            averageSeconds: activeDays.isEmpty ? 0 : totalSeconds / activeDays.count,
            averageCount: activeDays.isEmpty ? 0 : Double(totalCount) / Double(activeDays.count),
            best: (best?.seconds ?? 0) > 0 ? best : nil
        )
    }
}
