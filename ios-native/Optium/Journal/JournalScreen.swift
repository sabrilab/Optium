import SwiftData
import SwiftUI

/// Les fils fermes.
///
/// Le document est explicite : le journal existe mais **n'est pas une
/// destination**. Il ne pousse a rien, ne notifie rien, ne compte aucune
/// serie. Il sert a relire ce qu'on a decide, et plus tard a alimenter les
/// fourchettes d'estimation.
struct JournalScreen: View {
    @Query(
        filter: #Predicate<WorkThread> { $0.closedAt != nil },
        sort: \WorkThread.closedAt,
        order: .reverse
    )
    private var closed: [WorkThread]

    var body: some View {
        NavigationStack {
            Group {
                if closed.isEmpty {
                    ContentUnavailableView {
                        Label("Aucun fil fermé", systemImage: "text.line.first.and.arrowtriangle.forward")
                    } description: {
                        Text("Les fils que tu fermes s’inscrivent ici, avec la phrase de départ.")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(closed.enumerated()), id: \.element.id) { index, thread in
                                row(thread, hue: Ink.cardHues[index % Ink.cardHues.count])
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(InkBackground())
            .navigationTitle("Journal")
        }
    }

    private func row(_ thread: WorkThread, hue: Ink.CardHue) -> some View {
        let summary = thread.summary()
        return VStack(alignment: .leading, spacing: 12) {
            Text(thread.nature.word.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            Text(thread.phrase)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.primary)

            HStack(spacing: 18) {
                mark("\(summary.resumptionCount)", "reprises")
                mark("\(summary.inWindowCount)", "dans la fenêtre")
                if summary.nightsCrossed > 0 {
                    mark("\(summary.nightsCrossed)", summary.nightsCrossed == 1 ? "nuit" : "nuits")
                }
                if summary.holdCount > 0 {
                    mark("\(summary.holdCount)", summary.holdCount == 1 ? "retenue" : "retenues")
                }
            }
        }
        .padding(18)
        .bentoSurface(hue, corner: 28, intensity: 0.4)
    }

    private func mark(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .medium))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
