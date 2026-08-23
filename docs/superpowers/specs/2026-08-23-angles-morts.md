# Les angles morts — rendre le mécanisme visible sans l'expliquer

Date : 2026-08-23
Statut : spécification, arbitrages tranchés par l'auteur

## Le problème

L'application calcule beaucoup de choses justes et n'en montre presque
aucune. Trois formes d'angle mort, dans l'ordre de gravité :

1. **Une donnée est enregistrée et jamais relue.** `Resumption.clarityAtStart`
   est écrit à chaque reprise (`Model/WorkThread.swift:115`) et n'alimente
   aucune surface : ni le journal, ni les preuves, ni les outils de l'appel.
2. **Un effet est visible mais sa cause est muette.** Le cerveau s'agite en
   fonction du nombre de fils ouverts (`Home/HomeScreen.swift:49`). Personne
   ne peut deviner le lien.
3. **Une conséquence est calculée mais jamais rapprochée de l'acte.**
   `LandingEstimator` divise par `openThreads` : ouvrir un fil déplace la date
   d'atterrissage. L'utilisateur voit la date, jamais le déplacement.

Le réflexe naturel est d'ajouter des phrases explicatives. C'est le mauvais
réflexe, et l'application en porte déjà trop : elle demande d'apprendre une
douzaine de termes inventés avant de servir à quoi que ce soit.

## Le principe

> **L'application n'explique pas ses règles, elle les montre en train de
> s'appliquer** — et, quand c'est possible, *avant* que l'acte soit commis.

Chaque point ci-dessous remplace une phrase par une forme. Le texte restant
est réduit à ce qu'aucune forme ne peut porter : un delta chiffré, un mot.

## Ce qu'il ne faut pas faire

**Aucune de ces mesures ne doit devenir un refus.** La porte est le seul refus
de l'application, elle porte sur les décisions à clarté basse, et sa rareté
est ce qui la rend supportable (`Model/WorkThread.swift:98`). Ajouter une
porte à l'ouverture d'un fil, ou désactiver un bouton parce que l'atterrissage
recule, détruirait le produit. **Tout ce qui suit renseigne. Rien n'empêche.**

---

## 1. Les paliers — cinq rangs, trois bandes

**Arbitrage de l'auteur** : on garde les cinq paliers, et on les range dans
trois bandes.

Le problème restait entier : *Cristallin, Limpide, Net, Voilé, Trouble* n'ont
aucun ordre intuitif. Sans le tableau sous les yeux, personne ne sait si *Net*
est au-dessus ou en dessous de *Limpide*.

Le regroupement, tiré de la répartition UK Biobank déjà présente dans
`Tier.populationShare` :

| Bande | Paliers | Part de la population |
|---|---|---|
| haute | Cristallin (14 %), Limpide (23 %) | 37 % |
| médiane | Net (26 %) | 26 % |
| basse | Voilé (22 %), Trouble (15 %) | 37 % |

**Les bandes ne portent pas de nom, et ne doivent pas en porter.** C'est tout
l'intérêt : elles donnent l'ordre par la position, sans ajouter de vocabulaire.
Les nommer « basse / moyenne / haute » créerait une seconde échelle à trois
crans à côté de celle de la clarté, qui ne mesure pas la même chose — les deux
seraient confondues.

### Le composant : `TierLadder`

Une échelle de cinq barreaux. L'écart entre deux bandes est plus large que
l'écart entre deux barreaux d'une même bande — c'est ce seul écart qui fait
lire les trois groupes, sans trait ni étiquette.

- Le barreau occupé : plein, teinté `Ink.marker`, avec le halo habituel.
- Les autres : creux, `white.opacity(0.16)`, comme les graduations non
  franchies de `TickScale`.
- L'emblème `BrainMark(fill: tier.fill)` se pose à hauteur du barreau occupé.
- Le mot du palier reste, une seule fois, à côté de son barreau.

Ajouter à `Tier` :

```swift
/// L'indice de bande, 0 (basse) à 2 (haute). Volontairement sans mot :
/// la bande se lit à sa position sur l'échelle, jamais à son nom.
var band: Int {
    switch self {
    case .crystalline, .limpid: 2
    case .clear: 1
    case .veiled, .murky: 0
    }
}
```

À placer partout où le palier apparaît : `JournalScreen` (remplace le couple
mot + emblème actuel), `ExhibitCard` dans l'appel, et le widget — qui ne
reçoit aujourd'hui que `tierWord`, donc aucune échelle.

### Bug à corriger dans la foulée

`Call/ExhibitCard.swift:90` :

```swift
BrainMark(fill: Tier(rawValue: word.lowercased())?.fill ?? 0.6, tint: Ink.marker)
```

`word` est le libellé français (« Cristallin »), les `rawValue` sont les cas
anglais (`crystalline`). La reconstruction renvoie donc **toujours `nil`** et
l'emblème affiche `0.6` quel que soit le palier réel. Le cas `.tier` de
`Exhibit` doit transporter le `Tier`, pas son libellé d'affichage.

---

## 2. Ouvrir un fil — montrer le coût avant de le payer

C'est la réponse à « qu'est-ce que ça veut dire, ouvrir plusieurs fils ». Ça
veut dire deux choses exactement, et l'application sait déjà les calculer :
**le cerveau s'agite d'un cran de plus**, et **l'atterrissage recule**.

Dans `ThreadComposer`, au-dessus du bouton « Ouvrir le fil », une bande vive
qui montre l'état d'après :

- **À gauche**, deux cerveaux miniatures côte à côte : l'agitation actuelle
  `min(1, threads.count / 5)` et celle d'après `min(1, (threads.count + 1) / 5)`.
  Même `BrainView`, hauteur réduite. Le second bouge visiblement plus.
- **À droite**, deux segments sur un même axe de dates : la fourchette
  d'atterrissage actuelle et celle obtenue en rappelant `LandingEstimator`
  avec `openThreads: threads.count + 1`. Le second segment dépasse.
  Le décalage s'écrit en `DotMatrixText` — `+3 J` — et c'est le seul texte.

Quatre règles, aucune négociable :

0. **La bande ne s'affiche qu'à l'ouverture, jamais à la modification.**
   `ThreadComposer` sert désormais aux deux (`var editing: WorkThread?`).
   Modifier la phrase d'un fil déjà ouvert n'ajoute aucun fil : montrer un
   coût à ce moment-là serait faux. Condition : `editing == nil`.

1. **Le bouton n'est jamais désactivé** et ne change pas d'apparence. Aucune
   couleur d'alerte, aucun rouge, aucun point d'exclamation.
2. **La bande disparaît quand il n'y a rien à montrer** — pas d'historique
   fermé, donc pas d'atterrissage, donc pas de segment. Se taire vaut mieux
   qu'inventer, comme partout ailleurs dans l'application.
3. **Elle se met à jour en direct** pendant qu'on choisit la nature et le
   projet. C'est ce qui la fait lire comme un instrument et non comme un
   avertissement.

Et sur l'écran d'accueil, au retour du compositeur : l'agitation du cerveau
passe à sa nouvelle valeur **en animation** (`withAnimation(Motion.state)`),
pas par saut. Deux ou trois répétitions suffisent à faire apprendre la
relation. Symétriquement à la fermeture d'un fil, où le cerveau se calme.

---

## 3. La nature — rendre la porte prévisible

Choisir « Décision » est le seul geste qui arme le refus de l'application. Il
est aujourd'hui traité comme les deux autres : un bouton radio et une légende.
La porte arrive donc toujours par surprise, ce qui est le contraire de ce
qu'on veut d'un mécanisme qu'on demande aux gens d'accepter.

**Un sceau**, et il porte trois faits à lui seul :

- Il apparaît dès que « Décision » est sélectionnée dans le compositeur → *ce
  fil peut m'arrêter*.
- Il reste sur la `ThreadRow` du fil, dans la liste → *lequel de mes fils peut
  m'arrêter*.
- **Il est vif quand la clarté est basse, éteint sinon** → *aujourd'hui, il
  m'arrêterait*.

Symbole : `Image(systemName: "door.left.hand.closed")`, qui est le vocabulaire
même du produit — introduit avec SF Symbols 4, donc disponible ; **le vérifier
dans le catalogue Xcode avant de s'en servir**, et retomber sur
`rectangle.portrait` s'il manquait. Éteint : `white.opacity(0.3)`. Vif : `Ink.marker` avec
`.symbolEffect(.pulse)`. La transition entre les deux états suit le jour, pas
une action — c'est une propriété du monde, pas un retour d'interface.

C'est le gain de lisibilité le plus fort de toute cette liste : il transforme
un refus subi en un refus annoncé, sans écrire une phrase de plus.

---

## 4. Les reprises — la trace plutôt que le compte

`ThreadRow` affiche « 3 reprises ». Le nombre ne dit rien : trois reprises en
un après-midi et trois reprises étalées sur quatre nuits sont deux histoires
opposées.

**`ResumptionTrace`** — une marque par reprise, de gauche à droite, dans le
vocabulaire de graduations déjà établi par `TickScale` :

- La **hauteur et le remplissage** de la marque encodent `clarityAtStart` :
  haute → grande et pleine avec halo ; moyenne → moyenne ; basse → courte et
  creuse. C'est ici, et seulement ici, que le champ mort reprend vie.
- Un **écart plus large** là où une nuit a été traversée.
- La reprise en cours, s'il y en a une, est en `Ink.marker`.

Ce que ça produit : d'un coup d'œil, on voit qu'un fil a été repris cinq fois,
presque toujours en clarté basse, sur trois nuits. **La trace ne juge pas,
elle décrit** — et c'est précisément pour ça qu'elle est lisible sans phrase.
Une ligne de marques courtes et creuses se comprend seule.

Ne rien écrire à côté. Surtout pas « tu travailles souvent en clarté basse ».

---

## 5. Le plafond — cesser de dépendre d'un appui

`brainBase` est la ligne qui marque ce que la nuit permet. Son explication
n'existe qu'au toucher, quatre secondes (`HomeScreen.explainBase`). Personne
ne découvre une interaction qui ne se signale pas.

Deux ajouts, aucun textuel :

- Un **repère permanent** à l'extrémité droite de la ligne — une simple
  encoche — pour que l'œil la lise comme un objet et non comme un artefact de
  rendu.
- Quand `brainFill >= brainBase - 0.02`, **la ligne s'éclaircit et le
  remplissage vient la toucher**. « Tu es au plafond » devient une chose qu'on
  voit au lieu d'une chose qu'on lit.

La phrase au toucher reste, en seconde couche.

---

## 6. La fenêtre — y poser les reprises

`WindowStrip` montre où l'on en est dans la fenêtre du jour. Elle ne montre
pas ce qu'on y a fait, alors que `Resumption.inWindow` est enregistré et ne
sert aujourd'hui qu'à la preuve « Fenêtre ».

Poser sur la même échelle une **marque basse par reprise entamée
aujourd'hui**, à sa position réelle dans la fenêtre. Le repère de tête reste
le présent, en `Ink.marker` — la règle du brief est inchangée : l'accent ne
signale que le présent.

La bande dit alors deux choses au lieu d'une : où j'en suis, et où j'ai
travaillé. La question « est-ce que j'utilise ma fenêtre » se répond sans que
personne l'ait posée.

---

## Ordre d'implémentation

1. Le bug d'`ExhibitCard` — c'est une correction, pas une fonctionnalité.
2. `TierLadder` et `Tier.band` — arbitrage tranché, périmètre fermé.
3. `ResumptionTrace` — ressuscite `clarityAtStart`, ne touche à aucune règle.
4. Le sceau de la porte — le plus fort, mais il touche deux écrans.
5. La bande du compositeur — la plus délicate, parce que c'est celle qui peut
   basculer en friction si elle est mal faite. À faire en dernier, et à
   supprimer sans regret si elle se met à ressembler à un avertissement.
6. Le plafond et la fenêtre — deux finitions.

## Ce qui n'est pas tranché

Faut-il un cinquième outil d'appel qui lise le croisement nature × clarté au
démarrage, pour que le cerveau puisse dire « tes décisions démarrent presque
toujours en clarté basse » ? La donnée existera dès le point 4. La question
est de savoir si l'appel doit la porter, ou si la trace par fil suffit. À
éprouver en usage réel avant de décider.
