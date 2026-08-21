import SwiftUI

/// Progression en graduations plutot qu'en barre pleine.
///
/// Une barre indique une proportion ; des graduations donnent une echelle, donc
/// une lecture du temps qui reste et pas seulement de la part accomplie.
struct TickScale: View {
    /// 0…1
    let progress: Double
    var tickCount: Int = 48
    var tint: Color = Ink.marker

    var body: some View {
        GeometryReader { proxy in
            let step = proxy.size.width / CGFloat(tickCount - 1)
            let head = CGFloat(min(1, max(0, progress))) * proxy.size.width

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(0..<tickCount, id: \.self) { index in
                        let position = CGFloat(index) * step
                        let passed = position <= head
                        // Une graduation plus haute tous les six crans : le
                        // regard a besoin de reperes pour lire une echelle.
                        let major = index % 6 == 0
                        Capsule()
                            .fill(passed ? tint.opacity(0.9) : Color.white.opacity(0.16))
                            .frame(width: 1.5, height: major ? 14 : 8)
                            .frame(width: step, alignment: .leading)
                    }
                }
                .frame(height: 14)

                // Repere de tete.
                Capsule()
                    .fill(tint)
                    .frame(width: 2.5, height: 20)
                    .shadow(color: tint.opacity(0.8), radius: 6)
                    .offset(x: head - 1.25)
            }
            .frame(height: 20)
        }
        .frame(height: 20)
    }
}
