# Optium

Trois versions dans un meme depot, une seule est active :

- **`ios-native/`** — l'application iPhone en SwiftUI natif. **C'est le projet
  actif.** Tout est decrit dans `ios-native/AGENTS.md` : le produit, le moteur
  de clarte, les decisions et les pieges. Le lire avant toute modification.
- **`mobile/`** — l'ancienne application Expo / React Native. **Perimee.** Elle
  implementait un minuteur Pomodoro, produit abandonne le 2026-08-22. Conservee
  comme reference de comparaison ; son `AGENTS.md` decrit un produit qui
  n'existe plus.
- **racine** — la toute premiere version web (Vite + React). Historique.

Les trois partagent le meme modele 3D : `public/scene.gltf` est la source dont
`mobile/assets/models/brain.glb` et `brain.bin` sont derives, ce dernier etant
celui que l'application native charge.

Conception et plans : `docs/superpowers/`. Langage visuel :
`docs/brief-design.md`.
