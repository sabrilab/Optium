import SwiftUI

/// Les sept dernieres nuits, sous la clarte du jour.
///
/// **Le lien entre les deux etait dans le calcul, jamais a l'ecran.** Un mot —
/// « haute », « basse » — apparaissait seul, et il fallait ouvrir un autre
/// ecran pour savoir sur quoi il reposait. Un verdict dont la cause se trouve
/// ailleurs se subit ; pose a cote de sa cause, il s'examine.
///
/// **Des barres, pas des chiffres.** Sept durees alignees se comparent d'un
/// coup d'oeil, ce que sept nombres ne permettent pas. Ce n'est pas un
/// graphique de statistiques : il n'y a ni axe, ni echelle chiffree, ni
/// moyenne. Juste ce qui a ete lu.
///
/// **Une seule couleur**, comme partout ailleurs. Ce qui distingue une nuit
/// deduite d'une nuit mesuree est son opacite, pas sa teinte — introduire un
/// second ton ici casserait la regle et, pire, ferait passer la deduction pour
/// une catégorie de sommeil.
struct NightsStrip: View {
    let nights: [RecordedNight]
    /// Le nombre de nuits sur lesquelles la clarte est **reellement**
    /// calculee.
    ///
    /// La legende ecrivait « se calcule sur ces 7 nuits » parce qu'elle
    /// comptait les barres affichees. Le moteur, lui, travaille sur vingt-huit
    /// : la premiere affirmation verifiable de l'application etait fausse des
    /// la huitieme nuit.
    var observedNights: Int?
    /// La cible haute, pour poser le trait de reference.
    var target: TimeInterval = 8 * 3600

    private var recent: [RecordedNight] {
        Array(nights.sorted { $0.wokeAt < $1.wokeAt }.suffix(7))
    }

    /// L'echelle. Dix heures de haut : au-dela, une nuit exceptionnelle
    /// ecraserait toutes les autres.
    private let ceiling: TimeInterval = 10 * 3600

    /// **Des barres etroites, a largeur fixe.** Etalees sur toute la largeur
    /// disponible, elles font trente-cinq points de large pour quarante de
    /// haut : l'oeil y lit des pastilles alignees, et les differences de duree
    /// disparaissent dans la masse. Etroites, la hauteur redevient la seule
    /// chose qui varie, donc la seule qu'on lit.
    private let barWidth: CGFloat = 13
    private let height: CGFloat = 46

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                // Le trait de cible, sur la largeur des barres seulement. Sans
                // lui, on voit des hauteurs, pas des durees.
                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: totalWidth, height: 1)
                    .offset(y: -height * (target / ceiling))

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(recent) { night in
                        bar(night)
                    }
                    // Les nuits manquantes laissent leur place vide plutot que
                    // de resserrer les autres : le trou est une information.
                    ForEach(recent.count..<7, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.07))
                            .frame(width: barWidth, height: 3)
                    }
                }
            }
            .frame(height: height, alignment: .bottom)

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var totalWidth: CGFloat { barWidth * 7 + 10 * 6 }

    private func bar(_ night: RecordedNight) -> some View {
        let share = min(1, night.night.duration / ceiling)
        return RoundedRectangle(cornerRadius: 3)
            .fill(Ink.marker.opacity(night.measured ? 0.92 : 0.38))
            .frame(width: barWidth, height: max(3, height * share))
            .overlay(alignment: .bottom) {
                // La nuit deduite porte un trait de base : sans lui, elle se
                // lit comme une nuit mesuree plus courte.
                if !night.measured {
                    Rectangle()
                        .fill(Ink.marker.opacity(0.85))
                        .frame(height: 2)
                }
            }
    }

    /// Ce que la bande dit, en une ligne, et **rattache a aujourd'hui**.
    private var caption: String {
        guard !recent.isEmpty else { return "Aucune nuit lue. Ta clarté ne peut pas être calculée." }
        let total = observedNights ?? recent.count

        // Sous le seuil, aucun calcul n'a lieu : l'affirmer serait faux.
        guard total >= ClarityEngine.minimumNights else {
            return "\(total) nuit\(total > 1 ? "s" : "") lue\(total > 1 ? "s" : ""). Optium en attend \(ClarityEngine.minimumNights) avant d’en tirer quoi que ce soit."
        }

        let inferred = recent.count { !$0.measured }
        let base = "Ta clarté d’aujourd’hui se calcule sur \(total) nuits"
        if inferred == recent.count { return base + ", déduites du mouvement du téléphone." }
        if inferred > 0 { return base + ". Les \(inferred) plus récentes sont déduites du mouvement." }
        return base + ", lues dans Santé."
    }
}
