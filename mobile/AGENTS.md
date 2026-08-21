# Optium — application mobile

> **Ce fichier decrit l'application Expo (`mobile/`), qui n'est plus le projet
> actif.** Depuis le 2026-08-22, Optium est reecrite en SwiftUI natif dans
> `ios-native/`, et le code Expo n'est conserve que comme reference de
> comparaison pendant le portage. Voir `docs/superpowers/specs/` et
> `docs/superpowers/plans/`.
>
> Deux contraintes ci-dessous ne valent que pour la version Expo et ont ete
> explicitement abandonnees dans la version native :
>
> - **le SDK fige en 54**, impose par Expo Go, n'a plus d'objet : l'app native
>   se compile et s'installe directement ;
> - **« pas de bascule de theme, l'apparence suit iOS »** : la version native
>   est en noir permanent, choix de direction artistique assume. La scene 3D,
>   les auras et les cartes n'existent que sur un noir vrai.
>
> En revanche, les trois choix de rendu de la scene 3D restent valables et ont
> ete portes tels quels en Metal.

Application Pomodoro pour iPhone : minuteur de sessions, projets decoupes en
taches par IA, statistiques, et une scene 3D dont le remplissage suit la
progression de la session.

Ce fichier decrit les contraintes du projet. Les lire evite de repeter des
erreurs qui ont deja coute du temps.

## Contrainte principale : le SDK est fige en 54

Le projet est sur **Expo SDK 54**, pas sur la derniere version. Ce n'est pas un
oubli : l'Expo Go installe sur l'iPhone de test ne supporte que le SDK 54, et
Expo Go n'accepte qu'une seule version de SDK a la fois. Monter le SDK rend
l'app impossible a ouvrir sur le telephone tant qu'un build de developpement
n'a pas remplace Expo Go.

Ne pas lancer `npx expo install --fix` avec l'intention de monter de version, ni
mettre a jour `expo` sans que ce point ait ete tranche.

Documentation de reference : https://docs.expo.dev/versions/v54.0.0/

## Lancer l'app

```bash
npm install
npx expo start              # serveur de developpement, ouverture dans Expo Go
npx expo run:ios --device   # compile et installe le build de developpement
```

`npx expo run:ios` enchaine CocoaPods, la compilation et l'installation. C'est
la commande a privilegier : elle evite d'avoir a gerer les pods a la main.

Pour compiler sans installer, une fois `pod install` passe :

```bash
xcodebuild -workspace ios/Optium.xcworkspace -scheme Optium \
  -destination 'generic/platform=iOS Simulator' build
```

Filtrer la sortie sur `error:|warning:|BUILD` — xcodebuild produit des milliers
de lignes sans interet.

## Valider avant de livrer

```bash
npx tsc --noEmit      # doit sortir sans rien afficher
npx expo lint         # zero erreur ; des avertissements react/no-unknown-property
                      # sur la scene 3D sont normaux (props react-three-fiber)
npx expo export --platform ios   # verifie que le bundle se construit
```

## Expo Go n'embarque pas tous les modules natifs

Expo Go est une app publiee sur l'App Store : elle ne contient que les modules
compiles dans son propre binaire. **`@expo/ui` n'en fait pas partie** — y rendre
un composant SwiftUI affiche un ecran rouge « Unimplemented component ».

D'ou deux mecanismes, a respecter pour tout nouveau composant natif :

1. **Separation par extension de fichier.** `@expo/ui` et `expo-symbols`
   initialisent le pont natif *au chargement du module* : un simple test
   `Platform.OS` arrive trop tard, l'import a deja echoue. Le code concerne vit
   donc dans un fichier `.ios.tsx`, avec un equivalent React Native dans le
   fichier sans suffixe (voir `components/icon`, `components/stats-chart`,
   `app/settings`).
2. **Detection a l'execution.** `supportsSwiftUI` (`src/lib/runtime.ts`)
   distingue Expo Go d'un build de developpement. Les fichiers `.ios.tsx`
   basculent sur leur equivalent React Native quand il vaut faux.

`expo-glass-effect` fait exception : il est inclus dans Expo Go, le Liquid Glass
fonctionne donc partout.

## Le dossier ios/ est versionne

Il est genere par `expo prebuild`, pas ecrit a la main. **Apres toute
modification d'`app.json`** — plugin, permission, identifiant, icone :

```bash
npx expo prebuild --platform ios --clean
```

Sans cela, les changements d'`app.json` n'atteignent jamais l'app compilee.

## Conventions

- **Jamais de `GlassView` importe directement.** Passer par
  `@/components/glass/glass-surface`, qui degrade en flou sur iOS anterieur a 26
  puis en aplat ailleurs.
- **Jamais de couleur en dur.** Les couleurs viennent de `getPalette()`
  (`src/constants/theme.ts`), qui expose les `UIColor` semantiques d'Apple via
  `PlatformColor`. Elles suivent seules le mode sombre et le reglage
  « Augmenter le contraste ». Les tailles de texte viennent de `Typography`.
- **Pas de bascule de theme dans l'app.** L'apparence suit iOS, comme dans les
  apps d'Apple. Les couleurs `PlatformColor` se resolvent cote natif et ne
  peuvent pas etre forcees depuis JavaScript.
- **Aucune cle d'API tierce dans l'application.** Un binaire mobile est
  extractible. Les appels au modele passent par la fonction edge Supabase
  `generate-tasks`, qui detient la cle cote serveur.
- Les variables lues par le client doivent etre prefixees `EXPO_PUBLIC_`.
  `.env.local` n'est jamais commite.
- Les cibles tactiles font au moins 44 points (`Layout.minTouchTarget`).

## La scene 3D

`assets/models/brain.glb` est **genere**, jamais edite :

```bash
python3 scripts/bake_brain.py ../public/scene.gltf assets/models/brain.glb
```

Le script applique la hierarchie de transformations du modele Sketchfab d'origine,
fusionne ses huit meshes en une geometrie unique, centre et met a l'echelle, puis
stocke les bornes dans les `extras` du GLB. L'app ne calcule donc rien au
demarrage, et la coque comme le fluide tiennent chacun en un seul draw call.

Trois choix de rendu sont deliberes et ne doivent pas etre annules sans mesure :

- Le verre est un effet de Fresnel, pas un `MeshPhysicalMaterial` a
  transmission — celle-ci imposait une passe de rendu supplementaire par image
  et une carte d'environnement telechargee depuis un CDN, dont l'echec faisait
  disparaitre toute la scene en silence.
- Le shader du fluide n'utilise pas `discard`, qui desactive l'elimination
  anticipee de profondeur sur les GPU a tuiles des iPhone.
- Le rendu est suspendu hors de l'ecran Session et en arriere-plan
  (`frameloop="never"`), et la densite de pixels plafonnee a 2.

Le composant lit le store imperativement dans `useFrame` plutot que de s'y
abonner : le minuteur change chaque seconde, et un abonnement declencherait un
rendu React a chaque fois alors que seule une uniforme GPU doit bouger.

## Donnees

Tout est local : `src/store.ts` (zustand) persiste dans AsyncStorage. Supabase ne
sert qu'a l'authentification et a la fonction de generation de taches, et reste
optionnel — sans cles, l'app fonctionne, seule l'IA est indisponible.
