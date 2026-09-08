# Optium — bible de contenu

Document de référence pour la distribution : ce qu'est le produit, pourquoi il
existe maintenant, ce qu'on a le droit d'en dire, et comment le filmer.

Il ne décrit pas une intention. Il décrit ce qui est **construit et vérifiable
dans le dépôt** au 2026-09-08 — 128 fichiers Swift, ~16 400 lignes, 267 tests.
Toute affirmation de cette bible doit pouvoir être montrée à l'écran.

---

## PARTIE I — CE QU'ON VEND

### La phrase

> **Optium lit ton sommeil et refuse de te laisser trancher une décision quand
> tu n'es pas en état de la trancher.**

Pas de minuteur. Pas de liste de tâches. Pas de tableau de bord.

### La catégorie : un instrument, pas un assistant

C'est la clé de tout le positionnement, et elle règle la moitié des questions
de ton.

Un **assistant** te pousse, te rappelle, t'encourage, te félicite. Il veut que
tu fasses plus. Toutes les applications de productivité sont des assistants,
et c'est pour ça qu'elles se ressemblent.

Un **instrument** ne veut rien. Un baromètre ne t'encourage pas à sortir. Un
altimètre ne te félicite pas de monter. Tu le consultes, il te renseigne, tu
décides.

Optium est un instrument. Trois conséquences directes, toutes déjà dans le
code :

- **Elle ne demande jamais rien.** Un seul geste déclaratif dans toute
  l'application : noter un café. Tout le reste est lu.
- **Elle n'a aucun impératif.** Aucun texte de l'interface ne dit « fais ».
- **Le plan se périme, il ne réprimande pas.** Ce qui n'est pas fait glisse en
  silence.

Ce ton doit tenir dans les vidéos aussi. **Optium ne fait jamais la leçon.**
Une vidéo qui dit « arrête de bosser fatigué » a déjà trahi le produit.

### Les deux verbes

Toute l'application tient dans deux gestes, et il n'y en aura pas de
troisième :

| | |
|---|---|
| **Elle t'arrête** | la porte |
| **Tu l'appelles** | le cerveau, un appel vocal, entièrement sur l'appareil |

### Les trois refus qui définissent le produit

Ce ne sont pas des manques. Ce sont des positions, et chacune est un angle de
communication à part entière.

1. **Pas de minuteur de 25 minutes**, même en option. L'application *était* un
   Pomodoro. Elle a pivoté le 2026-08-22 et ce code a été supprimé.
2. **Pas de tableau de bord, pas de pourcentage.** La clarté est calculée de 0
   à 100 et **le nombre n'est jamais affiché** — l'interface montre un mot :
   basse, moyenne, haute. Un « 74 % de capacité cognitive » n'est pas
   justifiable et s'approche d'un diagnostic.
3. **Pas de série à ne pas briser.** Aucun mécanisme de culpabilisation, aucun
   score global. Le risque d'orthosomnie — transformer le sommeil en
   performance à optimiser, et le dégrader ce faisant — est traité comme réel.

### Ce que ça implique au quotidien

C'est ce qu'il faut montrer, parce que c'est ce que les gens vivront.

**Au réveil.** L'application ne dit rien d'utile, et c'est volontaire :
l'inertie du réveil dure de trente minutes à deux heures. La règle du jour
montre déjà la forme de la journée à venir.

**Quand la fenêtre s'ouvre.** Une notification, une seule : *« Ta fenêtre
s'ouvre à 9 h 40. »* Elle ne pousse pas, elle annonce. Les heures suivent le
chronotype appris de l'heure de lever réelle — elles se déplacent seules quand
les habitudes changent.

**Au creux de l'après-midi.** Le sceau s'allume sur les fils marqués
« Décision ». Il ne dit pas d'arrêter. Il dit : *maintenant, il m'arrêterait.*
Le refus cesse d'être une surprise.

**Au moment de trancher.** Si c'est une décision et que la clarté est basse,
la porte s'ouvre. Écran plein cadre, sans carte — la seule rupture visuelle de
toute l'application, et cette rupture *est* le message. Deux issues, aucune
n'est un abandon : fermer en écrivant ce qu'on accepte, ou retenir jusqu'à la
prochaine fenêtre.

**Au rebond du soir.** Le sceau s'éteint. La même décision passe. **Ce n'est
pas l'application qui a changé d'avis — c'est toi qui as changé d'état.**

**Le lendemain.** Le café noté hier après 14 h a pesé sur la nuit, donc sur la
clarté d'aujourd'hui — jamais sur celle d'hier. C'est un enseignement, pas une
punition.

---

## PARTIE II — POURQUOI MAINTENANT

Trois arguments. Le premier est culturel, le deuxième scientifique, le
troisième concurrentiel. Ils se renforcent.

### 1. L'exécution est devenue gratuite. Le jugement est devenu le goulot.

C'est l'angle le plus fort de 2026, et il ne demande **aucune fonctionnalité
nouvelle** — c'est la description de ce qui existe déjà.

Rédiger, coder, résumer, traduire : l'IA fait tout ça pour presque rien. Ce
qui reste entièrement humain, c'est **décider** — trancher, valider, dire oui.

Et décider est précisément la fonction qui casse en premier quand on dort mal.

> Optium n'améliore pas ce que l'IA produit.
> **Il vérifie que l'humain qui valide est en état de valider.**

Positionnement : la couche *sous* les outils d'IA, pas un outil d'IA de plus.

### 2. Ce que dit la littérature, et ce qu'elle contredit

Tout ce qui suit est sourcé dans le dépôt (`docs/etudes-fondements.md`,
`AGENTS.md` §4-5). **Ne jamais avancer un chiffre qui n'y figure pas.**

**Le récit courant est faux.** On répète que le fatigué se croit performant. La
revue systématique de Bermudez et coll. (*Sleep Medicine Reviews*, 2021, 28
études) trouve l'inverse : les personnes privées de sommeil donnent des
estimations **plus conservatrices** de leur performance.

**Ce qui se dégrade vraiment**, c'est la détection de ses propres erreurs. La
seule formulation soutenue, et celle à répéter partout :

> **On ne devient pas aveugle à sa fatigue.
> On devient moins capable d'attraper ses propres erreurs.**

**C'est un argument plus fort pour la porte, pas plus faible.** Si le problème
était l'ignorance, une notification suffirait. Le problème est qu'on peut
parfaitement savoir qu'on est fatigué et rater l'erreur quand même. Savoir ne
suffit pas : il faut une interruption **au moment de conclure**.

**La régularité prime sur la durée.** Windred et coll. (*Sleep*, 2023, doi
10.1093/sleep/zsad253) sur 60 977 participants de la UK Biobank : l'indice de
régularité du sommeil prédit mieux la mortalité que la durée — et il se corrige
plus facilement. Médiane 81, interquartile 73,8–86,3. C'est ce qui fonde le
poids le plus lourd du moteur, et c'est ce qui résout le démarrage à froid :
un utilisateur du premier jour se situe déjà par rapport à soixante mille
personnes.

**La journée a une forme, et une mauvaise nuit la creuse.** Modèle à deux
processus : la pression du sommeil monte depuis le réveil, le rythme circadien
oscille sur 24 h et **continue d'osciller même sous forte pression**. D'où le
creux d'après-midi et le rebond du soir. Et l'amplitude croît avec la
pression : mal dormir ne rend pas la journée uniformément mauvaise, **ça creuse
l'écart entre la meilleure et la pire heure**. Le *quand* compte davantage, pas
moins.

**Ce qu'on ne prédit pas, et qu'il ne faut jamais promettre.** L'effet de
synchronie — performer mieux à l'heure de son chronotype — est contesté
(Rey-Mermet & Rothen, *Collabra: Psychology*, 2023). La résolution du modèle
est de l'ordre de ±2 heures, pas de la minute.
**On prédit la forme et l'ordre. Jamais l'heure exacte, jamais un chiffre.**

**Pourquoi seulement la durée et les horaires.** Les validations 2024 contre
polysomnographie donnent, pour les montres grand public : sommeil contre éveil
au-dessus de 95 % de sensibilité, durée totale à ±12 minutes — mais sommeil
profond entre 50 et 64 % seulement. Optium ne lit que ce que ces appareils
mesurent bien. **C'est un argument de rigueur, et il se raconte.**

### 3. Le terrain est libre, mais pas partout

**Apple a pris la nuit.** Depuis iOS 26, le Sleep Score note chaque nuit sur la
durée, la régularité du coucher et les interruptions. C'est le même plat que le
palier d'Optium, avec de meilleurs capteurs et gratuitement.

**Ce terrain est perdu, et le perdre n'est pas grave.** Ce qu'Apple ne fera
jamais, structurellement :

- Apple note **la nuit qui est passée**. Optium affirme quelque chose sur
  **l'heure où tu es**.
- Apple ne **refusera jamais rien**. Health est descriptif par conception et
  prudent par obligation. Aucun constructeur ne dira « ne ferme pas cette
  décision maintenant ».
- Apple ne sait pas **sur quoi tu travailles**.

> Apple est le capteur et l'historien. **Optium est l'interprète et l'arbitre.**

Et Apple qui s'améliore rend Optium meilleur : l'application lit HealthKit.
Chaque progrès de leur suivi est une amélioration gratuite de son entrée.

**Le Pomodoro traite la surface.** Il découpe le temps. Il ne demande jamais
dans quel état est la personne qui découpe. Trois essais randomisés en tout sur
la technique, et le seul comparatif ne lui donne pas l'avantage.

---

## PARTIE III — LES ANGLES

Sept angles, du plus fort au plus faible. Chacun porte : ce qu'on affirme, ce
qui le prouve, ce qu'on montre, et le risque.

### A1 — « Ton app de productivité ne t'a jamais demandé si tu avais dormi »

- **Affirmation** : toute la catégorie optimise le temps et ignore l'état.
- **Preuve** : le Pomodoro découpe le temps ; Optium lit le sommeil.
- **Visuel** : un minuteur qui tourne / le cerveau qui se remplit et se vide.
- **Format** : 8–15 s, vertical, sans voix.
- **Risque** : aucun. C'est le meilleur point d'entrée grand public.

### A2 — Le refus filmé

- **Affirmation** : elle t'arrête, vraiment.
- **Preuve** : la porte, en plein cadre, avec sa justification tirée d'un fait
  vérifiable dans Santé.
- **Visuel** : on tape « Fermer le fil », l'écran change de nature. Rupture.
- **Format** : 10 s. Le retour haptique précède l'écran — la main sait qu'on
  l'arrête avant que l'œil ait lu pourquoi. **Le son compte.**
- **Risque** : ne jamais formuler le refus comme un ordre. Elle propose deux
  issues, aucune n'est un abandon.

### A3 — La journée au doigt

- **Affirmation** : ta clarté n'est pas un verdict, c'est une courbe.
- **Preuve** : le glissement sur la règle du jour ; le cerveau se remplit et se
  vide en suivant.
- **Visuel** : **le meilleur plan de toute l'application.** Il démontre et il
  enseigne en trois secondes, sans une phrase.
- **Format** : 6–10 s, plan unique, doigt visible.
- **Risque** : aucun. À décliner en boucle, en fond, en fin de vidéo.

### A4 — Deux nuits, même heure

- **Affirmation** : une mauvaise nuit ne supprime pas les bons moments, elle
  creuse l'écart.
- **Preuve** : le rebond du soir vaut plus après une mauvaise nuit qu'après une
  bonne — c'est mesuré, pas affirmé.
- **Visuel** : deux règles côte à côte, même heure, sommets différents.
- **Format** : 15–20 s, comparatif.
- **Risque** : ne pas laisser croire que mal dormir serait un avantage.

### A5 — « L'IA écrit. Toi, tu décides. »

- **Affirmation** : l'exécution est gratuite, le jugement est le goulot.
- **Preuve** : l'appel vocal connaît la clarté et peut refuser d'aider à
  trancher.
- **Visuel** : l'appel, le halo, la voix qui dit non.
- **Format** : 20–30 s. Le plus partageable des sept.
- **Risque** : c'est l'angle le plus « intellectuel ». À réserver au format
  long ou à une audience déjà acquise.

### A6 — La rigueur comme spectacle

- **Affirmation** : cette app refuse d'afficher ce qu'elle ne peut pas prouver.
- **Preuve** : le nombre n'est jamais montré ; les stades de sommeil sont lus
  mais jamais exploités parce qu'ils sont mal mesurés ; l'application publie
  son propre taux d'erreur.
- **Visuel** : l'écran des fondements, l'écran de justesse.
- **Format** : 30–60 s, long, YouTube.
- **Risque** : ennuyeux si mal fait. Public de niche, mais fidèle.

### A7 — La démonstration de fabrication

- **Affirmation** : voilà comment c'est construit.
- **Preuve** : Metal, Foundation Models sur l'appareil, zéro donnée sortante.
- **Format** : long, YouTube, audience développeurs.
- **Risque** : n'amène pas d'utilisateurs finaux. À utiliser pour la crédibilité
  et les liens, pas pour les installations.

---

## PARTIE IV — LA GRAMMAIRE VIDÉO

Les vidéos se font avec **les composants de l'interface**, dans Remotion. Ce
n'est pas une contrainte, c'est l'avantage : le mécanisme *est* le contenu.

### La règle unique

> **On ne raconte pas le mécanisme. On le montre en train de s'appliquer.**

Pas de voix qui explique par-dessus une capture. L'objet réagit, on filme la
réaction. Si une vidéo a besoin d'une phrase pour être comprise, le plan est
mauvais.

### Les jetons (source : `ios-native/Shared/Ink.swift`, `docs/brief-design.md`)

| | |
|---|---|
| fond | `#000000` — noir nu, **jamais de mode clair** |
| surface | `#131315` |
| effort / focus | `#5253F0` → `#8A4ADD` |
| repos / récupération | `#16A596` → `#28769C` |
| **accent** | `#D6E85D` — **signale le présent, jamais la décoration** |
| critique | `#E0574F` |

**La hiérarchie se fait par la valeur, jamais par la teinte.** Intensités :
héros 1,0 / secondaire 0,62 / tertiaire 0,42.

**La teinte a le droit de porter un moment ou un sens de variation. Jamais un
classement.**

### Les objets filmables

| Objet | Ce qu'il dit | Emploi vidéo |
|---|---|---|
| **Le cerveau en volume** (Metal) | combien | le sujet, plein cadre |
| **La règle du jour** | quand | le plan signature, au doigt |
| **Le sceau de la porte** | ce fil peut m'arrêter, et maintenant il le ferait | le plan de tension |
| **L'échelle des paliers** | où l'on se situe — 5 barreaux, 3 bandes | le plan de contexte |
| **La trace des reprises** | l'histoire d'un fil | le plan de preuve |
| **Les graduations** (`TickScale`) | une échelle, pas une proportion | transitions, fonds |
| **Les chiffres matriciels** 5×7 | l'identité | les seules données à l'écran |

Le zéro n'a **pas** de barre. Le un **a** un empattement. Ne pas les redessiner.

### Ce qui n'apparaît jamais à l'écran

- Un pourcentage, un score, une note de clarté.
- Une heure de pic annoncée.
- Un mode clair.
- Un impératif.
- Un visage qui explique. Le produit est muet ; la marque l'est aussi.

### Les formats

- **Vertical 8–20 s** — le mécanisme, un plan, une idée. Deux par jour.
- **Vertical 30–45 s** — un comparatif ou un angle.
- **YouTube 3–8 min** — la théorie, la science, la fabrication. C'est
  l'actif durable : une vidéo qui se référence continue de livrer des années,
  et le catalogue finit par dépasser les nouvelles publications vers le
  sixième mois.

---

## PARTIE IV bis — LE VERRE, POUR DE VRAI

Le code vit dans `remotion/`. Cette section dit ce qui est vérifié et ce qui
ne l'est pas.

### La bonne nouvelle : Remotion est le meilleur endroit pour ce matériau

`backdrop-filter: url(#filtre-svg)` avec un `feDisplacementMap` — la seule
technique qui produise une vraie réfraction de bord — se comporte ainsi :

| | |
|---|---|
| **Chromium** | supporté ✅ — et c'est ce que Remotion rend |
| **Safari** | bug ouvert sur `feDisplacementMap` en `backdrop-filter` (WebKit 245510) |
| **Firefox** | aucun filtre SVG en `backdrop-filter` |

Autrement dit : **le verre sera plus vrai dans tes vidéos que sur ton propre
site.** Vérifié ici, en Chromium headless — la grille derrière la carte se
courbe réellement.

### Ce qui est délicat

La réfraction crédible ne vient pas du filtre, elle vient de **la carte de
déplacement** : neutre (128,128) au centre, rampe concentrée dans la bande du
bord, normale sortante correcte dans les coins. Composer des dégradés SVG ne
marche pas — les modes de fusion cassent le neutre — et l'alignement carte /
région de filtre est piégeux (`primitiveUnits`, viewport de l'hôte SVG).

Le calcul est fourni dans `remotion/src/Glass.tsx` (`lensDisplacementMap`).
Pour la production, **utiliser une bibliothèque maintenue** plutôt que de
réécrire :

- `PallavAg/liquid-glass-web-react` — génère la carte à la volée
- `dpawlikowski/liquid-glass` — CSS + SVG, aberration chromatique
- `LeonardSEO/liquid-glass-react` — carte PNG statique, ~5 ko
- `nikdelvin/liquid-glass` — conteneurs, texte, boutons

### Les deux règles qu'on oublie

**1. Le verre sur du noir nu ne montre rien.** Il n'y a rien à réfracter. Dans
l'application il fonctionne parce qu'il est posé sur le cerveau en Metal ou
sur l'aura. En vidéo, même règle : **jamais de verre sur un fond plat.** C'est
la tension réelle entre le brief — noir nu, pas de mode clair — et ce
matériau.

**2. Le speculaire fait plus de travail que la réfraction.** L'arête
supérieure rallumée et les flancs portent l'essentiel de la lecture « c'est du
verre ». La réfraction est ce qui la rend vivante quand le fond bouge. Sur un
plan fixe, le repli sans réfraction suffit — et il n'a aucune dépendance.

### Et la vérité sur le « vrai » verre

Le verre le plus vrai pour une vidéo n'est pas une réimplémentation : c'est
**un enregistrement d'écran de l'application réelle**, qui utilise le vrai
`UIGlassEffect` d'iOS 26. Remotion compose autour.

Une réimplémentation en React restera toujours une approximation — utile pour
les scènes synthétiques, jamais supérieure à la source. Pour les plans où le
verre est le sujet, **filmer l'app.** Pour les plans où il est un décor,
réimplémenter.

### Le rendu

    npx remotion render --gl=angle-egl Scene out/video.mp4

`--gl=angle-egl` active le GPU : en headless, Chromium le désactive par
défaut, et `backdrop-filter` est une opération de composition coûteuse.

---

## PARTIE V — CE QU'ON NE DIT JAMAIS

Deux raisons : l'honnêteté, et le rejet App Store. Une allégation de santé fait
basculer la fiche en catégorie médicale.

| Interdit | Pourquoi | À la place |
|---|---|---|
| « Sait quand tu es trop fatigué pour décider » | allégation de santé | « Lit un indicateur de régularité du sommeil » |
| « Améliore ta concentration de X % » | invérifiable | « Montre la forme de ta journée » |
| « Ton pic est à 10 h 47 » | la résolution est de ±2 h | « Ta fenêtre est plus étroite aujourd'hui » |
| « Tu ne remarques plus que tu te trompes » | **contredit par la littérature** | « Tu attrapes moins tes propres erreurs » |
| « Détecte la fatigue » / « diagnostique » | vocabulaire médical | « lit », « mesure », « situe » |
| « Optimise ton sommeil » | orthosomnie | « observe tes nuits » |

**Ne jamais promettre une performance. Toujours décrire une lecture.**

---

## PARTIE VI — LA DISTRIBUTION AUJOURD'HUI

### L'état réel : zéro

Rien n'existe encore, et il faut le dire clairement pour ne pas se raconter
d'histoires.

- Pas de compte Apple Developer. **Rien ne se publie sans.**
- Pas de politique de confidentialité — obligatoire dès qu'on lit HealthKit.
  Absente, et aucun `PrivacyInfo.xcprivacy` dans le dépôt.
- Pas de StoreKit, pas de paywall.
- Pas d'inscription au Small Business Program — sans elle Apple prend 30 % au
  lieu de 15 %.
- Pas de chaîne, pas de fiche App Store, pas de page.
- **267 tests jamais exécutés.** Leur existence n'est pas leur réussite.
- **Zéro utilisateur**, y compris l'auteur sur plusieurs semaines consécutives.

### Ce que le volume de recherche dit, et ne dit pas

« pomodoro » : 833 500 recherches mondiales, 135 000 aux États-Unis,
difficulté 100, CPC 1,63 $.

- **Ce qui est vrai et exploitable** : le problème n'a pas besoin d'être
  expliqué. Des centaines de milliers de personnes le cherchent déjà.
- **Difficulté 100** : la première page Google en résultats web est hors de
  portée. Cette porte-là est fermée.
- **Mais YouTube est un moteur de recherche.** Une vidéo se positionne dans sa
  recherche interne *et* dans le bloc vidéo de Google — deux portes que la
  difficulté 100 ne verrouille pas.
- **60 500 de ces recherches concernent la sauce tomate.**
- Une grosse part de la demande YouTube « pomodoro » cherche **la vidéo
  elle-même** — minuteurs de 25 minutes, *study with me*, lofi. Vues énormes,
  intention d'installation quasi nulle. **La requête qui rapporte n'est pas
  « pomodoro timer »** : c'est le champ des questions autour, où la réponse est
  le produit et pas une vidéo de 25 minutes.

### L'ordre

1. **Utiliser l'application soi-même trois semaines**, avec ses vraies nuits.
   Aucun contenu ne vaut ce que ça apprendra.
2. Compte Apple Developer, politique de confidentialité, Small Business
   Program, StoreKit. Exécuter les 267 tests.
3. Trente vidéos, pour mesurer les vues par vidéo — la seule hypothèse
   vraiment fragile du modèle de revenus.
4. Le paywall, une fois qu'on sait si les gens reviennent au huitième jour.

### Le seul chiffre qui compte

Ni les notes, ni les vues, ni les « waouh » de démonstration.

> **Combien de personnes ont ouvert l'application le jour 8.**

Le produit exige trois nuits avant de dire quoi que ce soit : il est
structurellement mauvais en démonstration instantanée et structurellement bon
sur la durée. Tant qu'on ne mesure que la démonstration, on ne mesure rien.
