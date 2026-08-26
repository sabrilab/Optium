import MetalKit
import SwiftUI

struct BrainView: UIViewRepresentable {
    /// Niveau vise du fluide, 0…1 : la clarte.
    let fill: Double
    /// Plafond permis par la nuit, 0…1.
    var base: Double = 1
    /// Nombre de fils ouverts, normalise 0…1.
    var agitation: Double = 0
    var isDay: Bool = true
    /// -1…1 : le sens de variation de la clarte. **Jamais son niveau.**
    ///
    /// Ca remonte → la teinte derive vers le repos, turquoise. Au sommet et en
    /// descente → vers l'effort, indigo. C'est une derive continue, jamais un
    /// interrupteur : le signe seul ferait clignoter la scene a chaque passage
    /// par zero.
    var slope: Double = 0
    /// 0…1 : la scene travaille — lecture des nuits, appel au modele.
    var effort: Double = 0
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
        context.coordinator.renderer?.fill = Float(fill)
        context.coordinator.renderer?.base = Float(base)
        context.coordinator.renderer?.agitation = Float(agitation)
        context.coordinator.renderer?.isDay = isDay
        context.coordinator.renderer?.slope = Float(slope)
        context.coordinator.renderer?.effort = Float(effort)
        view.isPaused = !isVisible
    }

    final class Coordinator {
        var renderer: BrainRenderer?

        private var lastTranslation: CGFloat = 0

        @MainActor
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let velocity = gesture.velocity(in: gesture.view).x
            renderer?.dragVelocity = Float(velocity) / 12_000

            switch gesture.state {
            case .began:
                lastTranslation = 0
                Feedback.prepare()
            case .changed:
                // La scene tourne sous le doigt : elle doit se sentir. C'est
                // le seul objet manipulable de l'application, et le seul
                // endroit ou le retour dit une matiere plutot qu'un evenement.
                let translation = gesture.translation(in: gesture.view).x
                let delta = translation - lastTranslation
                lastTranslation = translation
                Feedback.brainTurned(
                    by: Double(delta) / 90,
                    speed: min(1, abs(Double(velocity)) / 2_400)
                )
            default:
                break
            }
        }
    }
}
