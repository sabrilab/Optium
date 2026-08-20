import * as THREE from 'three';

const MAGIC_GLTF = 0x46546c67;
const CHUNK_JSON = 0x4e4f534a;
const CHUNK_BIN = 0x004e4942;

const COMPONENT_ARRAYS = {
  5121: Uint8Array,
  5123: Uint16Array,
  5125: Uint32Array,
  5126: Float32Array,
} as const;

const TYPE_SIZES: Record<string, number> = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 };

type GlbAccessor = {
  bufferView: number;
  componentType: keyof typeof COMPONENT_ARRAYS;
  count: number;
  type: string;
  byteOffset?: number;
};

type GlbDocument = {
  accessors: GlbAccessor[];
  bufferViews: { byteOffset?: number; byteLength: number }[];
  meshes: {
    primitives: { attributes: Record<string, number>; indices: number }[];
    extras?: { boundsMin?: number[]; boundsMax?: number[] };
  }[];
};

export type ParsedBrain = {
  geometry: THREE.BufferGeometry;
  boundsMin: THREE.Vector3;
  boundsMax: THREE.Vector3;
};

/**
 * Lecteur GLB minimal, taille pour le seul fichier que l'app embarque.
 *
 * On n'utilise pas le GLTFLoader de three : il est distribue en module ES et
 * s'appuie sur `import.meta`, que le bundler ne sait pas traiter sur toutes les
 * versions du SDK. Il apporte par ailleurs tout un support de materiaux,
 * textures, animations et extensions dont ce modele n'a aucun usage — il est
 * genere par scripts/bake_brain.py et ne contient qu'un maillage de positions,
 * de normales et d'index.
 *
 * Ce lecteur reste generique sur les points qui comptent (decalages des vues de
 * tampon, types de composants, bornes calculees a defaut d'extras) afin qu'une
 * regeneration du modele ne le prenne pas en defaut.
 */
export function parseGlb(bytes: ArrayBuffer): ParsedBrain {
  const header = new DataView(bytes, 0, 12);
  if (header.getUint32(0, true) !== MAGIC_GLTF) {
    throw new Error('Fichier GLB invalide : en-tete inattendu.');
  }

  let json: GlbDocument | null = null;
  let binary: ArrayBuffer | null = null;
  let offset = 12;

  while (offset < bytes.byteLength) {
    const chunk = new DataView(bytes, offset, 8);
    const length = chunk.getUint32(0, true);
    const kind = chunk.getUint32(4, true);
    const start = offset + 8;

    if (kind === CHUNK_JSON) {
      json = JSON.parse(new TextDecoder().decode(new Uint8Array(bytes, start, length)));
    } else if (kind === CHUNK_BIN) {
      binary = bytes.slice(start, start + length);
    }

    // Les segments sont alignes sur quatre octets.
    offset = start + length + ((4 - (length % 4)) % 4);
  }

  if (!json || !binary) throw new Error('Fichier GLB incomplet : segment manquant.');

  const readAccessor = (index: number) => {
    const accessor = json.accessors[index];
    const view = json.bufferViews[accessor.bufferView];
    const ArrayType = COMPONENT_ARRAYS[accessor.componentType];
    const start = (view.byteOffset ?? 0) + (accessor.byteOffset ?? 0);
    return new ArrayType(binary, start, accessor.count * TYPE_SIZES[accessor.type]);
  };

  const primitive = json.meshes[0].primitives[0];
  const positions = readAccessor(primitive.attributes.POSITION) as Float32Array;
  const normals = readAccessor(primitive.attributes.NORMAL) as Float32Array;
  const indices = readAccessor(primitive.indices);

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geometry.setAttribute('normal', new THREE.BufferAttribute(normals, 3));
  geometry.setIndex(new THREE.BufferAttribute(indices as Uint16Array | Uint32Array, 1));

  const extras = json.meshes[0].extras;
  if (extras?.boundsMin && extras?.boundsMax) {
    return {
      geometry,
      boundsMin: new THREE.Vector3().fromArray(extras.boundsMin),
      boundsMax: new THREE.Vector3().fromArray(extras.boundsMax),
    };
  }

  geometry.computeBoundingBox();
  const box = geometry.boundingBox!;
  return { geometry, boundsMin: box.min.clone(), boundsMax: box.max.clone() };
}
