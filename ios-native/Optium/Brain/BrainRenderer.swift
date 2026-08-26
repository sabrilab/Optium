import MetalKit
import simd

/// Rendu de la scene.
///
/// Le renderer lit l'etat du minuteur **sans s'y abonner** : celui-ci change
/// chaque seconde, et un abonnement provoquerait une reevaluation de vue a
/// chaque fois alors que seule une valeur uniforme doit bouger.
final class BrainRenderer: NSObject, MTKViewDelegate {

    /// Attention : cette structure est declaree deux fois, ici et dans
    /// Shaders.metal. Rien ne verifie a la compilation qu'elles concordent.
    /// Ne pas reordonner les champs d'un cote sans l'autre.
    struct Uniforms {
        var modelViewProjection: float4x4
        var modelView: float4x4
        var normalMatrix: float3x3
        var boundsMin: SIMD3<Float>
        var boundsMax: SIMD3<Float>
        var colorA: SIMD3<Float>
        var colorB: SIMD3<Float>
        var fillLevel: Float
        var baseLevel: Float
        var agitation: Float
        var time: Float
        var wobble: Float
    }

    /// Le fluide ne remplit jamais entierement la coque : un cerveau plein a ras
    /// bord se lit moins bien qu'un niveau qui laisse voir le verre.
    /// La plage occupee par le fluide dans la silhouette.
    ///
    /// **Elle ne part plus de zero, et c'est une correction.** La clarte etait
    /// mappee sur 0…0,8 : une journee en clarte basse laissait donc le liquide
    /// dans le tronc cerebral, la partie la plus fine du maillage, ou une
    /// variation de hauteur ne change presque aucun pixel. Le mouvement de la
    /// journee y etait invisible — precisement chez ceux a qui il sert le
    /// plus.
    ///
    /// Un plancher a 0,30 garde le fluide dans la partie large. **Ce n'est pas
    /// un mensonge** : la transformation est affine et monotone, donc l'ordre
    /// est integralement preserve — une mauvaise nuit reste visiblement plus
    /// basse qu'une bonne. C'est le choix d'un thermometre dont l'echelle ne
    /// commence pas au zero absolu.
    private static let fillFloor: Float = 0.30
    private static let fillTop: Float = 0.96
    private static let maxFill: Float = 0.96

    /// De combien l'ecart a la moyenne du jour est exagere.
    ///
    /// **L'amplification porte sur la variation, jamais sur la position.** La
    /// moyenne du jour reste tracee fidelement — c'est elle qui distingue les
    /// nuits — et seul l'ecart a elle est double. Sans ca, une journee entiere
    /// tient dans 56 points de hauteur et le glissement au doigt ne montre
    /// presque rien.
    ///
    /// Mesure : 56 points de course en clarte basse avant, 74 apres, et les
    /// quatre qualites de nuit restent separees de 30 points au moins.
    private static let dayGain: Float = 2.0

    // Deux familles seulement : le jour et la nuit. Jamais trois.
    private static let dayColorA   = SIMD3<Float>(0.322, 0.325, 0.941)
    private static let dayColorB   = SIMD3<Float>(0.510, 0.455, 1.000)

    /// La teinte de recuperation : le turquoise de `Ink.restGlow`.
    ///
    /// **Elle porte un sens de variation, jamais un niveau.** Monter ou
    /// descendre n'est pas etre bon ou mauvais — la teinte a donc le droit de
    /// le dire, la ou encoder la clarte en couleur ferait du verdict
    /// l'evenement visuel dominant.
    ///
    /// Elle ne derive **jamais vers le lime** `#D6E85D`, reserve au present.
    private static let restColorA  = SIMD3<Float>(0.086, 0.647, 0.588)
    private static let restColorB  = SIMD3<Float>(0.247, 0.839, 0.690)
    private static let nightColorA = SIMD3<Float>(0.149, 0.255, 0.561)
    private static let nightColorB = SIMD3<Float>(0.306, 0.353, 0.745)

    private let queue: MTLCommandQueue
    private let fluidPipeline: MTLRenderPipelineState
    private let shellPipeline: MTLRenderPipelineState
    private let positionBuffer: MTLBuffer
    private let normalBuffer: MTLBuffer
    private let indexBuffer: MTLBuffer
    private let indexCount: Int
    private let boundsMin: SIMD3<Float>
    private let boundsMax: SIMD3<Float>

    /// Etat anime, entretenu image par image.
    private var fillLevel: Float = 0
    private var baseLevel: Float = BrainRenderer.maxFill
    private var colorA = BrainRenderer.dayColorA
    private var colorB = BrainRenderer.dayColorB
    private var rotation: Float = 0
    /// Suit `effort` avec retard : un basculement instantane du regime se
    /// verrait comme un a-coup.
    private var effortLevel: Float = 0
    private var elapsed: Float = 0

    /// Le lancer de l'arrivee : vitesse initiale, en tours par seconde
    /// au-dessus du regime de repos, et constante de deceleration.
    ///
    /// Deux secondes et demie pour retomber au tiers de l'elan : assez long
    /// pour que le ralentissement se sente, assez court pour ne pas retarder
    /// la lecture de la scene.
    private static let launchSpeed: Float = 3.4
    private static let launchDecay: Float = 2.5
    private var wobble: Float = 0
    private var aspect: Float = 1

    /// Vitesse imprimee par le geste de rotation, decroissante.
    var dragVelocity: Float = 0
    /// Niveau vise du fluide, 0…1 : la clarte.
    var fill: Float = 0.8
    /// Plafond permis par la nuit, 0…1. Le fluide ne monte jamais au-dessus.
    var base: Float = 1
    /// Nombre de fils ouverts, normalise 0…1. Deforme la surface.
    var agitation: Float = 0
    /// Vrai le jour, faux la nuit. Deux familles de teintes, jamais trois.
    var isDay = true

    /// -1…1 : le sens de variation de la clarte.
    var slope: Float = 0
    private var slopeLevel: Float = 0

    /// La clarte moyenne de la journee, 0…1. Ancre de l'amplification.
    var dayMean: Float = 0.5

    /// 0…1 : la scene est-elle en train de travailler.
    ///
    /// **Une application qui lit des donnees doit se voir lire.** Sans etat de
    /// chargement, une lecture instantanee et une lecture qui echoue se
    /// ressemblent, et l'utilisateur ne sait jamais si quelque chose est en
    /// cours. Ici c'est le cerveau qui le porte : il accelere, il s'agite un
    /// peu, il respire plus vite. Rien de nouveau n'apparait a l'ecran — c'est
    /// le meme objet, dans un autre regime.
    var effort: Float = 0

    init?(view: MTKView, mesh: BrainMesh) {
        guard let device = view.device ?? MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else { return nil }

        self.queue = queue
        self.indexCount = mesh.indices.count
        self.boundsMin = mesh.boundsMin
        self.boundsMax = mesh.boundsMax

        guard let positionBuffer = device.makeBuffer(
                bytes: mesh.positions,
                length: mesh.positions.count * MemoryLayout<Float>.size),
              let normalBuffer = device.makeBuffer(
                bytes: mesh.normals,
                length: mesh.normals.count * MemoryLayout<Float>.size),
              let indexBuffer = device.makeBuffer(
                bytes: mesh.indices,
                length: mesh.indices.count * MemoryLayout<UInt32>.size)
        else { return nil }

        self.positionBuffer = positionBuffer
        self.normalBuffer = normalBuffer
        self.indexBuffer = indexBuffer

        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].bufferIndex = 0
        descriptor.attributes[0].offset = 0
        descriptor.attributes[1].format = .float3
        descriptor.attributes[1].bufferIndex = 2
        descriptor.attributes[1].offset = 0
        descriptor.layouts[0].stride = MemoryLayout<Float>.size * 3
        descriptor.layouts[2].stride = MemoryLayout<Float>.size * 3

        func pipeline(_ vertexName: String, _ fragmentName: String) -> MTLRenderPipelineState? {
            let pipe = MTLRenderPipelineDescriptor()
            pipe.vertexFunction = library.makeFunction(name: vertexName)
            pipe.fragmentFunction = library.makeFunction(name: fragmentName)
            pipe.vertexDescriptor = descriptor
            pipe.colorAttachments[0].pixelFormat = view.colorPixelFormat
            pipe.colorAttachments[0].isBlendingEnabled = true
            pipe.colorAttachments[0].rgbBlendOperation = .add
            pipe.colorAttachments[0].alphaBlendOperation = .add
            pipe.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipe.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipe.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipe.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try? device.makeRenderPipelineState(descriptor: pipe)
        }

        guard let fluid = pipeline("fluid_vertex", "fluid_fragment"),
              let shell = pipeline("shell_vertex", "shell_fragment") else { return nil }

        self.fluidPipeline = fluid
        self.shellPipeline = shell
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspect = size.height == 0 ? 1 : Float(size.width / size.height)
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let buffer = queue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        let delta: Float = 1.0 / Float(max(1, view.preferredFramesPerSecond))
        elapsed += delta

        // Le niveau ne saute jamais : toute variation s'interpole. A 60 images
        // par seconde, 0.037 par image donne environ 900 ms pour couvrir
        // l'ecart — la duree prescrite par la specification de mouvement.
        // L'ecart a la moyenne du jour est exagere, la moyenne ne l'est pas.
        let raw = min(fill, base)
        let amplified = dayMean + Self.dayGain * (raw - dayMean)
        let target = Self.fillFloor + max(0, min(1, amplified)) * (Self.fillTop - Self.fillFloor)
        fillLevel += (target - fillLevel) * 0.037
        baseLevel += (base * Self.maxFill - baseLevel) * 0.09

        // L'agitation du fluide monte aussi a l'effort : le liquide bouge
        // quand la scene travaille, ce qui est le signal le plus lisible.
        wobble = min(1, wobble * 0.95 + abs(dragVelocity) * 0.6 + effortLevel * 0.06)
        dragVelocity *= 0.9

        // La teinte croise a l'extinction, une seule fois par jour : 2,4 s.
        //
        // **Et elle derive avec la pente.** Une clarte qui remonte tire vers
        // le turquoise du repos, un sommet ou une descente vers l'indigo de
        // l'effort. Le taux, jamais le signe : mapper sur le signe ferait
        // clignoter la scene a chaque passage par zero — c'est-a-dire au
        // sommet et au creux, les deux moments qui comptent.
        //
        // La derive est lente (0,007 par image, soit 2,4 s) et donc
        // imperceptible en mouvement : la teinte se voit quand on regarde,
        // elle ne reclame jamais le regard.
        slopeLevel += (slope - slopeLevel) * 0.02
        let recovering = max(0, min(1, slopeLevel)) * 0.55

        let baseA = isDay ? Self.dayColorA : Self.nightColorA
        let baseB = isDay ? Self.dayColorB : Self.nightColorB
        colorA = lerp(colorA, lerp(baseA, Self.restColorA, t: recovering), t: 0.007)
        colorB = lerp(colorB, lerp(baseB, Self.restColorB, t: recovering), t: 0.007)

        effortLevel += (effort - effortLevel) * 0.05

        // **L'arrivee est un lancer, pas un rebond.**
        //
        // La scene entrait en flottant : le cerveau montait et descendait sur
        // place, ce qui se lit comme un objet suspendu qui ballotte. Il tourne
        // desormais vite au premier instant puis decelere, comme une piece
        // qu'on lance et qui trouve son regime. La decroissance est
        // exponentielle : rapide au debut, de plus en plus douce, sans jamais
        // s'arreter net.
        //
        // Elle ne se rejoue pas : `elapsed` repart de zero a chaque creation
        // du rendu, donc a chaque arrivee sur l'ecran, et jamais pendant qu'on
        // y est.
        let launch = Self.launchSpeed * exp(-elapsed / Self.launchDecay)

        // **La rotation de repos etait trop lente pour se voir.** A 0,3 radian
        // par seconde, il faut vingt secondes pour un tour : l'oeil lit un
        // objet fixe. A 0,52, le mouvement se percoit sans distraire, et il
        // double quand la scene travaille.
        rotation += delta * (0.52 + effortLevel * 0.55 + launch) + dragVelocity

        // Roulis lent, pour que la scene ne paraisse jamais figee. Il
        // s'amplifie a l'effort.
        //
        // **Le flottement vertical a ete retire.** Un objet qui monte et
        // descend sur place se lit comme suspendu et ballottant ; la rotation
        // seule suffit a le garder vivant, et elle dit quelque chose — la
        // vitesse porte l'effort.
        let breath = 1 + effortLevel * 0.9
        let bob: Float = 0
        let tilt = sin(elapsed * 0.6) * 0.035 * breath

        var uniforms = makeUniforms(rotation: rotation, bob: bob, tilt: tilt)

        encoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(normalBuffer, offset: 0, index: 2)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

        // Le fluide d'abord, la coque par dessus : le verre doit se composer
        // sur le liquide. Aucun des deux n'ecrit dans le tampon de profondeur.
        encoder.setRenderPipelineState(fluidPipeline)
        encoder.setCullMode(.none)
        encoder.drawIndexedPrimitives(
            type: .triangle, indexCount: indexCount,
            indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0
        )

        encoder.setRenderPipelineState(shellPipeline)
        // Face avant uniquement : moitie moins de fragments, pour une
        // difference invisible sur une coque translucide.
        encoder.setCullMode(.back)
        encoder.drawIndexedPrimitives(
            type: .triangle, indexCount: indexCount,
            indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0
        )

        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }

    private func makeUniforms(rotation: Float, bob: Float, tilt: Float) -> Uniforms {
        let model = translation(0, bob, 0) * rotationY(rotation) * rotationX(tilt)
        let view = translation(0, 0, -5.0)
        let projection = perspective(fovRadians: 40 * .pi / 180, aspect: aspect, near: 0.1, far: 100)

        let modelView = view * model
        let normal = float3x3(
            SIMD3(modelView.columns.0.x, modelView.columns.0.y, modelView.columns.0.z),
            SIMD3(modelView.columns.1.x, modelView.columns.1.y, modelView.columns.1.z),
            SIMD3(modelView.columns.2.x, modelView.columns.2.y, modelView.columns.2.z)
        )

        return Uniforms(
            modelViewProjection: projection * modelView,
            modelView: modelView,
            normalMatrix: normal,
            boundsMin: boundsMin,
            boundsMax: boundsMax,
            colorA: colorA,
            colorB: colorB,
            fillLevel: fillLevel,
            baseLevel: baseLevel,
            agitation: agitation,
            time: elapsed,
            wobble: wobble
        )
    }

    private func lerp(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        a + (b - a) * t
    }
}

// ── Matrices ──

private func translation(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
    var m = matrix_identity_float4x4
    m.columns.3 = SIMD4(x, y, z, 1)
    return m
}

private func rotationY(_ angle: Float) -> float4x4 {
    let c = cos(angle), s = sin(angle)
    return float4x4(
        SIMD4(c, 0, -s, 0), SIMD4(0, 1, 0, 0), SIMD4(s, 0, c, 0), SIMD4(0, 0, 0, 1)
    )
}

private func rotationX(_ angle: Float) -> float4x4 {
    let c = cos(angle), s = sin(angle)
    return float4x4(
        SIMD4(1, 0, 0, 0), SIMD4(0, c, s, 0), SIMD4(0, -s, c, 0), SIMD4(0, 0, 0, 1)
    )
}

private func perspective(fovRadians: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
    let y = 1 / tan(fovRadians * 0.5)
    let x = y / aspect
    let z = far / (near - far)
    return float4x4(
        SIMD4(x, 0, 0, 0), SIMD4(0, y, 0, 0), SIMD4(0, 0, z, -1), SIMD4(0, 0, z * near, 0)
    )
}
