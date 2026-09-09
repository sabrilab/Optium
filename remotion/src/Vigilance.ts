/**
 * Le modele a deux processus, repris de `Clarity/Vigilance.swift`.
 *
 * **La courbe que suit le liquide n'est pas decorative** : c'est celle que
 * l'application calcule. Deux harmoniques — la 24 h porte le grand mouvement,
 * la 12 h creuse l'apres-midi et produit le rebond du soir. Une seule
 * sinusoide ne peut pas faire les deux.
 */
const W24 = .55, P24 = 6, W12 = .95, P12 = 2;
const raw = (h: number) =>
  W24 * Math.cos(2 * Math.PI * (h - P24) / 24) + W12 * Math.cos(2 * Math.PI * (h - P12) / 12);

const BOUNDS = (() => {
  let lo = Infinity, hi = -Infinity;
  for (let i = 0; i <= 480; i++) {
    const v = raw(i * .05);
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  return {lo, hi};
})();

/** Le plafond au reveil, et la constante de pression. Une nuit moyenne. */
const CEILING_AT_WAKE = 72, TAU = 11;

export const pressure = (h: number) => 1 - Math.exp(-Math.max(0, h) / TAU);
/** Ce que la nuit permet, moins ce que la journee a deja coute. */
export const ceiling = (h: number) =>
  Math.max(0, Math.min(100, CEILING_AT_WAKE - 20 * pressure(h)));
export const rhythm = (h: number) => (raw(h) - BOUNDS.lo) / (BOUNDS.hi - BOUNDS.lo);
/** **L'amplitude croit avec la pression** : mal dormir creuse l'ecart. */
export const amplitude = (h: number) => 7 + 24 * pressure(h);

/** La clarte de l'instant : ce que le plafond laisse passer de l'oscillation. */
export const clarity = (h: number) =>
  Math.max(0, Math.min(100,
    ceiling(h) - amplitude(h) * (1 - rhythm(h)) - 20 * Math.exp(-Math.max(0, h) / 1.15)));
