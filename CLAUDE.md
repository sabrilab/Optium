# Optium

Deux applications dans un meme depot :

- **`mobile/`** — l'application iPhone (Expo / React Native). **C'est le projet
  actif.** Ses contraintes sont decrites dans `mobile/AGENTS.md` : les lire
  avant toute modification.
- **racine** — la version web d'origine (Vite + React), conservee comme
  reference pour le portage. Ne plus y developper.

Les deux partagent le meme modele 3D : `public/scene.gltf` est la source dont
`mobile/assets/models/brain.glb` est derive.
