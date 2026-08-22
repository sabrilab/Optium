import SwiftUI

/// L'etat de lecture, rendu visible.
///
/// **Une application qui lit des donnees doit se voir lire.** Sans etat de
/// chargement, une lecture instantanee et une lecture qui echoue se
/// ressemblent : dans les deux cas rien ne bouge, et l'utilisateur ne sait pas
/// si quelque chose est en cours. C'est particulierement vrai ici, ou la
/// lecture de Sante peut prendre plusieurs secondes au premier lancement.
///
/// Trois surfaces le portent : le cerveau change de regime, la ligne ci-dessous
/// annonce ce qui se passe, et un tirage vers le bas permet de le relancer.
struct ReadingBanner: View {
    let isReading: Bool
    /// Ce qui est en cours de lecture, nomme. « Chargement… » n'apprend rien.
    var what = "Lecture de tes nuits"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweeping = false

    var body: some View {
        if isReading {
            HStack(spacing: 10) {
                // Une barre qui balaie, pas un rond qui tourne : l'indicateur
                // systeme est generique, celui-ci appartient a l'application.
                GeometryReader { proxy in
                    Capsule()
                        .fill(Ink.marker.opacity(0.75))
                        .frame(width: proxy.size.width * 0.32)
                        .offset(x: sweeping ? proxy.size.width * 0.68 : 0)
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                            value: sweeping
                        )
                }
                .frame(width: 46, height: 2)
                .background(Capsule().fill(Color.white.opacity(0.12)))

                Text(what)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .frame(minHeight: 22)
            .onAppear { sweeping = true }
            .transition(.opacity)
        }
    }
}

/// Le voile d'un contenu pas encore lu.
///
/// **Une silhouette, jamais un contenu invente.** Un faux mot de clarte le
/// temps du chargement serait une valeur affichee qui n'a jamais ete mesuree —
/// exactement ce que le moteur s'interdit en rendant la clarte optionnelle.
struct SkeletonBar: View {
    var width: CGFloat = 120
    var height: CGFloat = 30

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: height / 3)
            .fill(Color.white.opacity(pulsing ? 0.14 : 0.07))
            .frame(width: width, height: height)
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}
