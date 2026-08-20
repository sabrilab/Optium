import { Asset } from 'expo-asset';
import { File } from 'expo-file-system';
import { useEffect, useState } from 'react';
import { Platform } from 'react-native';

import { parseGlb, type ParsedBrain } from './parse-glb';

export type BrainModel = ParsedBrain;

// Le modele est immuable : on ne le charge et ne le decode qu'une seule fois
// pour toute la duree de vie de l'app, meme si l'ecran est monte plusieurs fois.
let cached: Promise<BrainModel> | null = null;

async function readModelBytes(): Promise<ArrayBuffer> {
  const asset = Asset.fromModule(require('@/assets/models/brain.glb'));

  // Sur web, l'asset est deja une URL servie en HTTP : il n'y a rien a
  // telecharger sur un disque, et downloadAsync ne se resout pas.
  if (Platform.OS === 'web') {
    const response = await fetch(asset.uri);
    return response.arrayBuffer();
  }

  // Sur mobile, l'asset est copie sur le disque puis lu par le systeme de
  // fichiers — fetch() ne gere pas les URI file:// de maniere fiable.
  await asset.downloadAsync();
  return new File(asset.localUri ?? asset.uri).arrayBuffer();
}

/**
 * Charge la geometrie fusionnee du cerveau.
 *
 * Le GLB est deja centre, mis a l'echelle et fusionne en un seul maillage par
 * le script de build : il n'y a ni parcours de hierarchie, ni calcul de
 * matrices, ni fusion a faire au demarrage de l'app.
 */
export function useBrainModel(): { model: BrainModel | null; error: Error | null } {
  const [model, setModel] = useState<BrainModel | null>(null);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let active = true;
    cached ??= readModelBytes().then(parseGlb);

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
