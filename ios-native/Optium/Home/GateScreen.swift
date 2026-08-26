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
    @Environment(ActionLog.self) private var actions
    @Environment(ClarityStore.self) private var clarityStore
    @Environment(\.scenePhase) private var scenePhase

    /// La lecture mesurée, sauf si le forçage de développement l'écrase.
    private var reading: ClarityReading {
        if let forced = settings.clarityOverride {
            return .forced(forced, window: clarityStore.reading.window)
        }
        return clarityStore.reading
    }

    @State private var acceptance = ""
    @FocusState private var writing: Bool

    private var trimmed: String { acceptance.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// La prochaine fenetre, pas celle d'aujourd'hui.
    ///
    /// Retenir une decision, c'est la reporter au prochain creneau ou elle
    /// tiendra. Pointer la fenetre du jour — deja passee au moment ou la porte
    /// s'ouvre — la libererait immediatement, ce qui viderait la retenue de
    /// tout sens.
    private var nextWindow: Date {
        let today = reading.window.start
        guard today <= Date() else { return today }
        return Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Ce que la porte defend, et le recit courant qu'elle
                // contredit.
                HStack {
                    Spacer(minLength: 0)
                    EvidenceButton(evidence: EvidenceLibrary.errorDetection)
                }

                Text("TU FERMES UNE DÉCISION")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)

                if settings.brainEnabled {
                    BrainView(
                        fill: reading.brainFill,
                        base: reading.brainBase,
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

                // Le fait mesuré qui pèse le plus. Sans lui, le refus est une
                // affirmation sans preuve.
                if let justification = GateJustification.sentence(for: reading, now: Date()) {
                    Text(justification)
                        .font(.system(size: 17, weight: .light))
                        .padding(.bottom, 10)
                }

                Text("C’est le seul moment où Optium t’arrête.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 140)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    // Sans la ligne écrite, la porte ne s'ouvre pas. C'est tout
                    // son objet : on ne franchit pas en tapant, on franchit en
                    // disant ce qu'on accepte.
                    if thread.closeThroughGate(acceptance: acceptance, at: Date()) {
                        // Plus appuye qu'une fermeture directe : il a fallu
                        // passer par quelque part, et la main doit le savoir.
                        actions.record("Fil fermé")
                        Feedback.play(.threadClosedThroughGate)
                        Chime.play(.closed)
                        Task { await LiveActivityController.end() }
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
                    actions.record("Fil retenu")
                    Feedback.play(.held)
                    Task { await LiveActivityController.end() }
                    onHeld()
                } label: {
                    Text("Retenir jusqu’à \(Clock.hhmm(nextWindow))")
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
