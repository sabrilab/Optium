import Metal
import MetalKit
import UIKit
import simd

/// Rend le cerveau hors écran et l'écrit pour les widgets.
///
/// **WidgetKit n'exécute pas Metal** : une extension widget n'a pas de
/// contexte graphique et ne rend qu'une image fixe. La capture doit donc être
/// produite par l'application, déposée dans le conteneur du groupe, et
/// seulement affichée par l'extension.
///
/// Fond transparent : le widget dessine le sien, ce qui évite d'avoir à
/// produire une variante claire et une variante sombre.
///
/// Écrite en fichier et non dans `UserDefaults` : celui-ci n'est pas fait pour
/// des binaires, et `WidgetSnapshot` y écrit déjà du JSON qu'il ne faut pas
/// alourdir.
enum BrainSnapshot {
    /// 158 pt à ×3. Le cerveau occupe un carré dans les deux familles
    /// concernées, une seule source suffit donc.
    ///
    /// **Le budget mémoire d'une extension widget est étroit** — de l'ordre de
    /// 30 Mo, dépassement égale terminaison. Une image de 474 px décodée pèse
    /// environ 900 Ko : la marge est confortable, mais elle interdit de monter
    /// en résolution « pour voir ».
    static let side = 474

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.group)?
            .appendingPathComponent("brain.png")
    }

    /// - Returns: le remplissage gravé dans l'image, ou `nil` si rien n'a été
    ///   produit. Sans mesure on n'écrit pas : à l'arrivée, le widget montre
    ///   la silhouette vide.
    @discardableResult
    static func render(fill: Double, base: Double, isDay: Bool) -> Double? {
        guard fill > 0,
              let url = fileURL,
              let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let mesh = try? BrainMesh.loadFromBundle()
        else { return nil }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: side, height: side, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let target = device.makeTexture(descriptor: descriptor) else { return nil }

        guard let pipelines = pipelines(device: device, library: library) else { return nil }
        guard let buffers = buffers(device: device, mesh: mesh) else { return nil }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)

        guard let command = queue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return nil }

        var uniforms = self.uniforms(mesh: mesh, fill: fill, base: base, isDay: isDay)
        encoder.setVertexBuffer(buffers.positions, offset: 0, index: 0)
        encoder.setVertexBuffer(buffers.normals, offset: 0, index: 2)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<BrainRenderer.Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<BrainRenderer.Uniforms>.stride, index: 1)

        // Le fluide d'abord, la coque par-dessus — le même ordre qu'à l'écran,
        // sans quoi les deux représentations divergeraient.
        encoder.setRenderPipelineState(pipelines.fluid)
        encoder.setCullMode(.none)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: mesh.indices.count,
                                      indexType: .uint32, indexBuffer: buffers.indices, indexBufferOffset: 0)
        encoder.setRenderPipelineState(pipelines.shell)
        encoder.setCullMode(.back)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: mesh.indices.count,
                                      indexType: .uint32, indexBuffer: buffers.indices, indexBufferOffset: 0)
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()

        guard let data = png(from: target) else { return nil }
        try? data.write(to: url, options: .atomic)
        return fill
    }

    // ── Détails ──

    private static func uniforms(mesh: BrainMesh, fill: Double, base: Double, isDay: Bool)
        -> BrainRenderer.Uniforms {
        let model = matrix_identity_float4x4
        let view = translation(0, 0, -5.0)
        let projection = perspective(fovRadians: 40 * .pi / 180, aspect: 1, near: 0.1, far: 100)
        let modelView = view * model
        let normal = float3x3(
            SIMD3(modelView.columns.0.x, modelView.columns.0.y, modelView.columns.0.z),
            SIMD3(modelView.columns.1.x, modelView.columns.1.y, modelView.columns.1.z),
            SIMD3(modelView.columns.2.x, modelView.columns.2.y, modelView.columns.2.z)
        )
        let day = (SIMD3<Float>(0.322, 0.325, 0.941), SIMD3<Float>(0.510, 0.455, 1.000))
        let night = (SIMD3<Float>(0.149, 0.255, 0.561), SIMD3<Float>(0.306, 0.353, 0.745))
        let colors = isDay ? day : night

        return BrainRenderer.Uniforms(
            modelViewProjection: projection * modelView,
            modelView: modelView,
            normalMatrix: normal,
            boundsMin: mesh.boundsMin,
            boundsMax: mesh.boundsMax,
            colorA: colors.0,
            colorB: colors.1,
            fillLevel: Float(min(fill, base) * 0.8),
            baseLevel: Float(base * 0.8),
            agitation: 0,
            // Instant fixe : la même entrée doit toujours donner la même image.
            time: 0,
            wobble: 0
        )
    }

    private static func pipelines(device: MTLDevice, library: MTLLibrary)
        -> (fluid: MTLRenderPipelineState, shell: MTLRenderPipelineState)? {
        let vertex = MTLVertexDescriptor()
        vertex.attributes[0].format = .float3
        vertex.attributes[0].bufferIndex = 0
        vertex.attributes[1].format = .float3
        vertex.attributes[1].bufferIndex = 2
        vertex.layouts[0].stride = MemoryLayout<Float>.size * 3
        vertex.layouts[2].stride = MemoryLayout<Float>.size * 3

        func make(_ v: String, _ f: String) -> MTLRenderPipelineState? {
            let pipe = MTLRenderPipelineDescriptor()
            pipe.vertexFunction = library.makeFunction(name: v)
            pipe.fragmentFunction = library.makeFunction(name: f)
            pipe.vertexDescriptor = vertex
            pipe.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipe.colorAttachments[0].isBlendingEnabled = true
            pipe.colorAttachments[0].rgbBlendOperation = .add
            pipe.colorAttachments[0].alphaBlendOperation = .add
            pipe.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipe.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipe.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipe.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try? device.makeRenderPipelineState(descriptor: pipe)
        }
        guard let fluid = make("fluid_vertex", "fluid_fragment"),
              let shell = make("shell_vertex", "shell_fragment") else { return nil }
        return (fluid, shell)
    }

    private static func buffers(device: MTLDevice, mesh: BrainMesh)
        -> (positions: MTLBuffer, normals: MTLBuffer, indices: MTLBuffer)? {
        guard let positions = device.makeBuffer(bytes: mesh.positions,
                                                length: mesh.positions.count * MemoryLayout<Float>.size),
              let normals = device.makeBuffer(bytes: mesh.normals,
                                              length: mesh.normals.count * MemoryLayout<Float>.size),
              let indices = device.makeBuffer(bytes: mesh.indices,
                                              length: mesh.indices.count * MemoryLayout<UInt32>.size)
        else { return nil }
        return (positions, normals, indices)
    }

    private static func png(from texture: MTLTexture) -> Data? {
        let bytesPerRow = texture.width * 4
        var raw = [UInt8](repeating: 0, count: bytesPerRow * texture.height)
        texture.getBytes(&raw, bytesPerRow: bytesPerRow,
                         from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)

        guard let provider = CGDataProvider(data: Data(raw) as CFData),
              let image = CGImage(
                width: texture.width, height: texture.height,
                bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                // Metal rend en BGRA prémultiplié ; l'ordre des octets doit
                // être annoncé, sinon les canaux ressortent inversés.
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                                                 | CGBitmapInfo.byteOrder32Little.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }

        return UIImage(cgImage: image).pngData()
    }
}

// ── Matrices, identiques à celles du rendu écran ──

private func translation(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
    var m = matrix_identity_float4x4
    m.columns.3 = SIMD4(x, y, z, 1)
    return m
}

private func perspective(fovRadians: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
    let y = 1 / tan(fovRadians * 0.5)
    let x = y / aspect
    let z = far / (near - far)
    return float4x4(SIMD4(x, 0, 0, 0), SIMD4(0, y, 0, 0), SIMD4(0, 0, z, -1), SIMD4(0, 0, z * near, 0))
}
