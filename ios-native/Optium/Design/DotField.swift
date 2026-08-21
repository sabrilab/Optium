import SwiftUI

/// Trame de points posee sur le fond noir.
///
/// Sans elle, le noir est un vide : rien n'y donne l'echelle ni la matiere, et
/// les cartes semblent flotter sur rien. La trame lui donne une surface, tres
/// discretement — a cette opacite on ne la voit pas, on la sent.
///
/// Elle rime aussi avec l'afficheur du minuteur, qui est fait des memes points.
struct DotField: View {
    var spacing: CGFloat = 17
    var dot: CGFloat = 1.7
    var opacity: Double = 0.085

    var body: some View {
        Canvas { context, size in
            let columns = Int(size.width / spacing) + 2
            let rows = Int(size.height / spacing) + 2
            let color = GraphicsContext.Shading.color(.white.opacity(opacity))

            for row in 0..<rows {
                for column in 0..<columns {
                    let rect = CGRect(
                        x: CGFloat(column) * spacing,
                        y: CGFloat(row) * spacing,
                        width: dot,
                        height: dot
                    )
                    context.fill(Path(ellipseIn: rect), with: color)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Fond commun a tous les ecrans : noir vrai, trame de points par-dessus.
struct InkBackground: View {
    var body: some View {
        ZStack {
            Ink.canvas
            DotField()
        }
        .ignoresSafeArea()
    }
}
