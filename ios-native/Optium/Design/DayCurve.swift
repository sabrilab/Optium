import SwiftUI

/// La journée entière, d'un coup d'œil.
///
/// **C'est la reponse au reproche le plus juste qu'on pouvait faire au
/// produit** : les jours ou l'on a mal dormi, il annoncait qu'on etait en bas
/// et n'avait rien d'autre a dire. Ici on voit que le creux de l'apres-midi
/// est passager, et qu'il y a un rebond derriere.
///
/// **Deux traces, jamais fondues en une.** La ligne haute est le plafond — ce
/// que la nuit permet encore — et elle descend. Les graduations dessous sont
/// la clarte, qui ondule. **L'ecart entre les deux se lit comme ce qui reste
/// disponible**, et c'est toute l'information.
///
/// Le vocabulaire est celui de `TickScale` : des graduations, pas une courbe
/// pleine. Une aire remplie se lirait comme un graphique de statistiques, et
/// l'application n'en fait pas.
///
/// **Aucun chiffre, aucune heure de pic annoncee.** Le modele a deux processus
/// est solide ; predire un pic personnel a l'heure pres ne l'est pas — voir la
/// reserve de `Vigilance` sur *Collabra: Psychology* (2023). On montre une
/// forme, jamais une promesse.
struct DayCurve: View {
    let points: [ClarityReading.CurvePoint]
    /// Heures depuis le reveil, pour poser le repere du present.
    let hoursAwake: Double
    /// La fenetre du jour, en heures depuis le reveil.
    var window: (start: Double, end: Double)?

    private var span: (min: Double, max: Double) {
        let hours = points.map(\.hoursAwake)
        return (hours.min() ?? 0, hours.max() ?? 16)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .topLeading) {
                windowBand(width: width, height: height)
                ceilingLine(width: width, height: height)
                ticks(width: width, height: height)
                nowMarker(width: width, height: height)
            }
        }
        .frame(height: 92)
        .accessibilityLabel("La courbe de ta journée")
    }

    // ── Position ──

    private func x(_ hour: Double, _ width: CGFloat) -> CGFloat {
        let (low, high) = span
        guard high > low else { return 0 }
        return width * CGFloat((hour - low) / (high - low))
    }

    private func y(_ value: Double, _ height: CGFloat) -> CGFloat {
        height * CGFloat(1 - min(1, max(0, value / 100)))
    }

    // ── Les couches ──

    /// La fenetre, posee derriere. Elle est **derivee de cette courbe** : elle
    /// entoure le sommet, et se retrecit d'elle-meme apres une mauvaise nuit.
    @ViewBuilder
    private func windowBand(width: CGFloat, height: CGFloat) -> some View {
        if let window {
            let start = x(window.start, width)
            let end = x(window.end, width)
            RoundedRectangle(cornerRadius: 4)
                .fill(Ink.marker.opacity(0.10))
                .frame(width: max(4, end - start), height: height)
                .offset(x: start)
        }
    }

    /// Le plafond : une ligne fine qui descend.
    private func ceilingLine(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            for (index, point) in points.enumerated() {
                let position = CGPoint(x: x(point.hoursAwake, width), y: y(point.ceiling, height))
                if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
            }
        }
        .stroke(Color.white.opacity(0.30), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    /// La clarte, en graduations. Le present et la suite se distinguent par la
    /// valeur, jamais par la teinte : ce qui est passe est simplement plus
    /// sourd.
    private func ticks(width: CGFloat, height: CGFloat) -> some View {
        let step = max(1, points.count / 46)
        return ForEach(Array(stride(from: 0, to: points.count, by: step)), id: \.self) { index in
            let point = points[index]
            let top = y(point.clarity, height)
            let past = point.hoursAwake < hoursAwake

            Capsule()
                .fill(Ink.marker.opacity(past ? 0.28 : 0.85))
                .frame(width: 2, height: max(2, height - top))
                .offset(x: x(point.hoursAwake, width) - 1, y: top)
        }
    }

    /// Le present. **La seule couleur franche**, comme partout ailleurs.
    private func nowMarker(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Ink.marker)
            .frame(width: 1.5, height: height)
            .offset(x: x(hoursAwake, width) - 0.75)
            .shadow(color: Ink.marker.opacity(0.6), radius: 4)
    }
}
