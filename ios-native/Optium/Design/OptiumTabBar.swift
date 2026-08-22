import SwiftUI

/// La barre d'onglets, alignee a gauche.
///
/// **Aucune API ne permet de l'obtenir du systeme.** `TabBarPlacement` ne
/// propose que `topBar`, `bottomBar` et `sidebar` — cette derniere reservee aux
/// dispositions adaptatives de l'iPad. La barre flottante d'iOS 26 est centree,
/// sans reglage.
///
/// Elle est donc dessinee ici, et le `TabView` du systeme n'est conserve que
/// pour ce qu'il fait bien : la selection, l'etat de chaque onglet, et la pile
/// de navigation propre a chacun. **Sa barre est masquee, pas remplacee** — les
/// vues restent des `Tab`, et revenir au systeme se fait en supprimant deux
/// lignes.
///
/// **Ce n'est pas une pratique recommandee.** Les Human Interface Guidelines
/// demandent une barre d'onglets standard, et celle d'iOS 26 est une
/// affordance systeme. C'est un ecart assume, a la demande explicite du
/// proprietaire du produit — pas un choix a reproduire ailleurs sans raison.
///
/// Ce qu'on perd : la reduction automatique au defilement d'iOS 26 et le rendu
/// par defaut des badges. Ce qu'on garde : le verre d'Apple, les cibles de
/// 44 points, le comportement de selection, et **les deux libelles**.
///
/// Une premiere version ne montrait le libelle que sur l'onglet courant, au
/// motif que deux libelles cote a cote reconstituent la largeur d'une barre
/// centree et que l'alignement ne se voit plus. C'etait payer la lisibilite
/// pour un effet : l'onglet inactif devenait une icone seule a 45 %
/// d'opacite, moins identifiable que dans la barre du systeme. L'alignement ne
/// vaut pas ca.
struct OptiumTabBar: View {
    @Binding var selection: RootTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                item(tab)
            }
        }
        .padding(6)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        // Alignee a gauche, avec la meme marge que les cartes : la barre
        // appartient a la colonne de contenu, elle ne flotte pas au milieu.
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        // Au-dessus de l'indicateur d'accueil : collee au bord, la barre est
        // difficile a viser et entre en conflit avec le geste de fermeture.
        .padding(.bottom, 6)
    }

    /// **L'icone au-dessus du libelle, comme la barre du systeme.**
    ///
    /// Une premiere version les mettait cote a cote pour tenir en une capsule
    /// etroite. C'etait deux fois faux : l'element devenait petit — donc moins
    /// facile a viser — et il ne ressemblait plus a ce qu'est une barre
    /// d'onglets sur iOS. L'alignement a gauche etait la seule demande ; la
    /// forme de l'element, elle, n'avait aucune raison de changer.
    private func item(_ tab: RootTab) -> some View {
        let isCurrent = tab == selection

        return Button {
            guard !isCurrent else { return }
            Feedback.play(.answered)
            selection = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 22, weight: .medium))
                    .frame(height: 24)
                Text(tab.title)
                    .font(.system(size: 11, weight: isCurrent ? .semibold : .regular))
                    .fixedSize()
            }
            // L'inactif reste franchement lisible. A 0,45 il fallait le
            // chercher ; le contraste porte la selection, pas la disparition.
            .foregroundStyle(isCurrent ? Ink.control : Color.white.opacity(0.72))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(minWidth: 76)
            .background {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.14))
                }
            }
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .animation(Motion.state, value: isCurrent)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isCurrent ? [.isSelected, .isButton] : .isButton)
    }
}
