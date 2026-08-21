import SwiftUI

/// Fond de la zone de scene.
///
/// Le verre et le fluide sont tous deux translucides et clairs : sans matiere
/// sombre derriere eux, ils n'ont rien sur quoi se detacher. Ce degrade
/// appartient a la scene, pas au chrome — les panneaux de verre, la barre
/// d'onglets et les autres ecrans restent sur le fond systeme.
///
/// Les couleurs sont litterales pour la meme raison que les huit couleurs de
/// projet : c'est du contenu, pas du style. Elles ne doivent surtout pas
/// s'inverser en mode clair, un fond qui blanchirait effacerait la scene.
struct SceneBackdrop: View {
    let isFocus: Bool

    private var top: Color {
        isFocus ? Color(red: 0.043, green: 0.055, blue: 0.125)
                : Color(red: 0.027, green: 0.086, blue: 0.075)
    }

    private var bottom: Color {
        isFocus ? Color(red: 0.082, green: 0.098, blue: 0.196)
                : Color(red: 0.047, green: 0.129, blue: 0.114)
    }

    var body: some View {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
            // Le degrade s'efface vers le bas pour rejoindre le fond systeme
            // sans arete visible sous la carte du minuteur.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.72),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // La teinte suit le mode, au meme rythme lent que le fluide.
            .animation(.easeInOut(duration: 1.5), value: isFocus)
    }
}
