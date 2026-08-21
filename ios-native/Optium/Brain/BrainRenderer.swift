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
    private struct Uniforms {
        var modelViewProjection: float4x4
        var modelView: float4x4
        var normalMatrix: float3x3
        var boundsMin: SIMD3<Float>
        var boundsMax: SIMD3<Float>
        var colorA: SIMD3<Float>
        var colorB: SIMD3<Float>
        var fillLevel: Float
        var time: Float
        var wobble: Float
    }

    /// Le fluide ne remplit jamais entierement la coque : un cerveau plein a ras
    /// bord se lit moins bien qu'un niveau qui laisse voir le verre.
    private static let maxFill: Float = 0.8

    private static let focusColorA = SIMD3<Float>(0.290, 0.565, 0.851)  // #4A90D9
    private static let focusColorB = SIMD3<Float>(0.424, 0.361, 0.906)  // #6C5CE7
    private static let restColorA  = SIMD3<Float>(0.180, 0.800, 0.443)  // #2ECC71
    private static let restColorB  = SIMD3<Float>(0.153, 0.682, 0.376)  // #27AE60

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
    private var fillLevel: Float = BrainRenderer.maxFill
    private var colorA = BrainRenderer.focusColorA
    private var colorB = BrainRenderer.focusColorB
    private var rotation: Float = 0
    private var elapsed: Float = 0
    private var wobble: Float = 0
    private var aspect: Float = 1

    /// Vitesse imprimee par le geste de rotation, decroissante.
    var dragVelocity: Float = 0
    /// Progression restante de la session, 0…1, poussee par la vue.
    var progress: Float = 1
    /// Vrai en concentration, faux en repos.
    var isFocus = true

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

        // En concentration, le fluide se vide au fil de la session ; en repos,
        // il se remplit. Le niveau glisse vers sa cible plutot que d'y sauter.
        let target = (isFocus ? progress : 1 - progress) * Self.maxFill
        fillLevel += (target - fillLevel) * 0.05

        wobble = min(1, wobble * 0.95 + abs(dragVelocity) * 0.6)
        dragVelocity *= 0.9

        colorA = lerp(colorA, isFocus ? Self.focusColorA : Self.restColorA, t: 0.02)
        colorB = lerp(colorB, isFocus ? Self.focusColorB : Self.restColorB, t: 0.02)

        rotation += delta * 0.3 + dragVelocity
        // Leger flottement vertical et roulis, pour que la scene ne paraisse
        // jamais figee.
        let bob = sin(elapsed * 1.0) * 0.06
        let tilt = sin(elapsed * 0.6) * 0.04

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
        let view = translation(0, 0, -5.5)
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
