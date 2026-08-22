# L'appel vocal

Spec, 2026-08-22. **Implémentée** — les trois questions ouvertes ont été
tranchées, voir §7.

---

## 1. Pourquoi ça ne contredit pas la règle

L'en-tête de `Call/BrainCall.swift` dit :

> Un appel **commence et se termine**. Ce n'est pas une surface qui défile, pas
> une conversation, pas un onglet — cette contrainte est ce qui empêche
> l'application de devenir un chatbot de plus.

**Cette règle ne change pas, et la voix la renforce.** Un appel vocal est borné
par sa nature même : il a une durée, il se termine, et il n'y a rien à faire
défiler. Ce qui détruirait la règle, c'est un fil de messages écrits — pas la
parole.

Le risque est donc précis, et il n'est pas dans la voix : il est dans ce qu'on
serait tenté de garder à côté d'elle.

### Interdits, à tenir dans le code et pas seulement ici

- Aucun historique consultable.
- Aucune transcription relisible ou reprenable.
- Aucun fil de messages.
- **Quand l'appel se termine, il ne reste rien à faire défiler.** L'écran
  retombe sur les trois questions, comme avant.

Ce qui est dit pendant l'appel vit en mémoire pour la durée de l'appel, et
disparaît avec lui. La seule trace persistante reste `ProjectMemory`, écrite à
la fermeture d'un fil — jamais par l'appel.

**Un test doit interdire la régression** : aucun modèle SwiftData, aucun
fichier, aucune clé `UserDefaults` ne doit porter de transcription.

---

## 2. La chaîne, entièrement sur l'appareil

```
SpeechTranscriber / SpeechAnalyzer   →   FoundationModels   →   AVSpeechSynthesizer
        (transcription)                     (réponse)               (voix)
```

Référence : WWDC25 session 277, *Bring advanced speech-to-text to your app with
SpeechAnalyzer*.

**Rien ne sort de l'appareil, et c'est testable.** La promesse « aucune
description de travail ne quitte l'appareil » vaut déjà pour l'appel écrit ;
elle doit valoir en vocal. Concrètement : `SpeechTranscriber` avec un modèle
local installé, jamais le chemin serveur, et une vérification explicite que la
locale demandée est disponible hors ligne — sinon on refuse plutôt que de
basculer silencieusement.

C'est le point le plus important de la spec, parce que c'est le seul qui, s'il
est raté, transforme une fonctionnalité en manquement.

---

## 3. Le tool calling remplace l'empilement

### Ce qui existe

`BrainCall.prompt()` empile tout : douze fils fermés, tous les fils ouverts, la
régularité, la clarté, la mémoire du projet — que le modèle en ait besoin ou
non.

### Ce qui remplace

Quatre outils, un par module, que le modèle appelle quand il en a besoin :

| Outil | Ce qu'il rend |
|---|---|
| `ClarityTool` | clarté, fenêtre, nuits observées |
| `ThreadHistoryTool` | fils fermés : reprises, nuits traversées, retenues |
| `OpenThreadsTool` | fils ouverts |
| `TierTool` | palier et preuves |

Le prompt redevient minuscule. Deux gains, et le second est le vrai :

1. La fenêtre de contexte ne sature plus.
2. **Chaque affirmation du modèle correspond à un appel d'outil daté.**

Références : WWDC25 session 301 (tool calling), session 259 (exemple complet).

**Conséquence à ne pas manquer** : le périmètre de projet introduit dans l'appel
écrit doit être passé aux outils, sinon `ThreadHistoryTool` rendra les fils de
tous les projets et on perdra ce qu'on vient de gagner.

---

## 4. Chaque outil montre ce dont il parle

**C'est le cœur de la fonctionnalité, pas sa décoration.**

Un outil ne fait pas que rendre du texte au modèle : il publie ce qu'il a
trouvé, et l'écran l'affiche pendant que la voix en parle.

- `ThreadHistoryTool` appelé → la carte du fil concerné apparaît.
- `ClarityTool` appelé → le cerveau et la fenêtre passent au premier plan.

### Le motif, à écrire dans le code

La première règle des instructions dit : *un modèle qui rappelle est
vérifiable*. Afficher la donnée pendant qu'on l'énonce **transforme cette
promesse en démonstration** — une invention deviendrait visible, faute d'avoir
quelque chose à montrer.

C'est aussi la réponse au risque propre à la voix : une parole qui passe ne se
vérifie pas. Ce qui est montré, si.

**Une seule chose à l'écran à la fois.** Ce qui est montré remplace ce qui
précédait. Rien ne s'empile — un empilement serait le fil de messages qu'on
vient d'interdire, sous une autre forme.

---

## 5. L'aura aux bords de l'écran

Pendant l'appel, l'aura du cerveau déborde jusqu'aux bords et respire au rythme
de la parole.

### Ne pas copier le halo de Siri

Ni ses couleurs, ni son dégradé animé. Trois raisons, toutes suffisantes :

- confusion sur qui parle ;
- Apple décourage l'imitation de ses affordances système ;
- une revue App Store peut le relever.

On utilise `Design/Aura.swift` et les teintes existantes — `focusGlow` #5253F0,
`focusGlowFar` #8A4ADD. C'est notre identité, et elle dit quelque chose de juste :
**c'est le cerveau de l'utilisateur qui parle, il occupe tout l'écran.**

### Épouser les coins de l'appareil

`ConcentricRectangle` et `GeometryProxy.concentricCornerRadii` (iOS 26). Aucune
API privée.

### Mouvement réduit

Sous `accessibilityReduceMotion`, l'aura devient fixe. Elle ne pulse pas. Elle
reste présente : elle dit qui parle, et cette information ne doit pas dépendre
du mouvement — cf. la règle de `Design/Motion.swift`.

---

## 6. Contraintes à traiter, pas à découvrir

- **Matériel.** Foundation Models exige un iPhone 15 Pro ou plus récent avec
  Apple Intelligence activé. `SystemLanguageModel.default.availability` est déjà
  géré dans `BrainCall` : l'appel vocal dégrade de la même façon, avec un
  message qui explique — jamais un échec muet.
- **Fenêtre de contexte.** 8192 tokens sur l'appareil, instructions + prompt +
  réponse confondus. Avec les outils on devrait rester loin du plafond ;
  à vérifier avec `model.tokenCount` (iOS 26.4+).
- **Les erreurs ne doivent plus être confondues.** Le `catch` actuel transforme
  *toute* erreur en « L'appel n'a pas abouti », ce qui est opaque.
  `exceededContextWindowSize` doit être distingué, et dit autrement.
- **Micro.** `NSMicrophoneUsageDescription` est obligatoire, avec une
  justification explicite en français. Proposition :
  « Optium écoute votre question pendant un appel. Votre voix est transcrite sur
  l'appareil et n'en sort jamais. »
- **`app.json` n'existe plus ici** : l'ajout se fait dans les réglages de cible
  du projet Xcode, `INFOPLIST_KEY_NSMicrophoneUsageDescription`.

---

## 7. Les trois questions, tranchées

1. **La voix de sortie — aucune condition.** Le texte de la réponse reste
   affiché quoi qu'il arrive ; la voix s'ajoute. `Voice.bestFrenchVoice()` prend
   la meilleure qualité installée — `premium`, puis `enhanced`, puis `default`.
   Conditionner l'appel à la présence d'une voix premium en aurait privé des
   gens qui n'ont rien demandé, pour un gain qui n'existe que si le
   téléchargement a été fait.

2. **Appui maintenu.** Pas de seuil de silence à régler, pas de faux départ, et
   la fin appartient à l'utilisateur. Ça épouse aussi la règle du §1 : un appel
   qu'on tient est un appel qui se termine quand on lâche.

3. **Les trois questions restent, comme entrées.** La parole libre n'ouvre qu'à
   l'intérieur du sujet choisi — `CallScreen.prefixed(_:)` rattache chaque
   relance à la question de départ. C'est le bornage du rôle, et il est
   revendiqué dans `CallScreen`.

---

## 8. Ce qui a été construit

| Fichier | Rôle |
|---|---|
| `Call/CallStage.swift` | la scène et l'instantané passé aux outils |
| `Call/BrainTools.swift` | les quatre outils |
| `Call/ExhibitCard.swift` | ce que l'outil vient de consulter |
| `Call/Voice.swift` | transcription, synthèse, niveau sonore |
| `Call/CallAura.swift` | l'aura aux bords, sans imiter Siri |

`BrainCall.prompt()` ne porte plus aucun fait : `BrainVoiceTests` vérifie qu'il
tient sous 700 caractères et ne contient ni chiffre ni phrase de fil.

`VoiceTests` tient la promesse de confidentialité : aucune entité SwiftData,
aucune clé de réglages ne peut porter une transcription, et `CallScreen`
n'écrit dans aucune mémoire.

---

## 9. Ce qui reste ouvert

- **Rien n'a été essayé sur un appareil.** Le simulateur n'a ni Apple
  Intelligence, ni micro utile, ni modèle de transcription : tout ce qui est
  ici compile et passe les tests, mais la chaîne complète n'a jamais tourné.
  C'est la première chose à faire.
- **`Tier(rawValue:)` dans `ExhibitCard`** reconstruit un palier depuis son mot
  affiché. Ça marche parce que les mots sont distincts, mais c'est fragile :
  mieux vaudrait faire porter le `Tier` par l'exhibit.
- **L'installation du modèle de transcription** peut être longue au premier
  appel et l'interface ne montre qu'« Un instant… ». Une progression serait
  plus honnête.
- Le risque du §8 initial n'a pas disparu : **la porte reste le produit.** Si
  l'appel vocal devient ce qu'on ouvre en premier, quelque chose s'est perdu.
