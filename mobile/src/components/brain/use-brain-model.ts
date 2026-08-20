import { Asset } from 'expo-asset';
import { File } from 'expo-file-system';
import { useEffect, useState } from 'react';
import { Platform } from 'react-native';
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';

export type BrainModel = {
  geometry: THREE.BufferGeometry;
  boundsMin: THREE.Vector3;
  boundsMax: THREE.Vector3;
};

// Le modele est immuable : on ne le charge et ne le decode qu'une seule fois
// pour toute la duree de vie de l'app, meme si l'ecran est monte plusieurs fois.
let cached: Promise<BrainModel> | null = null;

async function readModelBytes(): Promise<ArrayBuffer> {
  const asset = Asset.fromModule(require('@/assets/models/brain.glb'));
  await asset.downloadAsync();

  // Sur web, l'asset est servi par HTTP et la classe File n'existe pas.
  if (Platform.OS === 'web') {
    const response = await fetch(asset.uri);
    return response.arrayBuffer();
  }

  const uri = asset.localUri ?? asset.uri;
  return new File(uri).arrayBuffer();
}

function loadBrainModel(): Promise<BrainModel> {
  return readModelBytes().then(
    (bytes) =>
      new Promise<BrainModel>((resolve, reject) => {
        new GLTFLoader().parse(
          bytes,
          '',
          (gltf) => {
            let geometry: THREE.BufferGeometry | null = null;
            gltf.scene.traverse((child) => {
              if (!geometry && (child as THREE.Mesh).isMesh) {
                geometry = (child as THREE.Mesh).geometry;
              }
            });

            if (!geometry) {
              reject(new Error('Aucun mesh dans brain.glb'));
              return;
            }

            // Les bornes sont ecrites par scripts/bake_brain.py. On retombe sur
            // la boite englobante si le modele est regenere sans ces extras.
            const extras = gltf.parser.json.meshes?.[0]?.extras;
            if (extras?.boundsMin && extras?.boundsMax) {
              resolve({
                geometry,
                boundsMin: new THREE.Vector3().fromArray(extras.boundsMin),
                boundsMax: new THREE.Vector3().fromArray(extras.boundsMax),
              });
              return;
            }

            (geometry as THREE.BufferGeometry).computeBoundingBox();
            const box = (geometry as THREE.BufferGeometry).boundingBox!;
            resolve({ geometry, boundsMin: box.min.clone(), boundsMax: box.max.clone() });
          },
          reject
        );
      })
  );
}

/**
 * Charge la geometrie fusionnee du cerveau.
 *
 * Le GLB est deja centre, mis a l'echelle et fusionne en un seul mesh par le
 * script de build : il n'y a donc ni parcours de hierarchie, ni calcul de
 * matrices, ni fusion a faire au demarrage de l'app.
 */
export function useBrainModel(): { model: BrainModel | null; error: Error | null } {
  const [model, setModel] = useState<BrainModel | null>(null);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let active = true;
    cached ??= loadBrainModel();

    cached.then(
      (loaded) => active && setModel(loaded),
      (cause) => {
        // Un chargement echoue ne doit pas empoisonner les montages suivants.
        cached = null;
        if (active) setError(cause instanceof Error ? cause : new Error(String(cause)));
      }
    );

    return () => {
      active = false;
    };
  }, []);

  return { model, error };
}
