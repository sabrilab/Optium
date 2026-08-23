import SwiftUI

/// La règle de la journée, dressée contre le cerveau.
///
/// **Une règle d'écolier, pas un graphique.** Le temps descend du lever (en
/// haut) vers le soir (en bas). Il n'y a qu'UNE population de marques : une
/// graduation par demi-heure d'horloge. De part et d'autre du dos, chacune
/// porte deux choses qui ne peuvent pas se confondre parce qu'elles ne
/// partagent aucun côté :
///
/// - **vers le cerveau, la LONGUEUR dit ce que l'heure laisse passer** de ce
///   que la nuit permet. Longue : cette heure ne te retire presque rien.
///   Courte : elle te descend loin sous ton plafond.
/// - **vers l'extérieur, l'ÉPAISSEUR et le DÉBORD disent la hiérarchie de
///   l'heure** — demi-heure, heure pleine, heure écrite. C'est la grammaire
///   d'une règle (mm / 5 mm / cm), et le débord soude physiquement le chiffre
///   à son trait.
///
/// **Le niveau n'est pas ici, il est dans le cerveau**, à dix points de là,
/// sur 260 pt, avec son remplissage et sa ligne de plafond. La règle ne dit
/// que le QUAND. Une idée par objet : c'est la seule réponse recevable à
/// « elle paraît compliquée ».
///
/// **Aucun nombre de clarté.** Les seuls chiffres sont des heures d'horloge.
/// **Aucune heure de pic annoncée** : le sommet se voit parce que la règle y
/// est la plus large, jamais parce qu'une étiquette le nomme.
///
/// **Rien ne s'anime.** Le curseur avance de 0,235 pt par minute, redessiné
/// par le `TimelineView` de l'accueil. Il n'y a donc rien à couper sous
/// `accessibilityReduceMotion` : la règle le respecte par construction, et non
/// par une branche conditionnelle.
struct DayRule: View {

    /// **Précondition : trié par `hoursAwake` croissant.** C'est le cas de
    /// `ClarityReading.curve`, construit par `Vigilance.curve()`.
    let points: [ClarityReading.CurvePoint]
    /// L'instant à dessiner. **Vient du `TimelineView`, jamais de `Date()`** :
    /// l'heure écrite et la position du curseur doivent avoir la même source,
    /// sinon elles se contredisent d'une minute.
    let now: Date
    /// La fenêtre, en heures depuis le lever. **Doit être dérivée de
    /// `reading.wokeAt`**, la même ancre que `wakeTime`.
    var window: (start: Double, end: Double)?
    /// L'ancre de l'échelle : `ClarityReading.wokeAt`.
    let wakeTime: Date

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 11

    // ── Le gabarit, en points. Tout est ici : une cote écrite ailleurs finit
    //    par diverger. ──

    static let width: CGFloat = 92
    static let height: CGFloat = 260

    private static let span: Double = 17
    private static let spineX: CGFloat = 44
    private static let gutterX: CGFloat = 48
    private static let inset: CGFloat = 10
    private static let shortest: CGFloat = 4
    private static let longest: CGFloat = 40
    private static let overrunHour: CGFloat = 3
    private static let overrunLabelled: CGFloat = 5
    private static let overrunNow: CGFloat = 7
    /// Le plancher de l'échelle des longueurs. **Fixe, jamais renormalisé sur
    /// la journée** : c'est ce qui fait qu'une mauvaise nuit creuse une règle
    /// visiblement plus contrastée qu'une bonne.
    private static let ratioFloor: Double = 0.55

    private var headerHeight: CGFloat { typeSize.isAccessibilitySize ? 26 : 0 }
    private var plotTop: CGFloat { Self.inset + headerHeight }
    private var plotHeight: CGFloat { Self.height - plotTop - Self.inset }

    private var hoursAwake: Double { max(0, now.timeIntervalSince(wakeTime) / 3600) }

    // ── Repérage ──

    private func y(_ hour: Double) -> CGFloat {
        plotTop + plotHeight * CGFloat(min(Self.span, max(0, hour)) / Self.span)
    }

    /// Lecture du modèle à une heure quelconque : la règle est graduée en
    /// demi-heures d'horloge, `points` ne l'est pas.
    private func sample(_ hour: Double) -> (clarity: Double, ceiling: Double) {
        guard let first = points.first, let last = points.last else { return (0, 0) }
        if hour <= first.hoursAwake { return (first.clarity, first.ceiling) }
        if hour >= last.hoursAwake { return (last.clarity, last.ceiling) }
        var low = 0, high = points.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if points[mid].hoursAwake <= hour { low = mid } else { high = mid }
        }
        let a = points[low], b = points[high]
        let width = b.hoursAwake - a.hoursAwake
        guard width > 0 else { return (b.clarity, b.ceiling) }
        let t = (hour - a.hoursAwake) / width
        return (a.clarity + (b.clarity - a.clarity) * t,
                a.ceiling + (b.ceiling - a.ceiling) * t)
    }

    /// **Ce que l'heure laisse passer du plafond**, ramené à 0…1.
    ///
    /// Ni la clarté absolue — la journée n'en parcourt qu'un quart, ce qui
    /// donnait un bord droit —, ni l'écart au plafond du réveil — dont le
    /// zéro est invisible et se déplace chaque jour, et qui dessine le même
    /// motif tous les matins. Le rapport de la clarté au plafond DU MOMENT :
    /// au sommet on frôle 1, au creux on tombe, et la chute est d'autant plus
    /// profonde que la nuit a été mauvaise — ce qui est exactement la
    /// propriété centrale du modèle. Mesuré : l'écart pic-creux passe de
    /// 9,7 pt après une excellente nuit à 30,4 pt après une mauvaise.
    private func weight(at hour: Double) -> Double {
        let point = sample(hour)
        // Une nuit catastrophique plaque le plafond ET la clarté à zéro : sans
        // cette garde, le rapport 0/0 rendrait la règle la plus généreuse le
        // jour où elle a le moins à dire.
        guard point.ceiling > 1 else { return 0 }
        let ratio = min(1, max(0, point.clarity / point.ceiling))
        return min(1, max(0, (ratio - Self.ratioFloor) / (1 - Self.ratioFloor)))
    }

    /// Le futur est plus sourd que le passé à valeur égale : c'est un modèle,
    /// pas une mesure.
    private func opacity(weight: Double, future: Bool) -> Double {
        let strong = contrast == .increased
        if future { return (strong ? 0.26 : 0.15) + (strong ? 0.24 : 0.21) * weight }
        return (strong ? 0.45 : 0.30) + (strong ? 0.40 : 0.42) * weight
    }

    // ── Les graduations ──

    private struct Mark {
        let y: CGFloat
        let length: CGFloat
        let thickness: CGFloat
        let overrun: CGFloat
        let opacity: Double
    }

    private struct HourLabel: Identifiable {
        let y: CGFloat
        let hour: Int
        var id: CGFloat { y }
    }

    /// **Une graduation est une demi-heure d'HORLOGE, pas une demi-heure
    /// depuis le lever.** C'est ce qui fait qu'une étiquette tombe toujours
    /// exactement sur un trait, et que lire l'heure ne demande aucun calcul.
    ///
    /// On avance une `Date` de 1800 s plutôt qu'un `Double` de 0,5 : au bout
    /// de trente-cinq pas, l'accumulation flottante rendrait une minute 59 là
    /// où on attend un 0, et l'heure ronde ne serait plus reconnue.
    private func build(calendar: Calendar = .current) -> (marks: [Mark], labels: [HourLabel]) {
        guard points.count > 1 else { return ([], []) }
        var cursor = calendar.nextDate(after: wakeTime,
                                       matching: DateComponents(minute: 0),
                                       matchingPolicy: .nextTime) ?? wakeTime
        while cursor > wakeTime { cursor.addTimeInterval(-1800) }
        if cursor < wakeTime { cursor.addTimeInterval(1800) }

        var marks: [Mark] = []
        var labels: [HourLabel] = []
        let awake = hoursAwake
        let nowY = y(awake)

        while true {
            let hour = cursor.timeIntervalSince(wakeTime) / 3600
            if hour > Self.span { break }
            let parts = calendar.dateComponents([.hour, .minute], from: cursor)
            let oClock = (parts.minute ?? 0) == 0
            // Ancré sur le CADRAN, pas sur le lever : les chiffres restent
            // ronds quelle que soit l'heure du réveil.
            let labelled = oClock && (parts.hour ?? 0) % 3 == 0
            let value = weight(at: hour)
            let row = y(hour)
            marks.append(Mark(
                y: row,
                length: Self.shortest + (Self.longest - Self.shortest) * CGFloat(value),
                thickness: oClock ? 2.2 : 1.6,
                overrun: labelled ? Self.overrunLabelled : (oClock ? Self.overrunHour : 0),
                opacity: opacity(weight: value, future: hour > awake)))
            // Une étiquette trop près du présent serait recouverte : le
            // présent gagne toujours, c'est la seule heure complète.
            if labelled, !typeSize.isAccessibilitySize, abs(row - nowY) > 16 {
                labels.append(HourLabel(y: row, hour: parts.hour ?? 0))
            }
            cursor.addTimeInterval(1800)
        }
        return (marks, labels)
    }

    // ── Le corps ──

    var body: some View {
        let built = build()
        let marker = Ink.marker
        let strong = contrast == .increased
        let spineInk = Color.white.opacity(strong ? 0.22 : 0.12)
        let labelInk = Color.white.opacity(strong ? 0.80 : 0.60)
        let awake = hoursAwake
        let nowY = y(awake)
        let nowLength = Self.shortest
            + (Self.longest - Self.shortest) * CGFloat(weight(at: awake))

        // La fenêtre n'ajoute aucun objet : elle épaissit le dos. Une échelle
        // pleine se lit comme « accompli » ; passé le créneau c'est l'inverse,
        // donc elle retombe — même arbitrage que `WindowStrip`.
        let windowBar: (rect: CGRect, ink: Color)? = window.map { bounds in
            let top = y(min(bounds.start, bounds.end))
            let bottom = y(max(bounds.start, bounds.end))
            let passed = bounds.end < awake
            let thickness: CGFloat = passed ? 1.6 : 2.5
            return (CGRect(x: Self.spineX + 0.5 - thickness / 2,
                           y: top,
                           width: thickness,
                           height: max(3, bottom - top)),
                    Color.white.opacity(passed ? (strong ? 0.38 : 0.26)
                                               : (strong ? 0.75 : 0.55)))
        }

        return ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                // 1. Le dos de la règle.
                context.fill(
                    Path(CGRect(x: Self.spineX, y: plotTop, width: 1, height: plotHeight)),
                    with: .color(spineInk))

                // 2. Les graduations — l'unique population de marques.
                for mark in built.marks {
                    let rect = CGRect(x: Self.spineX - mark.length,
                                      y: mark.y - mark.thickness / 2,
                                      width: mark.length + mark.overrun,
                                      height: mark.thickness)
                    context.fill(Path(roundedRect: rect, cornerRadius: mark.thickness / 2),
                                 with: .color(.white.opacity(mark.opacity)))
                }

                // 3. La fenêtre, PAR-DESSUS les graduations : peinte avant,
                //    les traits blancs repasseraient sur elle.
                if let windowBar {
                    context.fill(
                        Path(roundedRect: windowBar.rect,
                             cornerRadius: windowBar.rect.width / 2),
                        with: .color(windowBar.ink))
                }

                // 4. Le présent : une graduation parmi les autres, simplement
                //    allumée, avec le plus long débord de la règle — donc
                //    reconnaissable même en vision périphérique, et même quand
                //    l'heure ne lui laisse que quatre points de longueur.
                let cursor = CGRect(x: Self.spineX - nowLength,
                                    y: nowY - 1.4,
                                    width: nowLength + Self.overrunNow,
                                    height: 2.8)
                // Le halo est dessiné, pas filtré : `addFilter(.shadow)`
                // imposerait une passe hors écran à chaque minute.
                context.fill(Path(roundedRect: cursor.insetBy(dx: -3, dy: -3),
                                  cornerRadius: 4.4),
                             with: .color(marker.opacity(0.18)))
                context.fill(Path(roundedRect: cursor, cornerRadius: 1.4),
                             with: .color(marker))
            }
            .frame(width: Self.width, height: Self.height)

            if typeSize.isAccessibilitySize {
                // En corps accessibilité, 44 pt de gouttière ne peuvent pas
                // porter de chiffre lisible. Les heures rondes disparaissent —
                // mais **l'heure qu'il est reste écrite**, en haut de la
                // colonne, où elle peut grandir. C'est la demande centrale :
                // elle ne se supprime pas.
                Text(Clock.hhmm(now))
                    .font(.system(size: min(labelSize, 17), weight: .semibold, design: .rounded)
                        .monospacedDigit())
                    .foregroundStyle(marker)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: Self.width, height: headerHeight, alignment: .trailing)
            } else {
                ForEach(built.labels) { label in
                    Text("\(label.hour) h")
                        .font(.system(size: labelSize, weight: .medium, design: .rounded)
                            .monospacedDigit())
                        .foregroundStyle(labelInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: Self.width - Self.gutterX, height: 14, alignment: .trailing)
                        .offset(x: Self.gutterX, y: label.y - 7)
                }

                // **La seule heure complète de la règle**, et la seule chose
                // écrite en couleur.
                Text(Clock.hhmm(now))
                    .font(.system(size: labelSize, weight: .semibold, design: .rounded)
                        .monospacedDigit())
                    .foregroundStyle(marker)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(width: Self.width - Self.gutterX, height: 14, alignment: .trailing)
                    .offset(x: Self.gutterX, y: nowY - 7)
            }
        }
        .frame(width: Self.width, height: Self.height, alignment: .topLeading)
        // La règle est posée sur le cadre du cerveau, qui capte le doigt
        // (rotation, et le tap qui explique le plafond). Elle est un
        // instrument qu'on lit, pas un contrôle : elle ne prend rien.
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("La règle de ta journée")
        .accessibilityHint("Chaque graduation est une demi-heure. Plus elle est longue, moins cette heure te retire de ce que ta nuit permet.")
        .accessibilityValue(spoken)
    }

    /// Ce qu'on en dit à voix haute. **Aucun chiffre de clarté, aucune heure
    /// de pic** : seulement l'heure qu'il est, et la fenêtre, dans les mêmes
    /// termes que la carte Clarté.
    private var spoken: String {
        var phrase = "Il est \(Clock.hhmm(now))."
        if let window {
            let start = Clock.hhmm(wakeTime.addingTimeInterval(window.start * 3600))
            let end = Clock.hhmm(wakeTime.addingTimeInterval(window.end * 3600))
            let awake = hoursAwake
            if window.end < awake {
                phrase += " Ta fenêtre s’est fermée à \(end)."
            } else if window.start > awake {
                phrase += " Ta fenêtre s’ouvre à \(start)."
            } else {
                phrase += " Fenêtre ouverte jusqu’à \(end)."
            }
        }
        return phrase
    }
}
