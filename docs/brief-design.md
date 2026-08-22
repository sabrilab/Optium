# Optium — brief de direction artistique

Document autonome, à coller tel quel dans un outil de design.
Dernière mise à jour : 2026-08-22.

---

## Le produit

Optium est une application Pomodoro pour iPhone. Trois onglets :

- **Session** — le minuteur, écran principal, celui qu'on regarde 25 minutes
  d'affilée. Une scène 3D y occupe le haut de l'écran : un cerveau en verre
  dont le fluide intérieur descend au fil de la session et remonte pendant la
  pause.
- **Projets** — des projets contenant des tâches, chaque tâche estimée en
  nombre de sessions. Toucher une tâche démarre une session dessus.
- **Statistiques** — concentration du jour, série de jours consécutifs,
  moyennes, histogramme des 14 derniers jours.

Plus un écran **Réglages** en feuille modale.

## Contexte technique — ce qui contraint le design

L'application est **native SwiftUI, iOS 26**. Ce n'est pas du web ni du React
Native. Trois conséquences directes :

1. **Le Liquid Glass d'Apple est utilisé partout** (`glassEffect`,
   `GlassEffectContainer`, `buttonStyle(.glass)`). Les panneaux, boutons et
   pastilles sont du vrai verre système, avec sa réfraction et ses animations.
   **À conserver** — c'est un choix explicite, pas un placeholder.
2. **La scène 3D est rendue en Metal**, avec des shaders faits main. Le cerveau
   est un maillage unique de 76 000 sommets, coque en Fresnel et fluide animé.
   On peut changer sa taille, sa position, ses couleurs — pas en faire un
   objet 2D ni une illustration.
3. **Les contrôles restent ceux du système** (`Toggle`, `Stepper`, `List`,
   `Menu`, `TabView`). Un contrôle redessiné perdrait le retour haptique,
   l'accessibilité et les animations d'Apple. On habille la surface, pas les
   mécanismes.

## Le langage visuel établi

### Fond

- **Noir vrai** (`#000000`), permanent. L'application ne suit pas l'apparence
  d'iOS : il n'y a pas de mode clair. La scène 3D, les auras et les cartes
  n'existent que sur du noir.
- Le noir porte une **trame de points** : points de 1,7 pt, espacés de 17 pt,
  blanc à 8,5 % d'opacité. Sans elle le noir est un vide — rien n'y donne
  l'échelle et les cartes flottent sur rien. On ne la voit pas, on la sent.

### Les cartes — le point le plus important

Chaque carte est **remplie de couleur bord à bord, avec un cœur sombre**. La
lumière semble venir de derrière la surface. Composition exacte :

1. remplissage plein de la teinte, opacité `0.72 × intensité` ;
2. un dégradé radial **noir** centré à `(0.50, 0.62)` — sous le centre, pas au
   centre — de rayon `max(largeur, hauteur) × 0.68`, avec les arrêts :
   noir 100 % → 96 % à 26 % → 74 % à 48 % → 34 % à 72 % → transparent à 100 % ;
3. l'**arête supérieure rallumée** dans la seconde teinte : dégradé linéaire du
   haut, 60 % → 22 % à 22 % de la hauteur → transparent à 52 %, en `plusLighter` ;
4. un **second foyer** décalé en `(0.82, 0.14)`, seconde teinte à 40 %, rayon
   `max × 0.50`, en `plusLighter` ;
5. flou de 22 pt sur l'ensemble, agrandi à 1,3 avant d'être clipé à la forme ;
6. par-dessus, le verre système.

**Rayons de coin** : 28 pour les cartes courantes, 30 pour les projets, 34 pour
la carte héros des statistiques, 36 pour la carte du minuteur.

### Couleurs

Une seule famille par mode. La hiérarchie se fait **par la valeur, jamais par
la teinte** : une carte secondaire est plus sombre, pas d'une autre couleur.

| Rôle | Valeur |
|---|---|
| Concentration, proche | `#5253F0` |
| Concentration, lointaine | `#8A4ADD` |
| Pause, proche | `#16A596` |
| Pause, lointaine | `#28769C` |
| Accent | `#D6E85D` |
| Commandes | blanc |

**Intensités** : carte héros 1,0 · cartes secondaires 0,62 · tertiaires 0,42 ·
cartes de projet 0,46.

L'accent `#D6E85D` est la **seule couleur franche de l'application**. Il ne
signale qu'une chose : le présent. Le jour courant dans l'histogramme, le
repère de l'échelle de progression, la pastille d'une tâche terminée. Il ne
doit jamais servir de décoration.

**Couleurs de projet** — huit teintes tenues, une par projet :
`#5B5BD6` `#7C5CD6` `#A855C4` `#C0567F` `#B5654A` `#8E8244` `#3E8F7C` `#3F7BA8`.
Elles apparaissent à pleine saturation dans une **pastille de 8 pt** à côté du
nom, et seulement à 46 % dans le lavis de la carte.

### L'afficheur du minuteur

Chiffres dessinés en **matrice de points 5 × 7**, façon afficheur à diodes.
Points de 7,5 pt, pas de grille de 11,5 pt, espace entre glyphes de 1,6 cran.
Les points éteints restent visibles à 4 % — c'est ce qui fait lire « afficheur »
et non « police pointilliste ». Halo coloré sur les points allumés.

Deux détails de lisibilité chèrement acquis : le zéro n'a **pas** de barre
diagonale (elle le fait hésiter avec un huit), et le un porte un **empattement**
(sans base il flotte à côté d'un sept).

### La progression

Pas une barre pleine : une **échelle à graduations**. 48 traits de 1,5 pt de
large, 8 pt de haut, portés à 14 pt tous les six crans. Un repère de tête de
2,5 × 20 pt en accent, avec halo. Une barre indique une proportion ; des
graduations donnent une échelle, donc une lecture du temps qui reste.

### L'histogramme

Traits de 2 pt, sans arrondi, blanc à 30 %, le jour courant en accent. Pas
d'axes, pas de grille, pas de fond.

### Typographie

- Grands titres : `largeTitle` système (gras).
- Étiquettes de section : `caption2` semi-gras, **en capitales**, interlettrage
  1,4 à 1,6.
- Valeurs numériques : 30 pt medium, chiffres tabulaires.
- Textes courants : `body`, `subheadline`, `footnote`, `caption` — les tailles
  d'Apple, pour que Dynamic Type fonctionne.
- Libellés de bouton : `subheadline` medium, **blancs**.

## Ce qu'il ne faut pas proposer

Chacun de ces points a été essayé puis retiré. Les réintroduire ferait revenir
en arrière :

- **Un mode clair**, ou des couleurs qui s'inversent selon l'apparence système.
- **Plusieurs familles de teintes sur un même écran.** Vert, violet, bleu et
  orange côte à côte : c'est ce qui faisait le plus « généré ».
- **Un aplat saturé pour le bouton principal.** Un grand rond bleu vif est le
  réflexe par défaut. Le verre suffit à désigner l'action principale dès lors
  qu'elle est la plus large de la rangée.
- **Des dégradés linéaires** sur les cartes. L'œil en devine la direction, la
  carte se lit comme un remplissage.
- **Des dégradés radiaux dont la retombée n'atteint pas les bords** : ils
  dessinent une tache au milieu au lieu de traverser la carte.
- **Des barres d'histogramme épaisses et arrondies** — un graphe de tableau de
  bord générique. Un trait fin est une mesure.
- **Une teinte de couleur sur chaque bouton.** Elle dilue l'unique couleur
  franche de l'application.

## Ce sur quoi le regard est attendu

Deux pistes identifiées et non traitées :

1. **La grille bento est régulière** — deux colonnes égales sur toute la
   hauteur. Les références qui ont nourri cette direction (Veri, Toss, les
   applications de suivi respiratoire) mélangent les formats : une carte large,
   deux carrées, une haute et étroite. C'est ce déséquilibre qui donne le
   rythme, et c'est probablement le gain restant le plus visible.
2. **Les grands titres sont en gras système**, alors que les références sont en
   graisse légère — ce qui change beaucoup le caractère.

Et plus largement : l'écran Session est celui qu'on regarde le plus longtemps.
Il est aujourd'hui composé du haut vers le bas — titre, scène, carte du
minuteur — ce qui est correct mais convenu.

## Contraintes à respecter dans toute proposition

- Cibles tactiles de **44 pt minimum**.
- Textes en **français**.
- Portrait uniquement.
- Le contraste doit tenir : ces cartes sont sombres et les textes secondaires y
  sont déjà à la limite.
