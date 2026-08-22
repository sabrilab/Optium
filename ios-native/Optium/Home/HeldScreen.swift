import SwiftUI

/// Retenu.
///
/// « Le plus silencieux. Aucune culpabilisation. » L'écran énonce ce qui a été
/// observé, puis désamorce : rien d'autre n'est bloqué, seule la validation
/// attend. Sans cette dernière phrase, la retenue se lit comme une punition.
struct HeldScreen: View {
    let thread: WorkThread
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("RETENU JUSQU’À \(heldUntilText)")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(Ink.marker)
                .padding(.bottom, 18)

            Text(thread.phrase)
                .font(.system(size: 24, weight: .light))
                .padding(.bottom, 30)

            Text("Tu aurais validé sans relire.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            Text("Rien d’autre n’est bloqué. Tu peux continuer à produire — c’est seulement la validation qui attend.")
                .font(.footnote)
                .foregroundStyle(.tertiary)

            Spacer()

            Button(action: onDone) {
                Text("Compris")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.glass)
            .tint(Ink.control)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
    }

    private var heldUntilText: String {
        guard let until = thread.heldUntil else { return "DEMAIN" }
        return Clock.hhmm(until)
    }
}
