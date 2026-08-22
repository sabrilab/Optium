import SwiftUI

// Les modules d'analyse des nuits.
//
// **Retrospectifs, factuels, et chacun dit ce qu'il ne peut pas dire.** Une
// application qui affiche des courbes de sommeil sans les qualifier fabrique
// de la certitude a partir d'une mesure approximative ; le garde-fou contre
// l'orthosomnie du projet interdit d'en faire une performance a optimiser.
//
// D'ou trois regles tenues dans chaque module :
//
// - aucune note, aucun score global, aucune serie a ne pas briser ;
// - aucune projection — on ne montre que ce qui a eu lieu ;
// - une phrase de limite, toujours, et jamais en petits caracteres gris pale.

/// Un module : un titre, un dessin, un fait, une limite.
struct NightModule<Content: View>: View {
    let title: String
    /// Le fait, en une ligne. Ce que le dessin montre, dit en toutes lettres —
    /// un graphique qu'il faut interpreter seul n'informe que ceux qui savent
    /// deja.
    let fact: String
    /// Ce que ce module **ne dit pas**. Obligatoire.
    let limit: String
    var hue: Ink.CardHue = Ink.indigo
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            content

            Text(fact)
                .font(.system(size: 16, weight: .light))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(limit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(hue, corner: 28, intensity: 0.5)
    }
}

// ── L'empreinte ──

/// Ou tombent les nuits dans la journee, une ligne par jour.
///
/// **C'est le diagramme qui montre ce que l'indice de regularite mesure.** Le
/// SRI est un nombre ; ici on voit la chose elle-meme — un bloc qui reste en
/// place, ou qui derive. Personne n'a besoin qu'on lui explique un actogramme :
/// l'alignement se voit ou ne se voit pas.
struct SleepRaster: View {
    let rows: [NightInsights.RasterRow]

    private let rowHeight: CGFloat = 7
    private let gap: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    // Les reperes de minuit et de 6 h. Deux, pas douze : une
                    // grille complete transformerait le dessin en tableau.
                    ForEach([6.0, 12.0], id: \.self) { offset in
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 1)
                            .offset(x: proxy.size.width * (offset / 24))
                    }

                    VStack(spacing: gap) {
                        ForEach(rows) { row in
                            band(row, width: proxy.size.width)
                        }
                    }
                }
            }
            .frame(height: CGFloat(rows.count) * (rowHeight + gap))

            HStack {
                Text("18 h").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("minuit").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("6 h").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("18 h").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func band(_ row: NightInsights.RasterRow, width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.05))
            ForEach(Array(row.spans.enumerated()), id: \.offset) { _, span in
                Capsule()
                    .fill(Ink.marker.opacity(row.inferred ? 0.38 : 0.88))
                    .frame(width: max(2, width * (span.upperBound - span.lowerBound)))
                    .offset(x: width * span.lowerBound)
            }
        }
        .frame(height: rowHeight)
    }
}

// ── Les levers ──

/// L'heure de lever, jour apres jour, autour de sa mediane.
///
/// La grandeur affichee ailleurs — « tes trois derniers levers ont varie de
/// 2 h 10 » — est un fait ponctuel. Ici on voit s'il s'agit d'un accident ou
/// d'une habitude.
struct WakeScatter: View {
    let points: [NightInsights.WakePoint]

    /// La fenetre verticale, autour de la mediane. Quatre heures de part et
    /// d'autre : au-dela, un lever aberrant ecrase tous les autres.
    private let span = 4.0

    private var median: Double {
        let hours = points.map(\.hour).sorted()
        return hours.isEmpty ? 7 : hours[hours.count / 2]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                // La mediane, au milieu. C'est la reference, pas une cible :
                // rien ne dit qu'il faille s'y tenir.
                Rectangle()
                    .fill(Ink.marker.opacity(0.35))
                    .frame(height: 1)
                    .offset(y: proxy.size.height / 2)

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let x = points.count > 1
                        ? proxy.size.width * CGFloat(index) / CGFloat(points.count - 1)
                        : proxy.size.width / 2
                    let offset = (point.hour - median) / span
                    let y = proxy.size.height * (0.5 - CGFloat(max(-1, min(1, offset))) / 2)

                    Circle()
                        .fill(Ink.marker.opacity(point.inferred ? 0.38 : 0.9))
                        .frame(width: 5, height: 5)
                        .offset(x: x - 2.5, y: y - 2.5)
                }
            }
        }
        .frame(height: 74)
    }
}

// ── Les durees, sur la periode ──

/// Chaque nuit, et la bande cible.
///
/// La bande n'est pas une note : la relation duree/mortalite est en U, et
/// dormir douze heures n'est pas mieux que d'en dormir huit. C'est pourquoi
/// c'est une bande et non un plancher.
struct DurationBars: View {
    let nights: [RecordedNight]
    private let ceiling: TimeInterval = 11 * 3600

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                // La cible, 7 h a 9 h.
                let low = proxy.size.height * (ClarityEngine.targetRange.lowerBound / ceiling)
                let high = proxy.size.height * (ClarityEngine.targetRange.upperBound / ceiling)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: high - low)
                    .offset(y: -low)

                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(nights) { night in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Ink.marker.opacity(night.measured ? 0.85 : 0.35))
                            .frame(height: max(2, proxy.size.height
                                   * min(1, night.night.duration / ceiling)))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(height: 88)
    }
}

// ── Deux medianes cote a cote ──

/// Le cafe tardif, et la nuit qui suit.
///
/// **Deux barres, jamais une fleche.** Une fleche dirait une cause ; les jours
/// a cafe tardif sont souvent les jours charges, et c'est peut-etre la charge
/// qui raccourcit la nuit.
struct PairedBars: View {
    let leftLabel: String
    let leftValue: TimeInterval
    let rightLabel: String
    let rightValue: TimeInterval

    private var ceiling: TimeInterval { max(leftValue, rightValue) * 1.15 }

    var body: some View {
        HStack(alignment: .bottom, spacing: 22) {
            column(leftLabel, leftValue, opacity: 0.45)
            column(rightLabel, rightValue, opacity: 0.88)
            Spacer()
        }
        .frame(height: 96)
    }

    private func column(_ label: String, _ value: TimeInterval, opacity: Double) -> some View {
        VStack(spacing: 6) {
            Text(hours(value))
                .font(.system(size: 15, weight: .medium))
                .monospacedDigit()
            RoundedRectangle(cornerRadius: 4)
                .fill(Ink.marker.opacity(opacity))
                .frame(width: 40, height: max(4, 56 * (value / ceiling)))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 78)
    }

    private func hours(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        return minutes % 60 == 0
            ? "\(minutes / 60) h"
            : String(format: "%d h %02d", minutes / 60, minutes % 60)
    }
}

// ── Le decalage social ──

/// Deux aiguilles sur un cadran de vingt-quatre heures.
///
/// **Un cadran plutot qu'une barre**, parce que la grandeur est une heure et
/// non une quantite : voir deux milieux de nuit s'ecarter sur un tour d'horloge
/// dit ce qu'est le decalage — vivre a deux heures differentes — la ou une
/// barre de « 1 h 40 » ne dirait qu'une longueur.
struct SocialLagDial: View {
    /// L'ecart, en heures.
    let hours: Double

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    .frame(width: 78, height: 78)

                // La semaine, en haut. L'aiguille est une reference, pas une
                // heure reelle : ce qui compte est l'angle entre les deux.
                hand(angle: 0, opacity: 0.85)
                hand(angle: hours / 24 * 360, opacity: 0.45)
            }

            VStack(alignment: .leading, spacing: 3) {
                legend("semaine", opacity: 0.85)
                legend("week-end", opacity: 0.45)
            }
            Spacer()
        }
        .frame(height: 92)
    }

    private func hand(angle: Double, opacity: Double) -> some View {
        Rectangle()
            .fill(Ink.marker.opacity(opacity))
            .frame(width: 2, height: 32)
            .offset(y: -16)
            .rotationEffect(.degrees(angle))
    }

    private func legend(_ text: String, opacity: Double) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Ink.marker.opacity(opacity))
                .frame(width: 10, height: 2)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// ── Le biais de la source ──

/// L'ecart median entre ce que la source annonce et ce qui est vrai.
///
/// **Deux reperes et la distance entre eux**, pas une courbe. La grandeur est
/// un decalage systematique, pas une evolution : la montrer comme une serie
/// temporelle laisserait croire qu'elle bouge, alors qu'elle se stabilise.
struct BiasArrow: View {
    /// Positif : le vrai reveil est plus tard que l'annonce.
    let minutes: Double

    private var isLater: Bool { minutes > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { proxy in
                let width = proxy.size.width
                // Le decalage occupe au plus un tiers de la largeur : au-dela,
                // une correction d'une heure et une de trois heures se
                // dessineraient pareil.
                let travel = min(width * 0.32, width * CGFloat(abs(minutes)) / 180)

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                        .offset(y: 9)

                    marker(x: width * 0.28, opacity: 0.35, label: "annoncé")
                    marker(x: width * 0.28 + (isLater ? travel : -travel),
                           opacity: 0.9, label: "réel")
                }
            }
            .frame(height: 44)
        }
    }

    private func marker(x: CGFloat, opacity: Double, label: String) -> some View {
        VStack(spacing: 3) {
            Capsule()
                .fill(Ink.marker.opacity(opacity))
                .frame(width: 3, height: 18)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 60)
        .offset(x: x - 30)
    }
}
