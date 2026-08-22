import ActivityKit
import SwiftUI
import WidgetKit

/// La reprise en cours, sur l'ecran verrouille et dans l'ile dynamique.
///
/// **Le seul endroit ou le fluide bouge en continu** — a une reserve pres,
/// qu'il faut nommer : ActivityKit ne fait pas tourner de boucle d'animation.
/// Le contenu se met a jour par envois espaces, a une frequence que le
/// systeme plafonne. On obtient donc un niveau qui glisse d'un envoi a
/// l'autre, pas une surface qui respire a soixante images par seconde.
///
/// **Jamais « Fermer le fil » depuis l'ile.** La porte doit rester dans
/// l'application : c'est la seule friction du produit, et la franchir d'un
/// pouce sur un ecran verrouille la viderait de son sens.
struct OptiumLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OptiumActivity.self) { context in
            lockScreen(context)
                // Le lavis passe par le fond de la vue : `activityBackgroundTint`
                // ne prend qu'une couleur unie, pas un degrade.
                .background { BentoWash(tint: Ink.indigo.tint, intensity: 0.85) }
                .activityBackgroundTint(Ink.canvas)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BrainMark(
                        fill: context.state.fill,
                        base: context.state.base,
                        tint: Ink.focusGlow
                    )
                    .frame(width: 64, height: 64)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Clarté \(context.state.clarityWord)")
                            .font(.system(size: 12, weight: .medium))
                        Text("\(context.state.resumptionNumber)ᵉ reprise")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(context.state.startedAt, style: .timer)
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(Ink.marker)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.attributes.phrase)
                            .font(.system(size: 15, weight: .light))
                            .lineLimit(2)
                        WindowBar(end: context.state.windowEnd)
                    }
                }
            } compactLeading: {
                BrainMark(fill: context.state.fill, tint: Ink.focusGlow)
                    .frame(width: 22, height: 22)
            } compactTrailing: {
                // **Le temps ecoule, pas le mot de clarte.** C'est la forme
                // repliee qui s'affiche quand on quitte l'application : y
                // mettre un mot qu'on vient de lire dans l'app, au lieu de la
                // seule chose qui bouge, la rendait inutile.
                //
                // La clarte reste presente : c'est le remplissage du cerveau,
                // a gauche, exactement comme partout ailleurs.
                Text(context.state.startedAt, style: .timer)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Ink.marker)
                    // Sans largeur fixe, l'ile se redimensionne au passage de
                    // 9:59 a 10:00 et le contenu sautille.
                    .frame(width: 52)
            } minimal: {
                // Le cerveau seul : a cette taille il n'y a de place pour rien
                // d'autre, et c'est lui le signal.
                BrainMark(fill: context.state.fill, tint: Ink.focusGlow)
            }
        }
    }

    private func lockScreen(_ context: ActivityViewContext<OptiumActivity>) -> some View {
        HStack(alignment: .top, spacing: 16) {
            BrainMark(
                fill: context.state.fill,
                base: context.state.base,
                tint: Ink.focusGlow,
                showsBase: true
            )
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 8) {
                Text(context.attributes.phrase)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Text("Clarté \(context.state.clarityWord)")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.4))
                    Text(context.state.startedAt, style: .timer)
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Ink.marker)
                }

                WindowBar(end: context.state.windowEnd)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

/// La piste de fenetre, reduite a l'essentiel : combien de temps il reste.
private struct WindowBar: View {
    let end: Date

    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(Ink.marker)
                .frame(width: 3, height: 10)
            Text("Fenêtre jusqu’à \(end.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
