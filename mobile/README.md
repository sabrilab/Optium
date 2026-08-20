# Optium — application mobile (Expo / React Native)

Portage iPhone d'Optium. Le code web d'origine reste a la racine du depot et
sert de reference ; ce dossier contient l'application mobile.

## Lancer l'app sur un iPhone

```bash
cd mobile
npm install
npx expo start
```

Scanner le QR code affiche dans le terminal avec l'appareil photo de l'iPhone.
L'app se recharge a chaque modification.

Aucune configuration n'est requise pour demarrer : les donnees sont stockees sur
l'appareil. Le fichier `.env.local` (voir `.env.example`) n'est necessaire que
pour l'authentification et la generation de taches par IA.

## Ce qui est natif

| Element | Implementation | Rendu reel |
|---|---|---|
| Onglets | `expo-router/unstable-native-tabs` | `UITabBarController`, Liquid Glass systeme sur iOS 26 |
| Panneaux flottants | `@/components/glass/glass-surface` | `UIGlassEffect`, repli en flou puis en aplat |
| Reglages | `@expo/ui/swift-ui` (`settings.ios.tsx`) | `Form`, `Section`, `Toggle`, `Slider` SwiftUI |
| Graphique | `@expo/ui/swift-ui` (`stats-chart.ios.tsx`) | Swift Charts |
| Icones | `expo-symbols` (`icon.ios.tsx`) | SF Symbols |

Les modules `@expo/ui` et `expo-symbols` initialisent le pont natif des le
chargement du module : ils ne peuvent pas etre importes puis ignores via un test
`Platform.OS`. D'ou la separation par extension de fichier `.ios.tsx`, qui les
tient hors des bundles web et Android.

## Le modele 3D

`assets/models/brain.glb` est genere, pas edite a la main :

```bash
python3 scripts/bake_brain.py ../public/scene.gltf assets/models/brain.glb
```

Le script applique la hierarchie de transformations du modele Sketchfab, fusionne
les huit meshes en une seule geometrie, centre et met le tout a l'echelle, puis
stocke les bornes dans les `extras` du GLB. L'app n'a donc aucun calcul a faire
au demarrage, et la coque comme le fluide tiennent chacun en un seul draw call.

Relancer ce script apres tout changement du modele source.

## Conventions

- Ne jamais importer `GlassView` directement : passer par `GlassSurface`, qui
  degrade proprement sur iOS anterieur a 26, Android et web.
- Les variables d'environnement lues par le client doivent etre prefixees
  `EXPO_PUBLIC_`.
- Aucune cle d'API tierce dans l'application : les appels au modele passent par
  la fonction edge Supabase `generate-tasks`.

## Build installable (sans Mac)

```bash
npm install -g eas-cli
eas login
eas build --profile development --platform ios
```

La compilation tourne sur les serveurs Expo. Installer sur un appareil physique
demande un compte Apple Developer ; Expo Go suffit tant que l'app n'utilise que
des modules du SDK, ce qui est le cas aujourd'hui.
