import SwiftUI

/// Fond commun a tous les ecrans : noir vrai, sans rien d'autre.
///
/// Une trame de points a ete essayee ici, reprise d'une reference. Elle
/// donnait de la matiere au noir mais salissait l'ensemble a l'usage — le
/// noir se defend mieux seul. Le type reste comme point d'entree unique du
/// fond : les sept ecrans y passent, et un changement ne touche qu'un fichier.
struct InkBackground: View {
    var body: some View {
        Ink.canvas.ignoresSafeArea()
    }
}
