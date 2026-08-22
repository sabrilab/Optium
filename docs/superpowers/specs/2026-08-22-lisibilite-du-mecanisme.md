# Rendre le mécanisme lisible — conception

Deuxième tronçon après *la porte*. Ne change ni le produit, ni le moteur, ni la
règle centrale. Traite un seul défaut : **l'application est lisible pour qui l'a
construite, pas pour qui la télécharge.**

## Intention

Trois moments posent problème, et ils ne se règlent pas de la même façon.

1. **L'arrivée.** Sans nuit enregistrée, `ClarityEngine.clarity` renvoie `nil`.
   Le premier écran n'a rien à montrer. Quelqu'un qui installe l'application le
   soir la trouve vide, ne comprend pas ce qu'elle attend, et ne revient pas.
2. **Le refus.** La porte arrête l'utilisateur en affirmant que sa clarté est
   basse. C'est une assertion sans preuve. Rien ne relie ce qui a été mesuré à
   ce que l'application vient de faire.
3. **La lecture continue.** Le cerveau porte déjà quatre grandeurs réelles —
   remplissage, plafond, agitation, jour. Aucune n'est nommée. L'utilisateur
   doit croire sur parole que l'application lit ses nuits.

## Décision de cadrage : pas de tableau de bord

Écartée délibérément, et cette décision prime sur tout ce qui suit.

Afficher les heures dormies, une courbe, un score, range Optium dans la
catégorie « application de sommeil » — où elle affronte Apple Santé, Oura et
Whoop, et où elle n'a rien à offrir de mieux. Ce qui la distingue est le refus,
pas la mesure.

La règle qui remplace le tableau de bord :

> **Une donnée n'apparaît que là où elle justifie une action, à l'instant où
> elle la justifie.**

Corollaires, à tenir :

- La valeur numérique de clarté reste invisible. Inchangé.
- Aucun écran nouveau. Les trois ajouts se posent sur des écrans existants.
- Aucun historique, aucune série temporelle, aucune moyenne affichée.
- Les faits montrés sont **mesurés**, jamais dérivés. « Tu as dormi 5 h 10 » est
  un fait ; « ta régularité est de 71 » est un score déguisé.

---

## 1. La justification à la porte

L'ajout le plus important du tronçon.

Quand la porte s'ouvre, une phrase apparaît sous le refus, avant les deux
issues. Elle énonce le fait mesuré qui pèse le plus dans la clarté basse.

### La règle de composition

`ClarityEngine` calcule trois composantes pondérées. La phrase cite **la
composante dont la contribution manquante est la plus grande** — celle qui, si
elle était au maximum, aurait le plus changé le résultat.

```
manque(composante) = poids × (1 − valeur_normalisée)
```

Une seule composante est citée. Deux, seulement si leurs manques sont à moins de
15 % l'un de l'autre, et jamais trois.

### Les formulations

Trois familles, une par composante. Les valeurs sont des exemples.

**Durée**
> Tu as dormi 5 h 10 cette nuit.

Sous 4 h ou au-dessus de 10 h, préciser que l'écart joue dans les deux sens :
> Tu as dormi 11 h 20 cette nuit — au-delà de ta cible, comme en deçà.

**Régularité**
> Tes trois derniers levers ont varié de 2 h 10.

Utiliser l'amplitude des levers observés sur la fenêtre courte, pas le SRI. Le
SRI est un score ; l'amplitude est un fait.

**Circadien**
> Il est 14 h 20 — ton creux de milieu de journée.

Le soir :
> Il est 23 h 40 — au-delà de ta fenêtre, qui s'est fermée à 19 h 10.

**Deux composantes**
> Tu as dormi 5 h 10, et tes trois derniers levers ont varié de 2 h 10.

### Ce que la phrase ne fait jamais

- Pas de conseil. Ni « dors plus », ni « reviens demain ».
- Pas de jugement. Ni « mauvaise nuit », ni « insuffisant ».
- Pas de nombre qui ressemble à un score : ni pourcentage, ni note, ni /100.
- Pas de cause. L'application mesure une corrélation de vigilance, elle
  n'explique pas pourquoi la nuit a été courte.

### Le cas sans donnée

**Si `clarity` est `nil`, la porte ne s'ouvre pas.** À rendre explicite dans
`closingOutcome`, qui prend aujourd'hui un `ClarityLevel` non optionnel : sans
mesure, il n'y a pas de refus justifiable, et un refus injustifié est pire
qu'une absence de refus.

Un test doit fixer ce comportement.

---

## 2. La légende du cerveau

Le cerveau affiche déjà quatre grandeurs réelles — le remplissage, la ligne de
plafond, l'agitation, le jour. Aucune n'est nommée. L'utilisateur voit une forme
bouger sans savoir ce qu'elle mesure, et doit croire sur parole que
l'application lit vraiment ses nuits.

Une légende de deux lignes se place sous le cerveau, sur l'accueil, en
permanence.

```
Nuit          6 h 40
Fenêtre       9 h 10 → 12 h 30
```

### La règle qui empêche la dérive vers le tableau de bord

**Seules figurent les grandeurs mesurées qui alimentent l'état affiché à cet
instant.** Pas de moyenne, pas de comparaison, pas de veille, pas de semaine.
Ce qui est écrit décrit le cerveau qu'on a sous les yeux, rien d'autre.

Concrètement, la distinction à tenir :

| Autorisé — une entrée mesurée | Interdit — une sortie calculée |
|---|---|
| `Nuit 6 h 40` | `Clarté 74` |
| `Fenêtre 9 h 10 → 12 h 30` | `Régularité 81` |
| `3 fils ouverts` | `Palier : 4e décile` |
| `2 cafés` | `Moyenne 7 h 05 sur 7 jours` |

La colonne de gauche est vérifiable par l'utilisateur dans Apple Santé. La
colonne de droite n'est vérifiable nulle part, et c'est ce qui la disqualifie.

### Les lignes

**Nuit** — durée du dernier sommeil observé, au format `6 h 40`. Absente si
aucune nuit n'a été mesurée depuis 36 h.

**Fenêtre** — bornes de la fenêtre du jour, au format `9 h 10 → 12 h 30`. Quand
elle est passée : `Fenêtre fermée à 12 h 30`, en teinte secondaire.

**Café** — n'apparaît qu'à partir d'une prise, au format `1 café` / `2 cafés`.
Rien à zéro : une ligne à zéro est un reproche.

**Fils** — le nombre de fils ouverts, qui pilote l'agitation, au format
`3 fils ouverts`. N'apparaît qu'au-delà de deux, seuil à partir duquel
l'agitation devient visible sur le maillage.

Maximum quatre lignes, jamais plus. Typographie secondaire, chiffres tabulaires,
alignés à droite. La légende ne doit pas concurrencer le mot de clarté, qui
reste l'élément principal de l'écran.

### La ligne de plafond

Elle reste non chiffrée — sa valeur est dérivée, pas mesurée. Elle s'explique
au toucher : un appui sur le cerveau fait apparaître une phrase pendant environ
quatre secondes, en fondu.

> La ligne marque ce que ta nuit permet aujourd'hui.

Quand le remplissage l'atteint :

> Tu es au plafond que ta nuit permet.

Sans nuit mesurée, la ligne est absente et l'appui ne fait rien. Déclencher au
`tap`, jamais au `drag`, pour ne pas entrer en conflit avec la rotation.

---

## 3. L'arrivée — ce que voit quelqu'un sans données

Le vrai sujet. L'application ne peut pas fonctionner avant d'avoir observé
quelques nuits, et ce délai doit devenir lisible au lieu d'être un vide.

**Principe : ne rien simuler.** Aucune donnée d'exemple, aucun cerveau rempli au
hasard, aucun écran de démonstration. Ce que l'application montre est vrai, y
compris quand ce qu'elle a à dire est « je ne sais pas encore ».

### Le cerveau à l'arrivée

Contour seul, remplissage nul, pas de ligne de base. Il respire — la surface
bouge déjà. L'objet est présent, il n'est pas encore renseigné.

### La phrase d'attente, à la place du mot de clarté

> Optium lit tes nuits pour savoir quand tu peux décider.
> **Deux nuits observées sur trois.**

Le compte est réel : nombre de `RecordedNight` distinctes sur les sept derniers
jours, plafonné à trois. C'est la donnée que tu voulais montrer à l'arrivée, et
elle est honnête : elle mesure le remplissage de l'application elle-même.

Trois nuits est le seuil minimal pour qu'une amplitude de levers ait un sens.
En dessous, la clarté reste `nil` et la porte reste fermée.

### Ce qui reste utilisable dès la première minute

L'utilisateur peut ouvrir des fils, les reprendre, les fermer, noter un café.
**Tout fonctionne, sauf le refus.** L'application n'est pas bloquée en attendant
ses données — elle est seulement muette sur la clarté.

### Le franchissement du seuil

À la troisième nuit, la clarté apparaît pour la première fois. C'est le moment
d'expliquer ce qui vient de changer, une seule fois :

> Optium a assez observé. À partir de maintenant, il t'arrêtera si tu essaies
> de trancher une décision quand tes nuits ne le permettent pas.

Une phrase, sur l'accueil, effacée au premier geste. Marquée comme vue dans les
réglages, jamais réaffichée.

### HealthKit refusé

Cas distinct de « pas encore de données », et à ne pas confondre.

> Optium a besoin de tes données de sommeil pour fonctionner. Sans elles, il
> reste un carnet de fils.

Avec l'accès aux réglages système. L'application continue de fonctionner comme
carnet, sans clarté ni porte, indéfiniment. Pas de relance, pas de rappel.

---

## 4. Les paliers — à trancher, hors périmètre d'implémentation

Signalé ici parce que c'est le principal obstacle restant à la compréhension,
mais **rien ne doit être implémenté sans arbitrage**.

Les cinq paliers — Cristallin, Limpide, Net, Voilé, Trouble — n'ont aucun ordre
intuitif. Sans le tableau sous les yeux, personne ne sait si *Net* est au-dessus
ou en dessous de *Limpide*. C'est un lexique, pas une échelle.

L'application demande déjà d'apprendre une douzaine de termes inventés : fil,
reprise, clarté, fenêtre, porte, palier, retenue, plus six preuves. Chacun se
défend seul ; ensemble ils forment une langue à apprendre avant de pouvoir se
servir de l'outil.

Deux directions, à choisir :

- **Garder cinq paliers, rendre l'ordre visible.** L'emblème porte déjà un
  remplissage croissant — l'afficher systématiquement à côté du nom rend
  l'échelle lisible sans changer le vocabulaire. Coût faible, gain partiel.
- **Descendre à trois paliers.** Aligne le vocabulaire du palier sur celui de la
  clarté, déjà en trois niveaux. Fait disparaître deux mots à apprendre. Coût :
  la répartition de population change, les seuils sont à recalculer, et la
  granularité se perd.

Recommandation : la première pour ce tronçon, la seconde à reconsidérer si
l'incompréhension persiste en usage réel.

---

## 5. Le cerveau des widgets — capture 3D plutôt que silhouette

Les widgets affichent aujourd'hui `BrainSilhouette`, 59 points extraits du
maillage. C'est correct, mais plat : l'objet perd le verre, la profondeur et le
niveau de liquide qui font l'identité de l'application sur l'écran principal.

Le remplacer par une **capture du rendu Metal** est possible, mais pas partout.

### Ce qui empêche de le faire partout

WidgetKit n'exécute pas Metal — déjà acté. La capture doit donc être produite
par l'application, écrite dans le groupe d'applications, et seulement affichée
par l'extension.

S'y ajoute une contrainte moins connue : **les widgets de l'écran verrouillé
sont rendus comme des masques teintés.** Une image en couleurs y est aplatie, et
un cerveau photographique y deviendrait une tache. Depuis iOS 18, l'écran
d'accueil connaît lui aussi un mode teinté qui désature les images.

D'où la répartition, à respecter :

| Emplacement | Rendu | Pourquoi |
|---|---|---|
| `systemSmall`, `systemMedium` | **capture 3D** | pleine couleur, place suffisante |
| `accessoryCircular`, `accessoryRectangular` | silhouette vectorielle | rendus en masque teinté |
| Live Activity, Dynamic Island | silhouette vectorielle | taille et teinte contraintes |

`BrainSilhouette` **n'est donc pas supprimé.** Il reste le rendu de l'écran
verrouillé, et le repli de l'écran d'accueil — voir plus bas.

Sur l'écran d'accueil en mode teinté, appliquer
`.widgetAccentedRenderingMode(.fullColor)` à l'image pour conserver les
couleurs. À vérifier sur appareil : si le rendu reste désaturé, basculer sur la
silhouette dans ce mode.

### La production de la capture

L'application rend le cerveau hors écran, dans une passe Metal identique à celle
de l'accueil, avec **fond transparent** — le widget dessine son propre fond, et
la transparence évite d'avoir à produire une variante claire et une variante
sombre.

Écriture dans le **conteneur du groupe d'applications**, via
`FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`. Pas dans
`UserDefaults` : celui-ci n'est pas fait pour des binaires, et
`WidgetSnapshot.save()` y écrit déjà du JSON qu'il ne faut pas alourdir.

Deux tailles, rendues au même moment :

| Fichier | Taille de rendu | Usage |
|---|---|---|
| `brain-small.png` | 158 × 158 pt × 3 | `systemSmall` |
| `brain-medium.png` | 158 × 158 pt × 3 | `systemMedium` |

Une seule taille de source suffit : le cerveau occupe un carré dans les deux
familles. Rendre à 474 px de côté et laisser SwiftUI redimensionner.

**Le budget mémoire des extensions widget est étroit** — de l'ordre de 30 Mo,
dépassement égale terminaison. Une image de 474 px décodée pèse environ 900 Ko,
ce qui laisse de la marge, mais interdit de monter en résolution « pour voir ».

### Le moment du rendu

La capture est produite **au même instant que `WidgetSnapshot`**, dans le même
chemin de code, puis `WidgetCenter.shared.reloadTimelines` est appelé. Image et
valeurs sont ainsi cohérentes par construction.

### La péremption, et le repli

Le remplissage évolue au fil de la journée par la composante circadienne, alors
que l'image reste figée depuis la dernière exécution de l'application. Un cerveau
en décalage avec le mot affiché juste à côté serait pire que pas de cerveau.

`WidgetSnapshot` gagne donc deux champs :

```swift
/// Le remplissage grave dans la derniere capture.
var brainImageFill: Double?
/// L'instant du rendu.
var brainImageRenderedAt: Date?
```

Règle d'affichage, dans la vue du widget :

```
si  brainImageFill existe
et  |entree.fill − brainImageFill| < 0.03
et  entree.date − brainImageRenderedAt < 6 h
alors  afficher la capture
sinon  afficher la silhouette vectorielle
```

Le repli est silencieux : aucune indication de péremption, l'utilisateur voit
simplement l'autre représentation du même objet. C'est précisément pourquoi les
deux doivent rester le même objet, comme le rappelle §8 d'AGENTS.md.

### Vérification

- Le fichier est écrit dans le conteneur du groupe, jamais dans `UserDefaults`.
- Aucune capture n'est produite quand la clarté est absente : à l'arrivée, le
  widget montre la silhouette vide.
- La règle de repli renvoie bien la silhouette au-delà de 0,03 d'écart, et
  au-delà de six heures.
- Les familles `accessory*` n'ouvrent jamais le fichier image.

---

## Vérification

Tests à ajouter, dans l'esprit des 69 existants.

**La porte**
- `closingOutcome` ne renvoie jamais `.gate` quand la clarté est absente.
- Les six tests existants (trois natures × trois niveaux) restent inchangés.
  **Ne pas les affaiblir.**

**La justification**
- La composante citée est bien celle dont le manque pondéré est le plus grand,
  sur chacune des trois composantes prise isolément.
- Deux composantes ne sont citées que si l'écart de manque est sous 15 %.
- Jamais trois composantes.
- La phrase ne contient ni pourcentage, ni note, ni le mot « clarté ».

**La légende**
- Aucune ligne n'affiche une grandeur dérivée : ni clarté, ni régularité, ni
  palier, ni moyenne.
- La ligne café est absente à zéro.
- La ligne fils est absente à deux fils ou moins.
- La légende ne dépasse jamais quatre lignes.

**L'arrivée**
- Le compte de nuits est plafonné à trois et ne recule pas en cours de journée.
- La clarté reste absente sous trois nuits, quelle que soit la qualité des
  nuits observées.
- La phrase de franchissement n'apparaît qu'une fois.

## Hors périmètre

- Tout tableau de bord, tout historique, toute courbe.
- L'affichage de la valeur numérique de clarté.
- Toute modification de la condition d'ouverture de la porte.
- Toute modification de la pondération du moteur.
- L'apprentissage par la calibration, déjà noté comme non fait.
- La suppression de `BrainSilhouette` : elle reste le rendu de l'écran
  verrouillé et le repli de l'écran d'accueil.
- Le rendu Metal dans une extension widget, que WidgetKit n'autorise pas.
