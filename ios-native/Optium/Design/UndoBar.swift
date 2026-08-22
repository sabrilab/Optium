import SwiftData
import SwiftUI

/// La bande d'annulation.
///
/// **Elle apparait apres l'action, jamais avant.** Une commande d'annulation
/// permanente en bas d'ecran devient un element de decor, donc invisible ; une
/// bande qui ne vient que lorsqu'il y a quelque chose a defaire se remarque a
/// chaque fois.
///
/// **Elle nomme ce qu'elle defait.** « Annuler » seul oblige a se rappeler ce
/// qu'on vient de faire, ce qui est exactement la faculte qui manque au moment
/// ou l'on se trompe.
///
/// Elle ne demande jamais confirmation. Une confirmation avant chaque
/// suppression punit les mille fois ou l'on ne se trompe pas ; l'annulation
/// apres coup ne coute rien a personne.
struct UndoBar: View {
    @Environment(ActionLog.self) private var log
    @Environment(\.modelContext) private var context

    var body: some View {
        if let pending = log.pending, context.undoManager?.canUndo == true {
            HStack(spacing: 14) {
                Text(pending)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button {
                    Feedback.play(.held)
                    context.undoManager?.undo()
                    log.clear()
                } label: {
                    Label("Annuler", systemImage: "arrow.uturn.backward")
                        .font(.footnote.weight(.medium))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Ink.marker)
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

extension View {
    /// Pose la bande au-dessus de la barre d'onglets.
    func undoBar() -> some View {
        overlay(alignment: .bottom) {
            UndoBar()
                // Au-dessus de la barre d'onglets : posee dessous, elle serait
                // cachee par elle au moment ou elle sert.
                .padding(.bottom, 62)
        }
    }
}
