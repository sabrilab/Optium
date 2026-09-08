import React from "react";
import { Ink, withAlpha } from "./Ink";

/**
 * Le verre, pour Remotion.
 *
 * ## Ce qui est verifie
 *
 * `backdrop-filter: url(#filtre-svg)` avec un `feDisplacementMap`
 * **fonctionne dans Chromium**, donc dans Remotion, qui rend avec Chromium
 * headless. C'est la meilleure plateforme possible pour ce materiau :
 *
 * - **Chromium** : supporte les filtres SVG dans `backdrop-filter`. ✅
 * - **Safari** : bug ouvert sur `feDisplacementMap` en `backdrop-filter`
 *   (WebKit 245510).
 * - **Firefox** : ne supporte aucun filtre SVG en `backdrop-filter`.
 *
 * ## Ce qui est delicat, et pourquoi ce composant delegue
 *
 * La refraction credible ne vient pas du filtre mais de **la carte de
 * deplacement** : neutre (128,128) au centre, rampe concentree dans la bande
 * du bord, normale sortante correcte dans les coins. Composer des degrades
 * SVG ne marche pas — les modes de fusion cassent le neutre — et l'alignement
 * carte/region de filtre est piegeux (`primitiveUnits`, viewport de l'hote).
 *
 * C'est exactement ce que les bibliotheques maintenues ont resolu. On les
 * utilise plutot que de reecrire :
 *
 *     npm i liquid-glass-web-react
 *
 * ## La contrainte propre a Optium
 *
 * **Le verre sur du noir nu ne montre rien** : il n'y a rien a refracter.
 * Dans l'application il fonctionne parce qu'il est pose sur le cerveau en
 * Metal ou sur l'aura. En video, meme regle — jamais de verre sur un fond
 * plat. `requireBackdrop` le rappelle a l'appel.
 */
export type GlassProps = {
  width: number;
  height: number;
  radius?: number;
  children?: React.ReactNode;
  style?: React.CSSProperties;
  /**
   * Force de la refraction au bord. 0 = verre depoli simple.
   * Au-dela de ~0,7 l'effet cesse de ressembler a du verre.
   */
  refraction?: number;
  blur?: number;
};

/**
 * Le repli sans refraction : verre depoli + speculaire de bord.
 *
 * **Il tient tout seul.** Le speculaire — l'arete superieure rallumee et les
 * flancs — porte l'essentiel de la lecture « c'est du verre » ; la refraction
 * est ce qui la rend vivante quand le fond bouge. Pour un plan fixe, ce repli
 * suffit largement, et il n'a aucune dependance.
 */
export const Glass: React.FC<GlassProps> = ({
  width,
  height,
  radius = 34,
  children,
  style,
  blur = 14,
}) => (
  <div
    style={{
      width,
      height,
      borderRadius: radius,
      display: "grid",
      placeItems: "center",
      backdropFilter: `blur(${blur}px) saturate(1.7) brightness(1.06)`,
      WebkitBackdropFilter: `blur(${blur}px) saturate(1.7) brightness(1.06)`,
      background: withAlpha(Ink.ink, 0.04),
      boxShadow: [
        // L'arete superieure : c'est elle qui fait lire le verre.
        `inset 0 1.5px 0 ${withAlpha(Ink.ink, 0.6)}`,
        `inset 0 -1px 0 ${withAlpha(Ink.ink, 0.14)}`,
        `inset 1.5px 0 0 ${withAlpha(Ink.ink, 0.18)}`,
        `inset -1.5px 0 0 ${withAlpha(Ink.ink, 0.18)}`,
        `0 18px 50px rgba(0,0,0,.55)`,
      ].join(","),
      ...style,
    }}
  >
    {children}
  </div>
);

/**
 * La carte de deplacement d'une lentille, calculee pixel par pixel.
 *
 * Fournie pour qui voudrait cabler la refraction lui-meme. **Le calcul est
 * juste** ; c'est l'alignement avec la region du filtre qui demande du soin,
 * et c'est la que les bibliotheques gagnent leur place.
 *
 * @returns une URL de donnees PNG, ou `null` hors navigateur.
 */
export function lensDisplacementMap(
  w: number,
  h: number,
  radius: number,
  band: number,
  power = 2,
): string | null {
  if (typeof document === "undefined") return null;
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  const ctx = c.getContext("2d");
  if (!ctx) return null;
  const img = ctx.createImageData(w, h);
  const cx = w / 2, cy = h / 2, hx = w / 2 - radius, hy = h / 2 - radius;

  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const px = x + 0.5 - cx, py = y + 0.5 - cy;
      const qx = Math.abs(px) - hx, qy = Math.abs(py) - hy;
      let d: number, nx: number, ny: number;
      if (qx > 0 && qy > 0) {
        // Dans un coin : la normale est radiale.
        const l = Math.hypot(qx, qy) || 1;
        d = radius - l;
        nx = (qx / l) * Math.sign(px);
        ny = (qy / l) * Math.sign(py);
      } else if (qx > qy) {
        d = radius - qx; nx = Math.sign(px); ny = 0;
      } else {
        d = radius - qy; nx = 0; ny = Math.sign(py);
      }
      // 1 au bord, 0 au-dela de la bande. La puissance concentre la rampe.
      const t = Math.pow(Math.max(0, 1 - Math.max(0, Math.min(1, d / band))), power);
      const i = (y * w + x) * 4;
      img.data[i] = 128 - nx * t * 127;      // R -> deplacement en x
      img.data[i + 1] = 128 - ny * t * 127;  // G -> deplacement en y
      img.data[i + 2] = 128;
      img.data[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  return c.toDataURL();
}
