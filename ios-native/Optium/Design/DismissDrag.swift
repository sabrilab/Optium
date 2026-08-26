import SwiftUI

/// La zone par laquelle on baisse un ecran plein.
///
/// **Un plein ecran n'a pas de geste de retrait**, et une feuille qui en a un
/// ne monte pas jusqu'en haut. Poser le geste soi-meme donne les deux.
///
/// Il vit sur une **zone dediee**, pas sur tout l'ecran : la scene 3D dessous
/// tourne au glissement, et deux gestes qui se recouvrent laissent l'un des
/// deux gagner au hasard. La barre du haut est l'endroit ou personne ne
/// s'attend a faire tourner un cerveau.
///
/// **Aucune barre grise n'est dessinee.** L'indicateur de glissement des
/// feuilles annoncerait le geste, et l'application ne commente pas ses propres
/// gestes — celui-ci se trouve par habitude, comme dans un lecteur de musique.
struct DismissDrag: ViewModifier {
    let onDismiss: () -> Void

    @State private var offset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Au-dela, on lache. Cent points : assez pour qu'un glissement accidentel
    /// ne ferme rien, assez peu pour que le geste reste leger.
    private static let threshold: CGFloat = 100

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        // Vers le bas seulement, et amorti : l'ecran suit le
                        // doigt sans le devancer.
                        offset = max(0, value.translation.height * 0.7)
                    }
                    .onEnded { value in
                        if value.translation.height > Self.threshold {
                            Feedback.play(.held)
                            onDismiss()
                        }
                        withAnimation(reduceMotion ? nil : Motion.state) { offset = 0 }
                    }
            )
    }
}

extension View {
    /// Rend un ecran plein retirable par glissement vers le bas.
    ///
    /// - Parameter grabbing: la vue qui capte le geste. Le reste de l'ecran
    ///   garde les siens.
    func dismissDrag(_ onDismiss: @escaping () -> Void) -> some View {
        modifier(DismissDrag(onDismiss: onDismiss))
    }
}
