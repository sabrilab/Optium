import SwiftUI

struct CompletionSheet: View {
    let mode: TimerMode
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: mode == .focus ? "checkmark.circle.fill" : "cup.and.saucer.fill")
                .font(.system(size: 56))
                .foregroundStyle(Ink.glow(isFocus: mode == .focus))

            Text(mode == .focus ? "Session terminée" : "Pause terminée")
                .font(.title2.weight(.semibold))

            Text(mode == .focus
                 ? "Prenez une pause, vous l’avez méritée."
                 : "Prêt à replonger ?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(mode == .focus ? "Commencer la pause" : "Reprendre") {
                onContinue()
                dismiss()
            }
            .buttonStyle(.glassProminent)
            .tint(Ink.glow(isFocus: mode == .focus))
            .controlSize(.large)
            .frame(minHeight: 44)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Ink.canvas
                Aura(isFocus: mode == .focus, intensity: 0.8)
                    .frame(height: 380)
            }
            .ignoresSafeArea()
        }
        .presentationDetents([.medium])
    }
}
