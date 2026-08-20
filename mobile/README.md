# Optium — application mobile (Expo / React Native)

Portage natif iOS + Android d'Optium. Le code web historique (Vite + React) reste
a la racine du depot ; ce dossier contient l'app mobile.

## Stack

| Brique | Choix | Pourquoi |
|---|---|---|
| SDK | Expo 57 (React Native 0.86, React 19.2) | derniere version stable |
| Navigation | `expo-router` + `NativeTabs` | vraie `UITabBarController`, Liquid Glass systeme offert sur iOS 26 |
| Composants systeme | `@expo/ui/swift-ui` | vues SwiftUI reelles (Form, List, Picker, Chart...) |
| Liquid Glass | `expo-glass-effect` | bindings sur `UIGlassEffect` (iOS 26) |
| Backend | `@supabase/supabase-js` + AsyncStorage | session persistee, refresh pilote par l'AppState |

## Demarrage

```bash
cd mobile
npm install
cp .env.example .env.local   # renseigner les cles Supabase
npx expo start
```

Scanner le QR code avec l'appareil photo de l'iPhone.

## Installer sur un iPhone

Deux chemins, selon ce dont tu as besoin :

**Expo Go** — le plus rapide, zero compte payant. Suffit tant que l'app n'utilise
que des modules du SDK Expo (c'est le cas aujourd'hui). Le Liquid Glass demande
un iPhone sous iOS 26.

**Build de developpement** — necessaire des qu'un module natif hors SDK est
ajoute. Passe par EAS, aucun Mac requis (la compilation tourne sur les serveurs
Expo), mais demande un compte Apple Developer pour installer sur un appareil
physique.

```bash
npm install -g eas-cli
eas login
eas build --profile development --platform ios
```

## Conventions

- Ne jamais importer `GlassView` directement : passer par `@/components/glass/glass-surface`,
  qui degrade proprement sur iOS < 26, Android et web.
- Les variables d'environnement exposees au client doivent etre prefixees `EXPO_PUBLIC_`.
- `src/app/glass.tsx` est un banc de test temporaire, a supprimer une fois le portage fait.
