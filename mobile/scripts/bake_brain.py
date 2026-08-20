"""
Precalcule le modele du cerveau pour le mobile.

Le GLTF d'origine (Sketchfab) contient 8 meshes separes, imbriques dans une
hierarchie de noeuds transformes. Les charger tels quels coute 8 draw calls pour
la coque et 8 de plus pour le fluide, et oblige l'app a recalculer les matrices
monde puis les bornes a chaque demarrage.

Ce script fait ce travail une fois pour toutes et produit un GLB unique :
  - transformations de la hierarchie appliquees aux sommets
  - les 8 meshes fusionnes en une seule geometrie
  - modele centre sur l'origine et normalise dans une sphere de 2.5 unites
  - bornes stockees dans les `extras`, pour le shader de remplissage

Usage : python3 scripts/bake_brain.py <source.gltf> <sortie.glb>
"""

import json
import struct
import sys
from pathlib import Path

COMPONENT_FORMATS = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
TYPE_COUNTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def identity():
    return [1.0 if i % 5 == 0 else 0.0 for i in range(16)]


def mat_mul(a, b):
    """Multiplication de matrices 4x4 en convention colonne (celle du glTF)."""
    out = [0.0] * 16
    for col in range(4):
        for row in range(4):
            out[col * 4 + row] = sum(a[k * 4 + row] * b[col * 4 + k] for k in range(4))
    return out


def node_matrix(node):
    if "matrix" in node:
        return list(node["matrix"])
    m = identity()
    if "rotation" in node:
        x, y, z, w = node["rotation"]
        m = [
            1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0.0,
            2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0.0,
            2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0.0,
            0.0, 0.0, 0.0, 1.0,
        ]
    if "scale" in node:
        sx, sy, sz = node["scale"]
        for i in range(3):
            m[i] *= sx
            m[4 + i] *= sy
            m[8 + i] *= sz
    if "translation" in node:
        m[12], m[13], m[14] = node["translation"]
    return m


def read_accessor(gltf, blob, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    fmt = COMPONENT_FORMATS[acc["componentType"]]
    ncomp = TYPE_COUNTS[acc["type"]]
    item_size = struct.calcsize(fmt) * ncomp
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride") or item_size

    values = []
    for i in range(acc["count"]):
        offset = start + i * stride
        values.append(struct.unpack_from("<" + fmt * ncomp, blob, offset))
    return values


def main(src_path, out_path):
    src = Path(src_path)
    gltf = json.loads(src.read_text())
    blob = (src.parent / gltf["buffers"][0]["uri"]).read_bytes()

    # Parcours de la hierarchie en accumulant les matrices monde.
    positions, normals, indices = [], [], []
    stack = [(n, identity()) for n in gltf["scenes"][gltf.get("scene", 0)]["nodes"]]

    while stack:
        node_index, parent = stack.pop()
        node = gltf["nodes"][node_index]
        world = mat_mul(parent, node_matrix(node))

        for child in node.get("children", []):
            stack.append((child, world))

        if "mesh" not in node:
            continue

        for prim in gltf["meshes"][node["mesh"]]["primitives"]:
            base = len(positions)
            for x, y, z in read_accessor(gltf, blob, prim["attributes"]["POSITION"]):
                positions.append((
                    world[0] * x + world[4] * y + world[8] * z + world[12],
                    world[1] * x + world[5] * y + world[9] * z + world[13],
                    world[2] * x + world[6] * y + world[10] * z + world[14],
                ))
            # Les normales ignorent la translation. Les matrices de ce modele sont
            # des rotations uniformement mises a l'echelle, donc la partie 3x3
            # suffit : on renormalise juste apres.
            for x, y, z in read_accessor(gltf, blob, prim["attributes"]["NORMAL"]):
                nx = world[0] * x + world[4] * y + world[8] * z
                ny = world[1] * x + world[5] * y + world[9] * z
                nz = world[2] * x + world[6] * y + world[10] * z
                length = (nx * nx + ny * ny + nz * nz) ** 0.5 or 1.0
                normals.append((nx / length, ny / length, nz / length))
            for (i,) in read_accessor(gltf, blob, prim["indices"]):
                indices.append(base + i)

    # Centrage puis mise a l'echelle dans une sphere de 2.5 unites, comme le
    # faisait la version web au runtime.
    lo = [min(p[axis] for p in positions) for axis in range(3)]
    hi = [max(p[axis] for p in positions) for axis in range(3)]
    center = [(lo[a] + hi[a]) / 2 for a in range(3)]
    scale = 2.5 / max(hi[a] - lo[a] for a in range(3))

    positions = [tuple((p[a] - center[a]) * scale for a in range(3)) for p in positions]
    lo = [min(p[a] for p in positions) for a in range(3)]
    hi = [max(p[a] for p in positions) for a in range(3)]

    pos_bytes = b"".join(struct.pack("<3f", *p) for p in positions)
    nrm_bytes = b"".join(struct.pack("<3f", *n) for n in normals)
    idx_bytes = b"".join(struct.pack("<I", i) for i in indices)

    def pad(data, alignment=4):
        remainder = len(data) % alignment
        return data + b"\x00" * (alignment - remainder) if remainder else data

    pos_bytes, nrm_bytes = pad(pos_bytes), pad(nrm_bytes)
    bin_chunk = pos_bytes + nrm_bytes + idx_bytes

    doc = {
        "asset": {"version": "2.0", "generator": "optium bake_brain"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": "brain"}],
        "meshes": [{
            "name": "brain",
            "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": 2}],
            "extras": {"boundsMin": lo, "boundsMax": hi},
        }],
        "buffers": [{"byteLength": len(bin_chunk)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(pos_bytes), "target": 34962},
            {"buffer": 0, "byteOffset": len(pos_bytes), "byteLength": len(nrm_bytes), "target": 34962},
            {"buffer": 0, "byteOffset": len(pos_bytes) + len(nrm_bytes), "byteLength": len(idx_bytes), "target": 34963},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(positions), "type": "VEC3", "min": lo, "max": hi},
            {"bufferView": 1, "componentType": 5126, "count": len(normals), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5125, "count": len(indices), "type": "SCALAR"},
        ],
    }

    json_chunk = pad(json.dumps(doc, separators=(",", ":")).encode(), 4).replace(b"\x00", b" ")
    glb = b"glTF" + struct.pack("<II", 2, 12 + 8 + len(json_chunk) + 8 + len(bin_chunk))
    glb += struct.pack("<II", len(json_chunk), 0x4E4F534A) + json_chunk
    glb += struct.pack("<II", len(bin_chunk), 0x004E4942) + bin_chunk

    Path(out_path).write_bytes(glb)

    print(f"sommets   : {len(positions)}")
    print(f"triangles : {len(indices) // 3}")
    print(f"bornes    : min={[round(v, 3) for v in lo]} max={[round(v, 3) for v in hi]}")
    print(f"sortie    : {out_path} ({len(glb) / 1024 / 1024:.2f} Mo)")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
