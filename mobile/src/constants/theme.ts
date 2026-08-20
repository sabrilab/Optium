/**
 * Palette portee depuis src/index.css de la version web.
 *
 * Les jetons d'origine sont en OKLCH, un espace colorimetrique que React Native
 * ne sait pas interpreter : ils ont ete convertis en sRGB une fois pour toutes.
 */
export const Colors = {
  dark: {
    background: '#030304',
    card: '#0A0A0D',
    secondary: '#161619',
    border: 'rgba(255, 255, 255, 0.10)',
    text: '#FAFAFA',
    textSecondary: '#9F9FA9',
    destructive: '#FF6467',
    accent: '#4A90D9',
  },
  light: {
    background: '#FFFFFF',
    card: '#FFFFFF',
    secondary: '#F4F4F5',
    border: '#E4E4E7',
    text: '#09090B',
    textSecondary: '#71717B',
    destructive: '#E7000B',
    accent: '#3B7DD8',
  },
} as const;

export type ColorScheme = keyof typeof Colors;
export type Palette = { [K in keyof (typeof Colors)['dark']]: string };

export const Spacing = { one: 4, two: 8, three: 12, four: 16, five: 20, six: 24 } as const;
export const Radius = { small: 10, medium: 16, large: 22, pill: 999 } as const;
