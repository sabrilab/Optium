import SwiftUI

/// Fermeture du fil.
///
/// La phrase de départ est remontrée **telle quelle**. C'est tout l'intérêt de
/// l'avoir figée à l'ouverture : on lit ce qu'on croyait faire à côté de ce
/// que ça a pris.
struct ClosedScreen: View {
    let thread: WorkThread
    let onDone: () -> Void

    private var summary: ThreadSummary { thread.summary() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("FIL FERMÉ")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 22)

                Text("Ce que ça a pris")
                    .font(.system(size: 24, weight: .light))
                    .padding(.bottom, 20)

                HStack(spacing: 12) {
                    tally("\(summary.resumptionCount)", summary.resumptionCount == 1 ? "reprise" : "reprises", Ink.indigo)
                    tally("\(summary.inWindowCount)", "dans la fenêtre", Ink.teal)
                }
                .padding(.bottom, 12)

                HStack(spacing: 12) {
                    tally("\(summary.nightsCrossed)", summary.nightsCrossed == 1 ? "nuit" : "nuits", Ink.violet)
                    tally("\(summary.holdCount)", summary.holdCount == 1 ? "retenue" : "retenues", Ink.amber)
                }
                .padding(.bottom, 26)

                VStack(alignment: .leading, spacing: 12) {
                    Text("TA PHRASE, \(openedOn)")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                    Text(thread.phrase)
                        .font(.system(size: 20, weight: .light))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .bentoSurface(Ink.rose, corner: 30, intensity: 0.45)

                if let acceptance = thread.acceptance {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CE QUE TU AS ACCEPTÉ")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.4)
                            .foregroundStyle(.secondary)
                        Text(acceptance)
                            .font(.system(size: 17, weight: .light))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .bentoSurface(Ink.coral, corner: 30, intensity: 0.4)
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onDone) {
                Text("C’est bien ça")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.glass)
            .tint(Ink.control)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    private var openedOn: String {
        thread.createdAt.formatted(.dateTime.weekday(.wide)).uppercased()
    }

    private func tally(_ value: String, _ label: String, _ hue: Ink.CardHue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 30, weight: .light))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .bentoSurface(hue, corner: 28, intensity: 0.5)
    }
}
