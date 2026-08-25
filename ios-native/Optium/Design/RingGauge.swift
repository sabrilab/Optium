import SwiftUI

/// Une jauge circulaire, sur le composant natif d'Apple.
///
/// **`Gauge` et non un `Circle().trim()` fait maison.** Le composant du
/// systeme apporte trois choses qu'une trace a la main n'a pas : le trace
/// exact d'Apple, la valeur lue par VoiceOver sans qu'on l'ecrive, et le
/// comportement correct en corps accessibilite. C'est le meme raisonnement que
/// pour la barre d'onglets, ou une reconstruction a la main n'a jamais valu
/// l'objet du systeme.
///
/// **Ou une jauge circulaire a le droit d'exister.** Elle demande **un rapport
/// avec un tout naturel** — une part sur un ensemble que l'utilisateur peut
/// nommer. Dans Optium il n'y en a que deux : les nuits observees sur le
/// minimum requis, et l'avancee dans la fenetre du jour. Tout le reste serait
/// un score deguise : la clarte n'a pas de « tout », le palier n'est pas un
/// pourcentage, et les afficher en anneau reviendrait a montrer le nombre que
/// le produit s'interdit d'ecrire.
struct RingGauge<Center: View>: View {
    /// 0…1.
    let progress: Double
    /// Ce que VoiceOver dit. **Obligatoire** : un anneau sans enonce est
    /// muet pour qui ne le voit pas.
    let spoken: String
    var tint: Color = Ink.marker
    var size: CGFloat = 44
    @ViewBuilder var center: Center

    var body: some View {
        Gauge(value: min(1, max(0, progress))) {
            EmptyView()
        } currentValueLabel: {
            center
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(tint)
        .scaleEffect(size / 58)
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}

extension RingGauge where Center == EmptyView {
    init(progress: Double, spoken: String, tint: Color = Ink.marker, size: CGFloat = 44) {
        self.init(progress: progress, spoken: spoken, tint: tint, size: size) { EmptyView() }
    }
}
