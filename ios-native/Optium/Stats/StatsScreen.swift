import Charts
import SwiftData
import SwiftUI

struct StatsScreen: View {
    @Query private var sessions: [FocusSession]

    private var stats: Stats {
        StatsBuilder.build(sessions: sessions, today: Date())
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                let stats = stats

                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        hero(stats)

                        LazyVGrid(columns: columns, spacing: 12) {
                            BentoCard(tint: Ink.focusGlowFar, accent: Ink.focusGlow, intensity: 0.62) {
                                BentoStat(label: "Série en cours",
                                          value: "\(stats.streak)",
                                          unit: stats.streak <= 1 ? "jour" : "jours")
                            }
                            BentoCard(tint: Ink.focusGlow, accent: Ink.focusGlowFar, intensity: 0.62) {
                                BentoStat(label: "Sessions aujourd’hui",
                                          value: "\(stats.todayCount)")
                            }
                            BentoCard(tint: Ink.focusGlowFar, accent: Ink.focusGlow, intensity: 0.42) {
                                BentoStat(label: "Moyenne / jour",
                                          value: minutes(stats.averageSeconds),
                                          unit: "min")
                            }
                            BentoCard(tint: Ink.focusGlow, accent: Ink.focusGlowFar, intensity: 0.42) {
                                BentoStat(label: "Sessions / jour",
                                          value: String(format: "%.1f", stats.averageCount))
                            }
                        }

                        bestCard(stats)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            .background(background)
            .navigationTitle("Statistiques")
        }
    }

    private var background: some View {
        InkBackground()
    }

    /// La carte principale porte le chiffre du jour en matrice de points et
    /// l'histogramme des quatorze derniers jours.
    private func hero(_ stats: Stats) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("CONCENTRATION AUJOURD’HUI")
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 10) {
                DotMatrixText(
                    text: minutes(stats.todaySeconds),
                    dot: 7, gap: 4,
                    glow: Ink.focusGlow
                )
                Text("min")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }

            chart(stats.days)
                .frame(height: 140)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .bentoSurface(tint: Ink.focusGlow, accent: Ink.focusGlowFar, corner: 34)
    }

    private func bestCard(_ stats: Stats) -> some View {
        BentoCard(tint: Ink.focusGlowFar, accent: Ink.focusGlow, intensity: 0.52) {
            HStack {
                BentoStat(
                    label: "Meilleur jour",
                    value: stats.best.map { minutes($0.seconds) } ?? "—",
                    unit: stats.best == nil ? nil : "min"
                )
                Spacer()
                if let best = stats.best {
                    Text(best.date.formatted(.dateTime.weekday(.abbreviated).day()))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func chart(_ days: [DayStat]) -> some View {
        Chart(days) { day in
            BarMark(
                x: .value("Jour", day.date, unit: .day),
                y: .value("Minutes", day.seconds / 60),
                width: .fixed(2)
            )
            .foregroundStyle(
                Calendar.current.isDateInToday(day.date)
                ? Ink.marker
                : Color.white.opacity(0.30)
            )
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.background(.clear) }
    }

    private func minutes(_ seconds: Int) -> String {
        "\(Int((Double(seconds) / 60).rounded()))"
    }
}
