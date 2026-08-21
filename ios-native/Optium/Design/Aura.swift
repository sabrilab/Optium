import SwiftUI

/// Grande aura radiale floue, element d'ambiance principal.
///
/// Elle respire lentement — dix secondes par cycle — pour que l'ecran ne soit
/// jamais tout a fait immobile pendant les vingt-cinq minutes qu'on passe
/// dessus, sans jamais attirer l'oeil au point de distraire.
struct Aura: View {
    let isFocus: Bool
    /// 0…1 : l'aura s'intensifie avec l'avancement de la session.
    var intensity: Double = 1

    @State private var breathing = false

    var body: some View {
        RadialGradient(
            stops: [
                .init(color: Ink.glow(isFocus: isFocus).opacity(0.55 * intensity), location: 0),
                .init(color: Ink.glowFar(isFocus: isFocus).opacity(0.28 * intensity), location: 0.45),
                .init(color: .clear, location: 1),
            ],
            center: .center,
            startRadius: 0,
            endRadius: 320
        )
        .blur(radius: 60)
        .scaleEffect(breathing ? 1.08 : 0.94)
        .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: breathing)
        .animation(.easeInOut(duration: 1.5), value: isFocus)
        .onAppear { breathing = true }
        .allowsHitTesting(false)
    }
}
