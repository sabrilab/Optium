import { Colors, type Palette } from '@/constants/theme';
import { useAppStore } from '@/store';

/**
 * Optium impose son propre theme plutot que de suivre celui du systeme : la
 * scene 3D est concue pour un fond sombre, et l'utilisateur garde la main via
 * les reglages.
 */
export function useTheme(): { palette: Palette; scheme: 'dark' | 'light' } {
  const scheme = useAppStore((s) => s.theme);
  return { palette: Colors[scheme], scheme };
}
