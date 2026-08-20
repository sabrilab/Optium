import { Platform, PlatformColor, type ColorValue } from 'react-native';

/**
 * Couleurs systeme d'iOS.
 *
 * `PlatformColor` renvoie les `UIColor` semantiques d'Apple plutot que des
 * valeurs figees. C'est ce que fait une app native : les teintes s'adaptent
 * seules au mode sombre, au reglage « Augmenter le contraste », au mode
 * economie d'energie et aux futures revisions du systeme, et les rapports de
 * contraste du Human Interface Guidelines sont garantis par construction.
 *
 * La version web reprend les valeurs sRGB publiees par Apple, faute d'API
 * equivalente dans le navigateur.
 */
export type Palette = {
  /** Fond des ecrans a contenu libre. */
  background: ColorValue;
  /** Fond des ecrans construits autour de listes groupees. */
  groupedBackground: ColorValue;
  /** Fond des cellules posees sur un fond groupe. */
  groupedCard: ColorValue;
  /** Remplissage discret : pastilles, pistes de progression. */
  fill: ColorValue;
  separator: ColorValue;
  label: ColorValue;
  secondaryLabel: ColorValue;
  tertiaryLabel: ColorValue;
  tint: ColorValue;
  destructive: ColorValue;
};

const iosPalette = (): Palette => ({
  background: PlatformColor('systemBackground'),
  groupedBackground: PlatformColor('systemGroupedBackground'),
  groupedCard: PlatformColor('secondarySystemGroupedBackground'),
  fill: PlatformColor('tertiarySystemFill'),
  separator: PlatformColor('separator'),
  label: PlatformColor('label'),
  secondaryLabel: PlatformColor('secondaryLabel'),
  tertiaryLabel: PlatformColor('tertiaryLabel'),
  tint: PlatformColor('systemBlue'),
  destructive: PlatformColor('systemRed'),
});

const fallbackPalettes: Record<'light' | 'dark', Palette> = {
  light: {
    background: '#FFFFFF',
    groupedBackground: '#F2F2F7',
    groupedCard: '#FFFFFF',
    fill: 'rgba(118, 118, 128, 0.12)',
    separator: 'rgba(60, 60, 67, 0.29)',
    label: '#000000',
    secondaryLabel: 'rgba(60, 60, 67, 0.60)',
    tertiaryLabel: 'rgba(60, 60, 67, 0.30)',
    tint: '#007AFF',
    destructive: '#FF3B30',
  },
  dark: {
    background: '#000000',
    groupedBackground: '#000000',
    groupedCard: '#1C1C1E',
    fill: 'rgba(118, 118, 128, 0.24)',
    separator: 'rgba(84, 84, 88, 0.65)',
    label: '#FFFFFF',
    secondaryLabel: 'rgba(235, 235, 245, 0.60)',
    tertiaryLabel: 'rgba(235, 235, 245, 0.30)',
    tint: '#0A84FF',
    destructive: '#FF453A',
  },
};

export function getPalette(scheme: 'light' | 'dark'): Palette {
  return Platform.OS === 'ios' ? iosPalette() : fallbackPalettes[scheme];
}

/**
 * Styles typographiques d'iOS, aux tailles publiees par Apple.
 *
 * `allowFontScaling` est actif par defaut dans React Native : ces tailles
 * suivent donc le reglage Dynamic Type de l'utilisateur.
 */
export const Typography = {
  largeTitle: { fontSize: 34, lineHeight: 41, fontWeight: '700' },
  title1: { fontSize: 28, lineHeight: 34, fontWeight: '700' },
  title2: { fontSize: 22, lineHeight: 28, fontWeight: '600' },
  headline: { fontSize: 17, lineHeight: 22, fontWeight: '600' },
  body: { fontSize: 17, lineHeight: 22, fontWeight: '400' },
  callout: { fontSize: 16, lineHeight: 21, fontWeight: '400' },
  subheadline: { fontSize: 15, lineHeight: 20, fontWeight: '400' },
  footnote: { fontSize: 13, lineHeight: 18, fontWeight: '400' },
  caption: { fontSize: 12, lineHeight: 16, fontWeight: '400' },
} as const;

/** Metriques de mise en page du Human Interface Guidelines. */
export const Layout = {
  /** Marge laterale standard des listes et du contenu. */
  margin: 16,
  /** Retrait des separateurs de cellule, aligne sur le texte. */
  separatorInset: 16,
  /** Rayon des cellules groupees insérées. */
  cornerRadius: 10,
  /** Hauteur minimale d'une cible tactile. */
  minTouchTarget: 44,
} as const;

export const Spacing = { one: 4, two: 8, three: 12, four: 16, five: 20, six: 24 } as const;
export const Radius = { small: 10, medium: 16, large: 22, pill: 999 } as const;
