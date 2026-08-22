import SwiftUI

/// **La porte. Le seul refus de l'application.**
///
/// Plein cadre, aucune carte. C'est le seul écran qui n'est pas une surface de
/// verre posée sur le noir, et cette rupture *est* le message : tout le reste
/// de l'application renseigne, celui-ci arrête.
///
/// Deux issues, et aucune n'est un abandon : fermer en écrivant ce qu'on
/// accepte, ou retenir jusqu'à la prochaine fenêtre.
struct GateScreen: View {
    let thread: WorkThread
    let onClosed: () -> Void
    let onHeld: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    @State private var acceptance = ""
    @FocusState private var writing: Bool

    private var trimmed: String { acceptance.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var nextWindow: Date {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return settings.claritySource.window(on: tomorrow).start
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("TU FERMES UNE DÉCISION")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)

                if settings.brainEnabled {
                    BrainView(
                        fill: Double(settings.claritySource.current().value) / 100,
                        base: min(1, Double(settings.claritySource.current().value) / 100 + 0.12),
                        agitation: 0.75,
                        isDay: true,
                        isVisible: scenePhase == .active
                    )
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
                }

                Text(thread.phrase)
                    .font(.system(size: 21, weight: .light))
                    .padding(.bottom, 26)

                Text("Écris ce que tu acceptes, et pourquoi.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)

                TextField("", text: $acceptance, axis: .vertical)
                    .font(.system(size: 17, weight: .light))
                    .lineLimit(3...7)
                    .focused($writing)
                    .padding(.vertical, 14)
                    .overlay(alignment: .topLeading) {
                        if acceptance.isEmpty {
                            Text("J’accepte la version courte parce que…")
                                .font(.system(size: 17, weight: .light))
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(trimmed.isEmpty ? Color.white.opacity(0.16) : Ink.marker)
                            .frame(height: 1)
                    }
                    .padding(.bottom, 26)

                Text("Ta clarté est \(settings.claritySource.current().level.word). C’est le seul moment où Optium t’arrête.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 140)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    // Sans la ligne écrite, la porte ne s'ouvre pas. C'est tout
                    // son objet : on ne franchit pas en tapant, on franchit en
                    // disant ce qu'on accepte.
                    if thread.closeThroughGate(acceptance: acceptance, at: Date()) {
                        onClosed()
                    }
                } label: {
                    Text("Fermer")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.glass)
                .tint(Ink.control)
                .disabled(trimmed.isEmpty)

                Button {
                    thread.hold(until: nextWindow, at: Date())
                    onHeld()
                } label: {
                    Text("Retenir jusqu’à \(nextWindow.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Ink.marker)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .background(.clear)
        }
    }
}
