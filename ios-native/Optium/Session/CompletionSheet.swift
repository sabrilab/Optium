import SwiftUI

struct CompletionSheet: View {
    let mode: TimerMode
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text(mode == .focus ? "SESSION TERMINÉE" : "PAUSE TERMINÉE")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)
                .padding(.bottom, 26)

            // L'afficheur reprend celui du minuteur : c'est le meme objet, a
            // son terme.
            DotMatrixText(
                text: "00:00",
                dot: 6,
                gap: 3.5,
                glow: Ink.glow(isFocus: mode == .focus)
            )
            .padding(.bottom, 22)

            Text(mode == .focus
                 ? "Prenez une pause, vous l’avez méritée."
                 : "Prêt à replonger ?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 30)

            Button {
                onContinue()
                dismiss()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: mode == .focus ? "cup.and.saucer.fill" : "play.fill")
                        .font(.system(size: 14))
                    Text(mode == .focus ? "Commencer la pause" : "Reprendre")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.glass)
            .tint(Ink.control)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                InkBackground()
                Aura(isFocus: mode == .focus, intensity: 0.9)
                    .frame(height: 420)
                    .offset(y: -40)
            }
            .ignoresSafeArea()
        }
        .presentationDetents([.medium])
        .presentationBackground(.clear)
    }
}
