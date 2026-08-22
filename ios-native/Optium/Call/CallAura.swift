import SwiftUI

/// L'aura de l'appel, jusqu'aux bords de l'ecran.
///
/// **Ce n'est pas le halo de Siri, et ce n'est pas un detail.** Ni ses
/// couleurs, ni son degrade anime. Trois raisons, chacune suffisante :
/// confusion sur qui parle, Apple decourage l'imitation de ses affordances
/// systeme, et une revue App Store peut le relever.
///
/// On reprend nos propres teintes — `focusGlow` et `focusGlowFar` — et elles
/// disent quelque chose de juste : **c'est le cerveau de l'utilisateur qui
/// parle, il occupe tout l'ecran.**
///
/// Le contour epouse exactement les coins de l'appareil grace a
/// `ConcentricRectangle`, qui derive son rayon de celui de l'ecran. Un rayon
/// fixe laisse un liser incurve differemment du materiel, visible des qu'on
/// sait le chercher. Aucune API privee.
struct CallAura: View {
    /// 0…1 : le volume entendu, ou l'avancement de la parole.
    let level: Double
    /// Vrai pendant que quelqu'un parle — l'utilisateur ou le cerveau.
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    /// La respiration suit la voix, amortie.
    ///
    /// Brute, elle sauterait a chaque syllabe et donnerait un vu-metre. Le
    /// plancher a 0,35 evite que l'aura disparaisse entre deux mots.
    private var amplitude: Double {
        guard isActive else { return 0.35 }
        return 0.35 + 0.65 * min(1, max(0, level))
    }

    var body: some View {
        GeometryReader { proxy in
            ConcentricRectangle(corners: .concentric(), isUniform: true)
                .stroke(
                    LinearGradient(
                        colors: [
                            Ink.focusGlow.opacity(0.85 * amplitude),
                            Ink.focusGlowFar.opacity(0.55 * amplitude),
                            Ink.focusGlow.opacity(0.75 * amplitude),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                // Le flou fait deborder la lumiere vers l'interieur : c'est ce
                // qui la fait lire comme une aura et non comme une bordure.
                .blur(radius: 14)
                .padding(2)
                .scaleEffect(reduceMotion ? 1 : (breathing ? 1.004 : 0.997))
                .animation(
                    reduceMotion
                        ? nil
                        : Animation.easeInOut(duration: 3.4).repeatForever(autoreverses: true),
                    value: breathing
                )
                .animation(Animation.easeOut(duration: 0.18), value: amplitude)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        // **Sous mouvement reduit, l'aura reste — elle ne pulse pas.** Elle dit
        // qui parle, et cette information ne doit pas dependre du mouvement.
        .onAppear { if !reduceMotion { breathing = true } }
    }
}
