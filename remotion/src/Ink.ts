/**
 * Les jetons d'Optium, repris a l'identique de ios-native/Shared/Ink.swift.
 *
 * **Source unique.** Si une valeur diverge ici, les videos cessent de
 * ressembler a l'application, et c'est tout l'interet du dispositif qui
 * tombe. Toute modification doit venir du Swift, jamais l'inverse.
 */
export const Ink = {
  canvas: "#000000",
  surface: "#131315",

  /** Effort. Le halo de la concentration, et la teinte du liquide. */
  focusGlow: "#5253F0",
  focusGlowFar: "#8A4ADD",

  /** Repos. La recuperation, et le regime de nuit. */
  restGlow: "#16A596",
  restGlowFar: "#28769C",

  /** **Signale le present, jamais la decoration.** */
  marker: "#D6E85D",
  critical: "#E0574F",

  ink: "#FFFFFF",
  ink2: "rgba(255,255,255,.64)",
  ink3: "rgba(255,255,255,.40)",
  hairline: "rgba(255,255,255,.08)",
} as const;

/** Intensites du brief : heros, secondaire, tertiaire. */
export const Intensity = { hero: 1, secondary: 0.62, tertiary: 0.42 } as const;

/**
 * La recette de carte du brief, en CSS.
 *
 * Quatre couches, dans cet ordre : remplissage plein de la teinte a
 * `0.72 x intensite`, coeur noirci en radial depuis (50 %, 62 %), arete
 * superieure rallumee dans la seconde teinte, et un second foyer en
 * (82 %, 14 %).
 */
export function bentoSurface(
  tint: string = Ink.focusGlow,
  accent: string = Ink.focusGlowFar,
  intensity: number = Intensity.secondary,
): React.CSSProperties {
  return {
    position: "relative",
    isolation: "isolate",
    overflow: "hidden",
    backgroundColor: Ink.canvas,
    backgroundImage: [
      `radial-gradient(136% 136% at 50% 62%, rgba(0,0,0,1) 0%, rgba(0,0,0,.96) 26%,` +
        ` rgba(0,0,0,.74) 48%, rgba(0,0,0,.34) 72%, rgba(0,0,0,0) 100%)`,
      `linear-gradient(0deg, ${withAlpha(tint, 0.72 * intensity)}, ${withAlpha(tint, 0.72 * intensity)})`,
    ].join(","),
  };
}

/** `#RRGGBB` + alpha -> `rgba(...)`. Les jetons sont en hexadecimal. */
export function withAlpha(hex: string, alpha: number): string {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${alpha})`;
}
