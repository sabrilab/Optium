import { useColorScheme } from 'react-native';

import { getPalette, type Palette } from '@/constants/theme';

/**
 * Suit l'apparence du systeme, sans bascule dans l'application.
 *
 * C'est le comportement des apps d'Apple — Livres, Musique, Reglages n'offrent
 * aucun reglage de theme : l'utilisateur le choisit une fois dans iOS et toutes
 * les apps s'y conforment. C'est aussi la seule option coherente avec les
 * couleurs `PlatformColor`, qui se resolvent cote natif selon l'apparence en
 * vigueur et ne peuvent pas etre forcees depuis JavaScript.
 */
export function useTheme(): { palette: Palette; scheme: 'dark' | 'light' } {
  const scheme = useColorScheme() === 'light' ? 'light' : 'dark';
  return { palette: getPalette(scheme), scheme };
}
