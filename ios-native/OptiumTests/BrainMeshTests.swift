import Foundation
import Testing

@testable import Optium

/// Construit un fichier minimal au format attendu : un seul triangle.
private func makeData() -> Data {
    var data = Data("OPTB".utf8)
    for value in [UInt32(1), UInt32(3), UInt32(3)] {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    let floats: [Float] = [
        -1, -1, -1,   1, 1, 1,                    // bornes
        0, 0, 0,   1, 0, 0,   0, 1, 0,            // positions
        0, 0, 1,   0, 0, 1,   0, 0, 1,            // normales
    ]
    for value in floats {
        withUnsafeBytes(of: value.bitPattern.littleEndian) { data.append(contentsOf: $0) }
    }
    for value in [UInt32(0), UInt32(1), UInt32(2)] {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    return data
}

@Test func leMaillageSeLitDepuisSesOctets() throws {
    let mesh = try BrainMesh.load(from: makeData())

    #expect(mesh.positions.count == 9)
    #expect(mesh.normals.count == 9)
    #expect(mesh.indices == [0, 1, 2])
    #expect(mesh.boundsMin == SIMD3<Float>(-1, -1, -1))
    #expect(mesh.boundsMax == SIMD3<Float>(1, 1, 1))
}

@Test func uneSignatureInvalideEstRefusee() {
    var data = makeData()
    data.replaceSubrange(0..<4, with: Data("XXXX".utf8))

    #expect(throws: BrainMesh.LoadError.self) {
        try BrainMesh.load(from: data)
    }
}

@Test func unFichierTronqueEstRefuse() {
    let data = makeData().prefix(30)

    #expect(throws: BrainMesh.LoadError.self) {
        try BrainMesh.load(from: Data(data))
    }
}

@Test func leMaillageDuPaquetSeChargeEtNEstPasVide() throws {
    let mesh = try BrainMesh.loadFromBundle()

    #expect(mesh.positions.count > 0)
    #expect(mesh.positions.count == mesh.normals.count)
    #expect(mesh.indices.count % 3 == 0)
    // Le script centre et met a l'echelle : les bornes encadrent l'origine.
    #expect(mesh.boundsMin.y < 0)
    #expect(mesh.boundsMax.y > 0)
}
