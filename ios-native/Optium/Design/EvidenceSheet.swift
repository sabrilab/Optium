import SwiftUI

/// La modale qui dit sur quoi une affirmation repose.
///
/// **Fond clair, texte sombre — la seule surface de l'application qui inverse
/// le noir.** Tout le reste est noir permanent : cette rupture est le message.
/// On quitte l'instrument pour lire un document, et l'œil le sait avant de
/// lire un mot.
///
/// **Aucune image.** Une photo de chercheur, de laboratoire ou de première
/// page d'article emprunte une autorité au lieu de l'établir, et n'a
/// généralement aucun rapport avec le travail cité. Le texte porte tout —
/// c'est aussi ce qui la rend traduisible et lisible par VoiceOver sans perte.
///
/// **Ce que l'étude ne montre pas est un champ obligatoire**, et c'est la
/// partie qui vaut le plus. Une application qui cite trois travaux pour se
/// donner du poids est ordinaire ; une qui dit « cette partie repose sur un
/// effet contesté » ne l'est pas.
struct EvidenceSheet: View {
    let evidence: Evidence

    @Environment(\.dismiss) private var dismiss

    private let paper = Color(red: 0.96, green: 0.955, blue: 0.94)
    private let ink = Color(red: 0.11, green: 0.11, blue: 0.12)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(evidence.claim)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)

                    verification

                    block("CE QUE LE TRAVAIL ÉTABLIT", evidence.shows)
                    // La seule section marquée : c'est celle qu'aucune autre
                    // application n'écrit.
                    block("CE QU’IL N’ÉTABLIT PAS", evidence.doesNotShow, emphasised: true)
                    block("CE QU’OPTIUM EN FAIT", evidence.usedFor)

                    Divider().overlay(ink.opacity(0.18))

                    // `Text(.init(_:))` interprete le markdown : sans ca, les
                    // asterisques du titre de revue s'affichent telles quelles.
                    Text(.init(evidence.reference))
                        .font(.footnote)
                        .foregroundStyle(ink.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(paper)
            .navigationTitle("Sur quoi ça repose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            // La modale est un document : elle sort du noir permanent, donc
            // aussi de l'apparence sombre forcée à la racine.
            .preferredColorScheme(.light)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                        .tint(ink)
                }
            }
        }
    }

    /// Le niveau de preuve, dit avant le contenu.
    ///
    /// **Il vient en premier parce qu'il conditionne tout le reste.** Une
    /// méta-analyse sur soixante mille personnes et un rapport de source
    /// secondaire ne pèsent pas pareil, et le lecteur a le droit de le savoir
    /// avant d'avoir lu.
    private var verification: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(evidence.verification.rawValue.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(ink.opacity(0.55))
            Text(evidence.verification.caution)
                .font(.footnote)
                .foregroundStyle(ink.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(ink.opacity(0.05))
        }
    }

    private func block(_ title: String, _ body: String, emphasised: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(ink.opacity(0.55))
            Text(.init(body))
                .font(.system(size: 16, weight: emphasised ? .regular : .light))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Le bouton qui ouvre une modale de fondement.
///
/// **Discret, et jamais obligatoire.** Il ne doit pas se lire comme un
/// avertissement ni réclamer d'être touché : quelqu'un qui n'a pas de doute ne
/// doit pas être arrêté par lui.
struct EvidenceButton: View {
    let evidence: Evidence
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)
                // La cible tactile fait 44 points, l'icône treize : le confort
                // ne se paye pas en encombrement visuel.
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sur quoi repose : \(evidence.claim)")
        .sheet(isPresented: $showing) {
            EvidenceSheet(evidence: evidence)
        }
    }
}
