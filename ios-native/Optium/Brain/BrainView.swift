import MetalKit
import SwiftUI

struct BrainView: UIViewRepresentable {
    /// Progression restante de la session, 0…1.
    let progress: Double
    let isFocus: Bool
    /// Le rendu est totalement suspendu quand la scene n'est pas visible :
    /// sans cela, la boucle continuerait a 60 images par seconde et viderait
    /// la batterie pendant qu'on consulte ses statistiques.
    let isVisible: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.isOpaque = false
        view.backgroundColor = .clear
        // Sans cela la passe de rendu efface vers un noir opaque, et la
        // scene apparait comme un rectangle noir au lieu de se fondre
        // dans le fond de l'application.
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 60
        // Les ecrans d'iPhone sont en densite 3. Rendre a cette densite triple
        // le nombre de fragments pour un gain invisible sur un contenu aussi
        // diffus : on plafonne a 2.
        view.contentScaleFactor = min(view.traitCollection.displayScale, 2)

        guard let mesh = try? BrainMesh.loadFromBundle(),
              let renderer = BrainRenderer(view: view, mesh: mesh) else {
            // Sans maillage ni GPU, la vue reste transparente : l'ecran Session
            // demeure parfaitement utilisable sans sa decoration.
            return view
        }

        context.coordinator.renderer = renderer
        view.delegate = renderer

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.renderer?.progress = Float(progress)
        context.coordinator.renderer?.isFocus = isFocus
        view.isPaused = !isVisible
    }

    final class Coordinator {
        var renderer: BrainRenderer?

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let velocity = gesture.velocity(in: gesture.view).x
            renderer?.dragVelocity = Float(velocity) / 12_000
        }
    }
}
