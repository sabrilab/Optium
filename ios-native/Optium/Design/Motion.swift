import SwiftUI

/// Le vocabulaire du mouvement.
///
/// **Trois courbes, et pas une de plus.** Chaque `withAnimation(.spring())`
/// pose au hasard dans une vue fabrique une application ou rien ne bouge tout
/// a fait pareil — le defaut se sent sans se nommer. Les trois ci-dessous
/// couvrent tout ce que fait Optium.
///
/// **Le mouvement est une decoration, jamais une information.** Tout ce qui
/// est ici doit pouvoir etre coupe sans qu'une seule chose devienne
/// incomprehensible : c'est ce qui rend `accessibilityReduceMotion` tenable
/// plutot qu'un mode degrade.
enum Motion {
    /// L'apparition d'une carte, d'une ligne, d'un ecran. Souple, sans rebond
    /// visible : l'application renseigne, elle ne saute pas.
    static let entrance = Animation.spring(response: 0.52, dampingFraction: 0.86)

    /// Un changement d'etat dans une carte deja posee.
    static let state = Animation.spring(response: 0.34, dampingFraction: 0.82)

    /// La porte. **Plus lente que tout le reste**, et c'est deliberé : elle
    /// interrompt, et une interruption qui arrive vite se lit comme un refus
    /// sec. Celle-la se pose.
    static let gate = Animation.spring(response: 0.75, dampingFraction: 0.92)
}

/// L'entree d'un element de liste.
///
/// Le decalage par rang donne a la liste un sens de lecture — de haut en bas,
/// comme on la lit. Il est plafonne : au-dela de six elements, tout arrive
/// ensemble, sinon le dernier d'une longue liste attendrait une seconde.
struct CardEntrance: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .blur(radius: shown ? 0 : 3)
            .onAppear {
                guard !reduceMotion else { shown = true; return }
                withAnimation(Motion.entrance.delay(Double(min(index, 6)) * 0.045)) {
                    shown = true
                }
            }
    }
}

/// Un element qui repond au doigt.
///
/// **Le retour tactile est ici, et pas dans l'action.** Il doit arriver a
/// l'appui, pas au relachement : c'est ce qui donne la sensation d'un objet
/// touche plutot que d'une commande executee.
struct Pressable: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(Motion.state, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Feedback.play(.threadOpened) }
            }
    }
}

extension View {
    func cardEntrance(_ index: Int = 0) -> some View {
        modifier(CardEntrance(index: index))
    }
}
