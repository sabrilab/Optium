import SwiftUI

/// Chiffres dessines en matrice de points, facon afficheur a diodes.
///
/// Dessines plutot que composes avec une police : cela evite d'embarquer une
/// fonte, et surtout cela donne la main sur la grille elle-meme — les points
/// eteints restent faiblement visibles, ce qui est exactement ce qui fait lire
/// « afficheur » plutot que « police pointilliste ».
struct DotMatrixText: View {
    let text: String
    var dot: CGFloat = 7
    var gap: CGFloat = 4
    var color: Color = .primary
    /// Luminosite des points eteints. Les garder visibles dessine la grille.
    var dimOpacity: Double = 0.09
    /// Halo des points allumes, comme la diffusion d'une vraie diode.
    var glow: Color?

    private static let rows = 7

    private var glyphs: [[String]] { text.map { Self.glyph(for: $0) } }

    /// Espace entre deux glyphes, un cran de grille complet.
    private var advance: CGFloat { dot + gap }

    private func width(of glyph: [String]) -> CGFloat {
        let columns = CGFloat(glyph[0].count)
        return columns * dot + (columns - 1) * gap
    }

    private var totalWidth: CGFloat {
        let glyphWidths = glyphs.reduce(0) { $0 + width(of: $1) }
        return glyphWidths + CGFloat(max(0, glyphs.count - 1)) * advance
    }

    private var totalHeight: CGFloat {
        CGFloat(Self.rows) * dot + CGFloat(Self.rows - 1) * gap
    }

    var body: some View {
        Canvas { context, _ in
            var origin: CGFloat = 0
            for glyph in glyphs {
                for (row, line) in glyph.enumerated() {
                    for (column, character) in line.enumerated() {
                        let rect = CGRect(
                            x: origin + CGFloat(column) * advance,
                            y: CGFloat(row) * advance,
                            width: dot,
                            height: dot
                        )
                        let path = Path(ellipseIn: rect)
                        if character == "1" {
                            context.fill(path, with: .color(color))
                        } else {
                            context.fill(path, with: .color(color.opacity(dimOpacity)))
                        }
                    }
                }
                origin += width(of: glyph) + advance
            }
        }
        .frame(width: totalWidth, height: totalHeight)
        .shadow(color: (glow ?? color).opacity(glow == nil ? 0 : 0.55), radius: dot * 0.9)
        .accessibilityHidden(true)
    }

    // ── Glyphes 5×7, plus un deux-points de deux colonnes ──

    private static func glyph(for character: Character) -> [String] {
        switch character {
        case "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"]
        case "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"]
        case "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"]
        case "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"]
        case "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"]
        case "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"]
        case "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"]
        case "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"]
        case "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"]
        case "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"]
        case ":": ["00", "00", "11", "00", "11", "00", "00"]
        default:  ["00000", "00000", "00000", "00000", "00000", "00000", "00000"]
        }
    }
}

#Preview {
    ZStack {
        Color.black
        DotMatrixText(text: "25:00", glow: .white)
    }
}
