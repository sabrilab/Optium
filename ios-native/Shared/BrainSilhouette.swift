import SwiftUI

/// La silhouette du cerveau, en deux dimensions.
///
/// Extraite du maillage 3D reel : projection laterale sur (x, y) — l'axe long du modele,
/// donc l'axe avant-arriere ; projeter sur (z, y) donnait la vue de face, qui
/// est un blob a tige rasterisee, fermeture
/// morphologique, puis tracage de contour de Moore et simplification. Un
/// balayage radial avait ete essaye d'abord — il donnait l'enveloppe convexe
/// et effacait l'echancrure du cervelet, ce qui faisait lire un ballon : les deux representations doivent etre le
/// meme objet, sans quoi le widget et l'ecran de session montreraient deux
/// cerveaux differents.
///
/// Elle existe parce que Metal ne tourne pas dans un widget : ceux-ci ne
/// rendent qu'une image fixe, dans un processus qui n'a pas de contexte
/// graphique. Elle sert aussi a la Live Activity et aux tres petites tailles,
/// ou la scene 3D serait illisible.
///
/// 59 points, normalises dans un carre unite.
enum BrainSilhouette {
    static let points: [CGPoint] = [
        CGPoint(x: 0.3549, y: 0.9800), CGPoint(x: 0.4174, y: 0.9800), CGPoint(x: 0.4397, y: 0.9086),
        CGPoint(x: 0.4487, y: 0.9041), CGPoint(x: 0.4487, y: 0.8862), CGPoint(x: 0.4665, y: 0.8684),
        CGPoint(x: 0.4710, y: 0.8460), CGPoint(x: 0.4933, y: 0.8193), CGPoint(x: 0.4978, y: 0.8014),
        CGPoint(x: 0.5112, y: 0.7969), CGPoint(x: 0.5112, y: 0.7835), CGPoint(x: 0.5335, y: 0.7657),
        CGPoint(x: 0.5558, y: 0.7166), CGPoint(x: 0.6674, y: 0.7255), CGPoint(x: 0.7433, y: 0.6898),
        CGPoint(x: 0.7791, y: 0.6585), CGPoint(x: 0.8014, y: 0.5826), CGPoint(x: 0.8728, y: 0.5781),
        CGPoint(x: 0.9353, y: 0.5380), CGPoint(x: 0.9353, y: 0.5246), CGPoint(x: 0.9487, y: 0.5201),
        CGPoint(x: 0.9532, y: 0.5022), CGPoint(x: 0.9621, y: 0.4978), CGPoint(x: 0.9666, y: 0.4531),
        CGPoint(x: 0.9800, y: 0.4353), CGPoint(x: 0.9800, y: 0.2834), CGPoint(x: 0.9532, y: 0.2165),
        CGPoint(x: 0.9309, y: 0.1986), CGPoint(x: 0.8996, y: 0.1450), CGPoint(x: 0.8728, y: 0.1182),
        CGPoint(x: 0.8148, y: 0.0914), CGPoint(x: 0.7701, y: 0.0513), CGPoint(x: 0.7032, y: 0.0289),
        CGPoint(x: 0.6451, y: 0.0200), CGPoint(x: 0.4308, y: 0.0200), CGPoint(x: 0.4174, y: 0.0289),
        CGPoint(x: 0.3727, y: 0.0289), CGPoint(x: 0.2834, y: 0.0602), CGPoint(x: 0.1941, y: 0.1182),
        CGPoint(x: 0.1763, y: 0.1495), CGPoint(x: 0.1540, y: 0.1673), CGPoint(x: 0.1450, y: 0.1986),
        CGPoint(x: 0.1004, y: 0.2343), CGPoint(x: 0.0825, y: 0.2745), CGPoint(x: 0.0780, y: 0.3192),
        CGPoint(x: 0.0513, y: 0.3415), CGPoint(x: 0.0379, y: 0.3951), CGPoint(x: 0.0200, y: 0.4219),
        CGPoint(x: 0.0200, y: 0.6630), CGPoint(x: 0.0736, y: 0.7433), CGPoint(x: 0.1361, y: 0.7478),
        CGPoint(x: 0.1450, y: 0.8014), CGPoint(x: 0.1673, y: 0.8371), CGPoint(x: 0.1986, y: 0.8639),
        CGPoint(x: 0.2433, y: 0.8773), CGPoint(x: 0.3058, y: 0.8728), CGPoint(x: 0.3638, y: 0.8818),
        CGPoint(x: 0.3683, y: 0.9309), CGPoint(x: 0.3549, y: 0.9755)
    ]

    /// Le contour, ferme, mis a l'echelle du rectangle donne.
    static func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaled = points.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        guard let first = scaled.first else { return path }

        // Courbes de Catmull-Rom converties en Bezier : relier les points par
        // des segments droits ferait apparaitre chaque sommet du contour.
        path.move(to: first)
        for index in 0..<scaled.count {
            let p0 = scaled[(index - 1 + scaled.count) % scaled.count]
            let p1 = scaled[index]
            let p2 = scaled[(index + 1) % scaled.count]
            let p3 = scaled[(index + 2) % scaled.count]
            path.addCurve(
                to: p2,
                control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            )
        }
        path.closeSubpath()
        return path
    }
}

/// Le cerveau en petit : contour, fluide, ligne de base.
///
/// **Variante obligatoire en dessous de 40 points de large** — ile dynamique,
/// widgets, complication. Le contour y est renforce et les sillons comme la
/// ligne de base disparaissent : sans cela le cerveau se lit comme un bol uni.
struct BrainSilhouetteView: View {
    /// 0…1
    var fill: Double
    /// 0…1, le plafond permis par la nuit. Ignore en petite taille.
    var base: Double = 1
    var tint: Color = Ink.focusGlow
    var showsBase = true

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            let shape = BrainSilhouette.path(in: rect)
            let small = proxy.size.width < 40

            ZStack {
                shape.fill(tint.opacity(0.10))

                // Le fluide est le contour clippe a la hauteur du niveau.
                shape
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.55)],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: proxy.size.height * fill)
                    }

                if showsBase && !small {
                    shape
                        .fill(Color.white.opacity(0.55))
                        .mask(alignment: .bottom) {
                            Rectangle()
                                .frame(height: 1.2)
                                .offset(y: -proxy.size.height * base)
                        }
                }

                shape.stroke(
                    Color.white.opacity(small ? 0.62 : 0.38),
                    lineWidth: small ? 1.6 : 1.0
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    ZStack {
        Color.black
        HStack(spacing: 20) {
            BrainSilhouetteView(fill: 0.7, base: 0.85)
                .frame(width: 120, height: 120)
            BrainSilhouetteView(fill: 0.4)
                .frame(width: 34, height: 34)
        }
    }
}
