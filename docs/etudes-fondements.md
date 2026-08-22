# Ce que disent les études

Vérification des fondements scientifiques d'Optium, menée le 2026-08-22.

Objectif : séparer ce que la littérature soutient, ce qu'elle conteste, et ce
qu'elle **contredit** — y compris quand cela contredit une formulation déjà
inscrite dans les documents du projet.

Niveau de vérification indiqué pour chaque point : *texte intégral lu*,
*résumé lu*, ou *rapporté par une source secondaire*.

---

## 1. Le résultat qui fonde le produit

### Ce qui lâche : la détection de ses propres erreurs

> Bermudez et coll., *Sleep Medicine Reviews*, 2021 — revue systématique et
> méta-analyse, 28 études retenues, 11 exploitables en méta-analyse.
> *Résumé lu.*

Deux conclusions distinctes, et il faut les tenir séparées :

- **La détection d'erreur est dégradée** après une privation de sommeil. La
  littérature est décrite comme « plus constante » sur ce point, et la
  méta-analyse confirme la revue.
- **L'estimation de sa propre performance**, en revanche, ne donne pas de
  consensus — les méthodes diffèrent trop.

**Le point qui corrige le récit habituel.** On répète partout que le fatigué se
croit performant. La revue dit l'inverse : les participants privés de sommeil
donnent typiquement des estimations **plus conservatrices** de leur performance.
Ils ne se surestiment pas ; ils détectent moins bien leurs erreurs.

Une revue systématique distincte (*Metacognition and Learning*, 2017) va dans le
même sens : la privation aiguë de courte durée n'affecte pas le jugement
métacognitif capté par les scores de confiance. *Résumé lu.*

### Ce que cela impose au produit

La formulation à retenir :

> **On ne devient pas aveugle à sa fatigue. On devient moins capable
> d'attraper ses propres erreurs.**

C'est un argument **plus fort** pour la porte, pas plus faible. Si l'utilisateur
savait simplement qu'il est fatigué, une notification suffirait. Le problème est
qu'il peut parfaitement le savoir et rater quand même l'erreur — donc savoir ne
suffit pas, il faut une interruption au moment de conclure.

**Correction à apporter.** Toute formulation du type « tu ne remarques plus que
tu te trompes » doit devenir « tu attrapes moins tes propres erreurs ». La
première est contredite, la seconde est soutenue.

---

## 2. La vigilance, pas l'intelligence — confirmé

> Lim & Dinges, *Psychological Bulletin*, 2010 — 70 articles, 147 tests.
> Déjà cité dans `ios-native/AGENTS.md`.

Effets les plus grands sur les lapsus d'attention simple ; les plus faibles, non
significatifs, sur l'exactitude du raisonnement.

**Le cadrage « qualité de l'esprit critique » reste interdit.** En revanche
« fiabilité du contrôle qualité » est exactement soutenu par le point 1 : c'est
la détection d'erreur, pas le raisonnement.

---

## 3. L'appétit au risque — déplacé, pas augmenté

> Revue de portée, 2025 — 25 articles, 2 276 participants.
> *Rapporté par source secondaire.*

La privation dégrade la décision, et beaucoup d'études rapportent davantage de
choix risqués. **Mais la direction n'est pas stable** : elle dépend du sexe, du
cadrage en gain ou en perte, de la durée de privation, de la prise de
psychotropes.

**À dire « déplacé », jamais « augmenté ».** La formulation actuelle du schéma
de la page — « appétit au risque déplacé » — est juste et doit le rester.

---

## 4. La composante circadienne — terrain contesté

L'effet de synchronie — mieux performer à l'heure qui correspond à son
chronotype — est largement admis et soutenu par plusieurs travaux sur la
fonction exécutive et la décision affective. *Résumé lu.*

**Mais il est disputé.** Un article de *Collabra: Psychology* (2023) conclut à
l'absence de gain cognitif général et robuste issu du croisement heure du jour ×
chronotype, et évoque la possibilité d'un artefact méthodologique.
*Résumé lu.*

**Conséquence pour le moteur.** La composante circadienne pèse 25 % de la
clarté. C'est la brique la plus fragile des trois. Deux options :

- la conserver en l'assumant comme la moins fondée ;
- réduire son poids au profit de la régularité, qui est la mieux établie.

À trancher, mais pas à ignorer.

---

## 5. La régularité — la brique la mieux tenue

> Windred et coll., *Sleep*, 2023 — 60 977 participants, UK Biobank.
> Déjà cité dans le projet.

La régularité prédit mieux la mortalité que la durée. C'est ce qui justifie son
poids de 45 %, le plus élevé des trois. **Rien dans cette vérification ne
remet ce choix en cause** — c'est au contraire la composante la plus solide.

---

## 6. La mesure elle-même — la découverte la plus utile

> Validations 2024 de montres grand public contre polysomnographie, dont une
> étude sur 127 adultes (Apple Watch Series 8). *Rapporté par sources
> secondaires concordantes.*

| Ce qui est mesuré | Fiabilité |
|---|---|
| Sommeil contre éveil | sensibilité ≥ 95 % |
| Temps de sommeil total | erreur d'environ ± 12 minutes |
| Sommeil paradoxal | sensibilité ≈ 82 % |
| **Sommeil profond** | **sensibilité ≈ 50 à 64 %** |

**Optium ne lit que `asleepAt` et `wokeAt`** — donc la durée et les horaires,
c'est-à-dire précisément ce que ces appareils mesurent bien. Les stades, qu'ils
mesurent mal, ne sont jamais utilisés.

C'est un choix d'architecture qui se révèle juste après vérification, et il faut
le protéger : **ne jamais introduire de composante fondée sur les stades de
sommeil.** Ce serait bâtir sur la seule partie non fiable de la mesure.

Cela dit, une erreur de ± 12 minutes sur la durée se propage dans l'indice de
régularité. La médiane glissante sur 28 jours amortit ce bruit — encore une
décision qui se trouve fondée après coup.

---

## 7. Le Pomodoro — l'angle de contenu, maintenant sourcé

C'est le point stratégique : 833 500 recherches mensuelles dans le monde pour
« pomodoro », et une base de preuves étonnamment mince.

### La base de preuves est mince

Les revues récentes recensent environ 32 études pour 5 270 participants, dont
**seulement trois essais contrôlés randomisés**. *Rapporté par source
secondaire.*

### L'étude la plus tranchante

> Smits, Wenzel & de Bruin, *Behavioral Sciences*, 2025, 15(7), 861.
> DOI 10.3390/bs15070861 — 94 étudiants, session d'étude de deux heures.
> **Texte intégral lu.**

Trois conditions : pauses auto-régulées (n = 25), Pomodoro — 5 minutes après
25 minutes (n = 36), Flowtime (n = 33).

Résultats :

- **Achèvement des tâches** : aucune différence significative (p = 0,854)
- **Flow** : aucune différence significative (p = 0,774)
- **Fatigue** : « la fatigue a augmenté plus rapidement pour le groupe Pomodoro
  que pour le groupe auto-régulé »
- **Motivation** : les chances d'être à un niveau de motivation supérieur
  diminuaient d'environ 2 % de plus par minute pour le groupe Pomodoro

Conclusion des auteurs, citée : *« les niveaux de motivation diminuent plus vite
pour les étudiants utilisant les techniques Pomodoro et Flowtime que pour ceux
qui utilisent des pauses auto-régulées »*, et *« les étudiants ayant utilisé la
technique Pomodoro ont montré une augmentation plus marquée de la fatigue »*.

**La réserve, à énoncer systématiquement** : les auteurs précisent que ces
différences de pente n'ont **pas** produit de différences significatives sur les
moyennes globales. Échantillon de 94 étudiants, session de deux heures, contexte
scolaire. C'est un signal, pas une réfutation.

### Ce que cela autorise à dire, et ce que cela n'autorise pas

**Défendable :**

- « Trois essais contrôlés randomisés en tout. Pour une méthode que des
  centaines de milliers de personnes cherchent chaque mois. »
- « Dans le seul essai qui les compare, le Pomodoro ne bat pas le fait de faire
  une pause quand on en sent le besoin — la fatigue y monte même plus vite. »
- « Découper le temps ne dit rien de l'état dans lequel on l'aborde. »

**Non défendable :**

- « Le Pomodoro ne marche pas. » L'étude ne montre pas ça, et les moyennes
  globales ne diffèrent pas.
- Tout chiffre de pourcentage d'efficacité.

L'angle honnête n'est pas que le Pomodoro échoue. C'est qu'il **traite le
découpage du temps, et jamais l'état de celui qui l'occupe** — ce qui est
exactement l'espace qu'occupe Optium.

---

## 8. Corrections à porter dans le projet

1. **`ios-native/AGENTS.md`** — remplacer toute formulation d'inconscience de la
   fatigue par la détection d'erreur dégradée. Ajouter la référence de la
   méta-analyse 2021.
2. **La pondération** — écrire `0,5 / 0,3 / 0,2` plutôt que `0,45 / 0,30 / 0,25`.
   Les décimales actuelles annoncent une calibration qui n'existe pas ; la fausse
   précision est ce qui décrédibilise un moteur heuristique.
3. **La composante circadienne** — documenter qu'elle repose sur un effet
   contesté, ou réduire son poids.
4. **Une interdiction à inscrire** — aucune composante fondée sur les stades de
   sommeil, la mesure grand public n'étant fiable que sur la durée et les
   horaires.
5. **La phrase de la porte** — « tu attrapes moins tes propres erreurs » plutôt
   que toute variante impliquant l'inconscience.

## 9. Ce qui reste non vérifié

- Les travaux de Walker sur la déconnexion préfrontal-amygdale et la régulation
  émotionnelle : cités de mémoire dans les échanges, **non vérifiés ici**. À ne
  pas inscrire avant contrôle.
- L'orthosomnie (Baron et coll., 2017) : citée de mémoire, **non vérifiée dans
  cette session**. Le risque reste réel et le garde-fou pertinent, mais la
  référence doit être confirmée.
- Aucune donnée ne permet de dire qu'interrompre une décision à faible clarté
  améliore la qualité de cette décision. **C'est l'hypothèse centrale d'Optium,
  et elle n'est testée nulle part.** Aucune étude trouvée ne l'aborde.
