# Hooked, et ce qu'Optium peut en faire

Résumé du modèle de Nir Eyal et Ryan Hoover (*Hooked: How to Build
Habit-Forming Products*, 2014), puis application à Optium.

Document d'analyse, pas une spécification : **rien ici n'est à implémenter en
l'état.** Il existe pour permettre un arbitrage éclairé.

Réserve de méthode : ce résumé est écrit de mémoire du texte, pas avec
l'ouvrage sous les yeux. Le modèle, les expériences citées et le vocabulaire
sont fidèles ; aucune pagination n'est donnée, et les formulations ne sont pas
des citations.

---

## Première partie — le modèle

Un *hook* est une boucle en quatre temps. Parcourue assez souvent, elle
transforme un comportement en habitude, c'est-à-dire en action faite avec peu
ou pas de réflexion consciente.

```
Déclencheur ──▶ Action ──▶ Récompense variable ──▶ Investissement
      ▲                                                  │
      └──────────────────────────────────────────────────┘
```

Le bouclage est l'essentiel : l'investissement charge le déclencheur suivant.

### 1. Le déclencheur

**Déclencheurs externes** — une information dans l'environnement qui dit quoi
faire ensuite. Quatre familles :

| Famille | Exemple | Ce qu'elle vaut |
|---|---|---|
| Payé | publicité | achète du trafic, jamais une habitude |
| Gagné | presse, mise en avant App Store | coûteux à entretenir, non pilotable |
| Relationnel | bouche-à-oreille, invitation | le plus efficace, le moins contrôlable |
| Possédé | icône, notification, widget, e-mail | le seul qui ramène de façon répétée |

Les déclencheurs possédés supposent un consentement : l'utilisateur a installé,
autorisé, épinglé. C'est ce qui les rend renouvelables.

**Déclencheurs internes** — le vrai objectif. Une émotion, une situation ou une
routine s'associe au produit par la mémoire, jusqu'à ce que le produit devienne
la réponse automatique. Eyal insiste : les émotions **négatives** sont les
déclencheurs internes les plus puissants — ennui, solitude, frustration,
confusion, indécision, peur de manquer.

La bascule externe → interne est ce qui distingue un produit utilisé d'un
produit installé dans la vie de quelqu'un.

Méthode proposée pour trouver le déclencheur interne : les **cinq pourquoi** de
Toyota, appliqués à un utilisateur décrit nommément plutôt qu'à un segment.

### 2. L'action

Le comportement le plus simple accompli dans l'attente d'une récompense.

**Le modèle de Fogg : B = MAT.** Un comportement (*Behavior*) survient quand
motivation, capacité (*Ability*) et déclencheur (*Trigger*) coïncident **au même
instant**. Si le comportement n'a pas lieu, au moins l'un des trois manque.

Les trois motivations fondamentales, selon Fogg : rechercher le plaisir et fuir
la douleur ; rechercher l'espoir et fuir la peur ; rechercher l'acceptation
sociale et fuir le rejet.

La capacité se décompose en six ressources ; **c'est la plus rare chez cet
utilisateur, à cet instant, qui gouverne** :

1. le temps
2. l'argent
3. l'effort physique
4. les cycles cérébraux — l'effort mental
5. la déviance sociale — à quel point l'acte est accepté autour de soi
6. le non-routinier — à quel point il rompt les habitudes existantes

**Le principe central : augmenter la capacité plutôt que la motivation.**
Simplifier est fiable ; motiver ne l'est pas.

Eyal ajoute des leviers cognitifs qui amplifient l'action : effet de rareté,
effet de cadrage, effet d'ancrage, et **effet de progrès doté** — une carte de
fidélité offerte avec deux cases déjà tamponnées est complétée bien plus
souvent qu'une carte vierge plus courte.

### 3. La récompense variable

Le cœur du livre.

Une récompense variable satisfait le besoin **tout en laissant vouloir
davantage**. La variabilité n'est pas un ornement : c'est le mécanisme.

Les appuis expérimentaux qu'il mobilise :

- **Olds et Milner** — les rats se stimulant le noyau accumbens ; l'interprétation
  retenue par Eyal est que le circuit sert l'*anticipation*, non le plaisir.
- **Schultz** — chez le singe, la dopamine monte à l'attente de la récompense,
  et **s'éteint quand la récompense devient prévisible**.

D'où la règle : une récompense certaine cesse de produire du désir.

**Les trois types — la taxonomie à retenir.**

**Récompenses de la tribu.** Le social : validation, empathie, reconnaissance,
compétition, coopération. Fondées sur l'apprentissage social. Les « j'aime », la
réputation Stack Overflow, les classements.

**Récompenses de la chasse.** La quête d'une ressource ou d'une information. La
machine à sous, le fil qui défile, la trouvaille imprévisible. Ce qui compte
n'est pas l'objet trouvé mais **l'incertitude du prochain**.

**Récompenses du soi.** La maîtrise, la compétence, la complétion, la cohérence.
Intrinsèques : personne ne regarde. Vider sa boîte de réception, monter d'un
niveau, terminer un module. S'appuie sur l'**effet Zeigarnik** — une tâche
inachevée occupe l'esprit jusqu'à sa clôture.

**Trois mises en garde, souvent oubliées :**

- **Préserver l'autonomie.** Le sentiment d'être manipulé déclenche une
  réactance qui tue l'habitude. Eyal cite la technique du « mais vous êtes
  libre » (Guéguen et Pascual) : rappeler explicitement la liberté de refuser
  augmente l'acceptation.
- **Variabilité finie contre infinie.** Une série télévisée a une fin : sa
  variabilité s'épuise. Un contenu produit par les utilisateurs se renouvelle
  sans limite. Les produits à variabilité finie doivent se réinventer sans cesse.
- **Récompenser la bonne chose.** Une récompense désalignée du *pourquoi* de
  l'utilisateur casse la boucle. Eyal donne Mint : montrer de l'argent sans
  donner de prise dessus n'a pas suffi.

### 4. L'investissement

L'utilisateur dépose quelque chose : du temps, des données, un effort, du
capital social, de l'argent. Trois biais expliquent l'effet :

1. **Nous surévaluons notre propre travail** — l'effet IKEA (Norton, Mochon,
   Ariely) : un meuble assemblé soi-même est jugé plus précieux qu'un meuble
   identique monté d'avance.
2. **Nous cherchons la cohérence avec nos actes passés** — un petit engagement
   accepté en prépare un plus grand.
3. **Nous fuyons la dissonance cognitive** — nous finissons par aimer ce dans
   quoi nous avons investi.

L'investissement produit de la **valeur stockée** : contenu, données,
abonnés, réputation, savoir-faire. Contrairement à un bien matériel, le service
**s'améliore à l'usage** — ce qui rend le départ coûteux.

Et surtout, l'investissement **charge le déclencheur suivant**. D'où la règle de
séquence, la plus opérationnelle du livre :

> **Demander l'investissement après la récompense, jamais avant.**

### 5. La matrice de manipulation

Le chapitre d'éthique. Deux questions, quatre positions :

| | Améliore matériellement la vie | Ne l'améliore pas |
|---|---|---|
| **Le concepteur l'utilise** | **Facilitateur** | **Amuseur** |
| **Il ne l'utilise pas** | **Colporteur** | **Trafiquant** |

Le facilitateur est la seule position confortable. L'amuseur est légitime mais
doit se réinventer sans cesse. Le colporteur échoue le plus souvent, faute de
comprendre l'utilisateur. Le trafiquant est indéfendable.

### 6. Le test d'habitude

Trois temps, à mener sur des données réelles :

1. **Identifier** — qui sont les utilisateurs habituels ? Définir « habituel »
   par un chiffre propre au produit, pas par intuition.
2. **Codifier** — retrouver le *chemin d'habitude* : la suite d'actions que ces
   utilisateurs-là ont accomplie et les autres non.
3. **Modifier** — amener les nouveaux venus sur ce chemin.

Deux notions complémentaires :

- **La zone d'habitude.** Un comportement devient habitude au croisement d'une
  fréquence suffisante et d'une utilité perçue élevée. Un comportement rare doit
  compenser par une utilité très supérieure.
- **Vitamines et antidouleurs.** Les habitudes transforment les vitamines en
  antidouleurs : la douleur naît de l'absence du produit.

---

## Deuxième partie — Optium au regard du modèle

### Ce qui existe déjà, sans avoir été nommé

C'est le constat principal : **le squelette des trois récompenses est en place.**

| Récompense | Ce qui la porte aujourd'hui | État |
|---|---|---|
| Chasse | les six preuves — Retenue, Fenêtre, Traversée, Régulier, Matin, Sobriété | existe, non mise en scène |
| Soi | le cerveau qui se remplit, le palier sur cinq niveaux | existe, la plus aboutie |
| Tribu | l'ancrage UK Biobank — situé dans une population de 60 977 personnes | existe, sous-exploité |

Et la variabilité est **réelle, non fabriquée** : elle vient du sommeil, que
l'utilisateur ne contrôle qu'en partie. C'est une position rare. La plupart des
produits simulent l'incertitude ; Optium en hérite d'une vraie.

### Le déclencheur interne, déjà juste

Le déclencheur interne d'Optium n'est pas l'ennui — c'est **le doute avant de
valider**. « Est-ce que je suis sûr ? » Cette émotion est précise, elle est
négative, et elle correspond exactement à la thèse du produit.

Conséquence : Optium ne cherche pas la fréquence, il cherche la coïncidence avec
un moment rare et important. C'est plus difficile à installer, mais l'utilité
perçue à ce moment-là est bien plus haute.

La surface de déclencheurs possédés est déjà construite : widgets, écran
verrouillé, Dynamic Island, raccourcis Siri.

### L'action, déjà optimale — et c'est le problème

`B = MAT` : la capacité est maximale, puisque **tout est lu**. Aucun effort, aucun
cycle cérébral, aucune rupture de routine.

Mais une action nulle produit un investissement nul. **C'est la faiblesse
structurelle d'Optium au regard du modèle** : une application à laquelle on ne
donne rien est une application qu'on quitte sans rien perdre.

La seule valeur stockée réelle aujourd'hui : les fils écrits et les lignes de
fermeture. C'est peu, et ce n'est pas mis en avant.

### Le conflit à trancher

Le moteur de Hooked récompense **la fréquence d'usage**. La charte d'Optium
l'interdit explicitement :

> « Pas de série à ne pas briser. Aucun mécanisme de culpabilisation. »
> « Toutes les preuves récompensent la retenue, jamais le volume — un test ferme
> cinquante fils à la chaîne sans rien débloquer, et il doit rester vrai. »

Ce n'est pas rédhibitoire, mais cela impose la version difficile : **des
récompenses variables qui ne récompensent pas l'usage.** Optium peut récompenser
le *résultat* — la régularité du sommeil, la retenue — et non le passage dans
l'application.

Position dans la matrice de manipulation : **facilitateur**, tant que les
mécanismes récompensent le résultat. Le jour où ils récompensent l'ouverture de
l'app, le produit glisse vers l'amuseur.

---

## Troisième partie — recommandations

### Ce que je retiendrais

**1. Les preuves grisées, critères visibles.** Les six preuves affichées en
permanence, éteintes tant qu'elles ne sont pas acquises, **avec leur critère
écrit**. La variabilité ne vient pas d'un secret — elle vient du sommeil, qui
n'obéit pas. C'est une récompense de la chasse honnête : on sait ce qu'on
cherche, on ignore quand on l'atteindra.

Cacher le critère serait le réflexe de game design habituel. Ce serait ici une
faute : le produit repose sur la confiance dans une mesure.

**2. La trajectoire, pas la promesse.** « À ce rythme, tu passes Net dans six
jours. » Récompense du soi, et effet Zeigarnik : une progression entamée
appelle sa clôture. À condition de rester une projection, jamais un engagement —
une prévision démentie coûte plus que l'absence de prévision.

**3. La comparaison sans personne.** L'ancrage UK Biobank est déjà une
récompense de la tribu qui respecte la règle « jamais de personnes, jamais le
volume ». Elle mérite d'être montrée davantage : se situer parmi 60 977 nuits
réelles est plus fort qu'un classement entre amis, et infiniment moins toxique.

**4. Déplacer l'investissement après la récompense.** La ligne de fermeture
écrite à la porte est le seul vrai investissement du produit — et elle arrive
déjà au bon endroit : après le soulagement. C'est conforme au livre sans l'avoir
cherché. À renforcer plutôt qu'à multiplier : cette ligne devrait se relire,
s'accumuler, constituer un objet dont on ne se sépare pas.

C'est aussi la réponse à l'idée d'assemblage : ce qui se construit dans Optium,
ce ne sont pas des briques décoratives, c'est **un corpus de décisions assumées**.

### Ce que je refuserais

- **Les séries de jours.** Déjà interdites par la charte, et pour une bonne
  raison : elles récompensent l'usage et punissent l'absence.
- **Toute notification conçue pour ramener.** Un déclencheur possédé qui ne
  porte pas d'information utile est une nuisance, et la première cause de
  désinstallation.
- **Le cadrage par la perte.** « Tu vas perdre ton palier » est le levier le
  plus efficace et le plus contraire au produit.
- **Toute récompense déclenchée par l'ouverture de l'application.**

### Le risque qu'il faut nommer

**L'orthosomnie.** Documentée par Baron et coll. (*Journal of Clinical Sleep
Medicine*, 2017) : la poursuite anxieuse d'un bon score de sommeil, entretenue
par un traceur, **dégrade** le sommeil qu'elle prétend améliorer.

Optium coche toutes les cases du risque : il mesure le sommeil, il en tire un
palier, et il propose de progresser. Rendre la progression désirable augmente
mécaniquement ce risque.

Deux garde-fous, à décider avant d'ajouter quoi que ce soit :

- Ne jamais rendre le palier atteignable par un effort du soir même. La médiane
  glissante sur 28 jours joue déjà ce rôle — la conserver est une protection,
  pas seulement une décision statistique.
- Rendre la redescente silencieuse. Un palier perdu ne doit produire aucune
  notification, aucune couleur d'alerte, aucune formulation de perte.

---

## Ce qu'il reste à décider

1. Va-t-on mettre en scène les trois récompenses déjà présentes, ou seulement
   les nommer ?
2. Accepte-t-on d'augmenter l'investissement demandé — donc de dégrader
   légèrement la capacité, à rebours du principe de Fogg — pour créer de la
   valeur stockée ?
3. La trajectoire projetée entre-t-elle en conflit avec « le plan se périme, il
   ne réprimande pas » ?

Une spécification ne devrait être écrite qu'après ces trois réponses.
