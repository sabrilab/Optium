# Optium — composants Remotion

Les objets de l'interface, portes a l'identique pour les videos.

**Source unique : `ios-native/Shared/Ink.swift` et `docs/brief-design.md`.**
Si une valeur diverge ici, les videos cessent de ressembler a l'application —
et c'est tout l'interet du dispositif qui tombe.

## Ce qu'il y a

| Fichier | Ce qu'il porte |
|---|---|
| `src/Ink.ts` | Les jetons, la recette de carte, `withAlpha` |
| `src/DotMatrix.tsx` | Les chiffres 5x7. Zero sans barre, un avec empattement |
| `src/Glass.tsx` | Le verre, et la carte de deplacement d'une lentille |
| `src/Film.tsx` | **Le film de 60 s**, sept plans, sous-titres compris |

## Le film

`src/Film.tsx` — vertical 1080 x 1920, 60 s a 30 images par seconde.

**Tout le rendu est une fonction pure du temps : `draw(ctx, t)`.** Aucune
animation CSS, aucun etat cache. C'est ce qui le rend deterministe : Remotion
appelle `draw` avec `frame / fps`, l'apercu du navigateur l'appelle avec
l'horloge, et les deux produisent exactement la meme image.

Le modele de vigilance est **le vrai**, repris de `Clarity/Vigilance.swift` :
la courbe que suit le liquide n'est pas decorative, c'est celle que
l'application calcule.

Le texte des sous-titres, dans `SHOTS`, **est le script de la voix off**, mot
pour mot. La voix se pose par-dessus ; le film tient sans elle.

> **Ce fichier n'a pas ete compile ici** — cet environnement n'a ni Remotion
> ni `tsc`. Il est syntaxiquement equilibre et le rendu a ete verifie image par
> image dans un navigateur, mais le premier `npx remotion studio` reste le
> premier vrai controle.

## Le verre : ce qui est verifie, et ce qui ne l'est pas

**Verifie** : `backdrop-filter: url(#filtre)` avec `feDisplacementMap`
fonctionne dans Chromium — donc dans Remotion. Safari a un bug ouvert dessus
(WebKit 245510) et Firefox ne le supporte pas du tout. **Remotion est donc le
meilleur endroit ou faire ce materiau, meilleur qu'un navigateur.**

**Non verifie de bout en bout** : obtenir une refraction de qualite Apple a la
main. Le calcul de la carte est juste (`lensDisplacementMap`), mais
l'alignement carte / region de filtre est piegeux. Pour la production,
utiliser une bibliotheque maintenue plutot que de reecrire :

- `PallavAg/liquid-glass-web-react` — genere la carte a la volee
- `dpawlikowski/liquid-glass` — CSS + SVG, aberration chromatique
- `LeonardSEO/liquid-glass-react` — carte PNG statique, ~5 ko

## La regle qu'on oublie toujours

**Le verre sur du noir nu ne montre rien.** Il n'y a rien a refracter. Dans
l'application il fonctionne parce qu'il est pose sur le cerveau en Metal ou
sur l'aura. En video, meme regle : jamais de verre sur un fond plat.

## Et la verite sur le « vrai » verre

Le verre le plus vrai pour une video n'est pas une reimplementation : c'est
**un enregistrement d'ecran de l'application reelle**, qui utilise le vrai
`UIGlassEffect` d'iOS 26. Remotion compose autour. Une reimplementation en
React restera toujours une approximation — utile pour les scenes synthetiques,
jamais superieure a la source.

## Rendu

    npx remotion render --gl=angle-egl Scene out/video.mp4

`--gl=angle-egl` active le GPU : en mode headless Chromium le desactive par
defaut, et `backdrop-filter` est une operation de composition couteuse.
