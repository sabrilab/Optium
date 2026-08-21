import Charts
import SwiftData
import SwiftUI

struct StatsScreen: View {
    @Query private var sessions: [FocusSession]

    private var stats: Stats {
        StatsBuilder.build(sessions: sessions, today: Date())
    }

    var body: some View {
        NavigationStack {
            List {
                let stats = stats

                Section("Aujourd’hui") {
                    row("Sessions terminées", "\(stats.todayCount)")
                    row("Temps de concentration", duration(stats.todaySeconds))
                    row("Série en cours", stats.streak <= 1 ? "\(stats.streak) jour" : "\(stats.streak) jours")
                }

                Section {
                    chart(stats.days)
                        .frame(height: 180)
                        .padding(.vertical, 8)
                } header: {
                    Text("14 derniers jours")
                } footer: {
                    Text("Minutes de concentration par jour.")
                }

                Section {
                    row("Concentration par jour", duration(stats.averageSeconds))
                    row("Sessions par jour", String(format: "%.1f", stats.averageCount))
                    row("Meilleur jour", stats.best.map { "\(duration($0.seconds)) · \(dayLabel($0.date))" } ?? "—")
                } header: {
                    Text("Moyennes")
                } footer: {
                    Text("Calculées sur les jours où au moins une session a été menée.")
                }
            }
            .navigationTitle("Statistiques")
        }
    }

    private func chart(_ days: [DayStat]) -> some View {
        Chart(days) { day in
            BarMark(
                x: .value("Jour", day.date, unit: .day),
                y: .value("Minutes", day.seconds / 60)
            )
            // Le jour courant se distingue des autres.
            .foregroundStyle(
                Calendar.current.isDateInToday(day.date) ? Color.accentColor : Color(.tertiaryLabel)
            )
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.day())
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
    }

    private func duration(_ seconds: Int) -> String {
        let minutes = Int((Double(seconds) / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest)"
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day())
    }
}
