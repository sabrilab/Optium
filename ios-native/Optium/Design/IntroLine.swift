import SwiftUI

/// La phrase qui nomme une chose, au moment où elle apparaît pour la première
/// fois.
///
/// **On n'enseigne pas le vocabulaire d'avance.** L'application demande
/// d'apprendre une douzaine de mots inventés — fil, reprise, clarté, fenêtre,
/// palier, retenue, preuves, restitution. Un écran qui les définit tous est un
/// écran que personne ne lit, et il arrive de toute façon avant que le premier
/// d'entre eux ait un objet à désigner.
///
/// Chaque mot s'introduit donc **sur la chose elle-même**, une fois, et jamais
/// plus. La phrase est posée juste sous l'objet qu'elle nomme : elle n'a pas à
/// décrire ce qu'on ne voit pas.
///
/// **Elle se retire d'elle-même**, sans bouton « Compris ». Un accusé de
/// lecture est une demande, et l'application ne demande rien — elle mesure, et
/// accepte d'être corrigée.
struct IntroLine: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        }
        .transition(.opacity)
    }
}

/// Les phrases d'introduction, et l'ordre dans lequel elles peuvent tomber.
///
/// **Une seule par session d'avant-plan.** Santé rend souvent vingt-huit nuits
/// d'un coup : sans file, les trois phrases du chemin principal s'empileraient
/// dans la même seconde — exactement le mur de vocabulaire que le produit
/// s'interdit.
enum Intro: String, CaseIterable, Sendable {
    /// La règle du jour. **Toujours en premier** : c'est elle qui rend
    /// l'application utilisée, là où la porte la rend défendable.
    case rule
    /// La clarté et la fenêtre, fusionnées — la question « ça veut dire quoi
    /// et d'où ça sort » est la même, et la poser en deux fois retarderait la
    /// porte d'une session.
    case clarity
    /// La porte, le seul refus.
    case gate
    /// La trace des reprises, à la deuxième ouverture d'un fil.
    case resumption
    /// La retenue, à la première ouverture de la porte.
    case hold
    /// Le palier, quand il devient calculable.
    case tier

    /// L'ordre est immuable : la règle avant tout le reste.
    var rank: Int { Intro.allCases.firstIndex(of: self) ?? 0 }
}
