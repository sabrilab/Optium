import Foundation
import simd

/// Maillage du cerveau, pre-calcule par `mobile/scripts/bake_brain.py`.
///
/// Le fichier est ecrit dans la disposition memoire que Metal attend : le
/// chargement se reduit a lire des octets, sans decodage ni recalcul au
/// demarrage. La coque et le fluide partagent cette geometrie unique et
/// tiennent chacun en un seul appel de dessin.
struct BrainMesh {
    let positions: [Float]
    let normals: [Float]
    let indices: [UInt32]
    let boundsMin: SIMD3<Float>
    let boundsMax: SIMD3<Float>

    enum LoadError: Error {
        case introuvable
        case signatureInvalide
        case versionInconnue(UInt32)
        case fichierTronque
    }

    private static let headerSize = 40

    static func load(from data: Data) throws -> BrainMesh {
        guard data.count >= headerSize else { throw LoadError.fichierTronque }
        guard data.prefix(4) == Data("OPTB".utf8) else { throw LoadError.signatureInvalide }

        let version: UInt32 = read(data, at: 4)
        guard version == 1 else { throw LoadError.versionInconnue(version) }

        let vertexCount = Int(read(data, at: 8) as UInt32)
        let indexCount = Int(read(data, at: 12) as UInt32)

        let floatCount = vertexCount * 3
        let expected = headerSize + (floatCount * 2) * 4 + indexCount * 4
        guard data.count >= expected else { throw LoadError.fichierTronque }

        let boundsMin = SIMD3<Float>(read(data, at: 16), read(data, at: 20), read(data, at: 24))
        let boundsMax = SIMD3<Float>(read(data, at: 28), read(data, at: 32), read(data, at: 36))

        var offset = headerSize
        let positions: [Float] = readArray(data, at: &offset, count: floatCount)
        let normals: [Float] = readArray(data, at: &offset, count: floatCount)
        let indices: [UInt32] = readArray(data, at: &offset, count: indexCount)

        return BrainMesh(
            positions: positions, normals: normals, indices: indices,
            boundsMin: boundsMin, boundsMax: boundsMax
        )
    }

    static func loadFromBundle() throws -> BrainMesh {
        guard let url = Bundle.main.url(forResource: "brain", withExtension: "bin") else {
            throw LoadError.introuvable
        }
        return try load(from: Data(contentsOf: url))
    }

    private static func read<T>(_ data: Data, at offset: Int) -> T {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
    }

    private static func readArray<T>(_ data: Data, at offset: inout Int, count: Int) -> [T] {
        let size = MemoryLayout<T>.size
        let start = offset
        offset += count * size
        return data.withUnsafeBytes { raw in
            (0..<count).map { raw.loadUnaligned(fromByteOffset: start + $0 * size, as: T.self) }
        }
    }
}
