import SwiftUI

/// La modale qui dit sur quoi une affirmation repose.
///
/// **Noir, comme tout le reste.** Un fond clair avait été essayé — la rupture
/// devait signaler qu'on quitte l'instrument pour lire un document. C'était
/// payer l'unité de l'application pour un effet : le noir est une décision de
/// direction artistique, pas un décor, et une seule surface qui s'en écarte
/// se lit comme un accident.
///
/// La hiérarchie de lecture est portée par la typographie et l'espacement,
/// jamais par l'inversion.
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

    private let paper = Ink.canvas
    private let ink = Color.white

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

                    Divider().overlay(ink.opacity(0.14))

                    // `Text(.init(_:))` interprete le markdown : sans ca, les
                    // asterisques du titre de revue s'affichent telles quelles.
                    Text(.init(evidence.reference))
                        .font(.footnote)
                        .foregroundStyle(ink.opacity(0.45))
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
            .preferredColorScheme(.dark)
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
                .foregroundStyle(ink.opacity(0.5))
            Text(evidence.verification.caution)
                .font(.footnote)
                .foregroundStyle(ink.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(ink.opacity(0.07))
        }
    }

    private func block(_ title: String, _ body: String, emphasised: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(ink.opacity(0.5))
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
