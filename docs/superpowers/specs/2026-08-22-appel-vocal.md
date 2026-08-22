# L'appel vocal

Spec, 2026-08-22. À relire avant implémentation — rien n'a été codé.

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

## 7. Ce que je n'ai pas tranché, et qui te revient

Trois questions ouvertes. Elles ne bloquent pas l'écriture du plan, mais elles
changent le résultat.

1. **La voix de sortie.** `AVSpeechSynthesizer` a des voix système très
   inégales en français. Une voix médiocre abîmerait plus l'expérience que
   l'absence de voix. Faut-il exiger une voix premium installée, et se rabattre
   sur le texte affiché sinon ?

2. **Qui déclenche l'écoute.** Bouton maintenu (on parle tant qu'on appuie,
   sans détection de fin) ou appui-relâche avec détection de silence ? Le
   maintien est plus prévisible et sans faux départ ; l'appui-relâche est plus
   confortable et plus risqué.

3. **Les trois questions restent-elles ?** En vocal on pourrait laisser parler
   librement. Mais les trois questions sont ce qui borne le rôle du cerveau, et
   ce bornage est explicitement revendiqué dans `CallScreen`. Mon avis : les
   garder comme entrées de l'appel, et n'ouvrir la parole libre qu'à
   l'intérieur du sujet choisi.

---

## 8. Ce que ça coûte, honnêtement

C'est la plus grosse fonctionnalité depuis le pivot. Le tool calling seul
réécrit `BrainCall` en entier, et la publication de ce que voit l'écran demande
un chemin qui n'existe pas aujourd'hui entre un outil et une vue.

Le risque principal n'est pas technique : c'est que l'appel vocal devienne le
centre de l'application alors que **la porte est le produit**. La voix doit
rester ce qu'est l'appel écrit — quelque chose qu'on ouvre, qu'on ferme, et
qu'on ne consulte pas.
