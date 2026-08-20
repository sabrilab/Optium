import { BlurView } from 'expo-blur';
import { GlassView, isLiquidGlassAvailable } from 'expo-glass-effect';
import type { GlassStyle } from 'expo-glass-effect';
import { StyleSheet, View, type ViewProps } from 'react-native';

import { useColorScheme } from '@/hooks/use-color-scheme';

export type GlassSurfaceProps = ViewProps & {
  /** 'regular' = verre teinte lisible, 'clear' = verre transparent sur media. */
  glassEffectStyle?: GlassStyle;
  /** Reagit au toucher (deformation du verre). A reserver aux surfaces tappables. */
  isInteractive?: boolean;
  tintColor?: string;
};

/**
 * Surface en Liquid Glass avec degradation progressive :
 *   iOS 26+        -> UIGlassEffect natif
 *   iOS < 26       -> UIVisualEffectView (flou facon iOS 7-18)
 *   Android / web  -> aplat semi-opaque
 *
 * Toujours passer par ce composant plutot que d'importer GlassView directement :
 * l'app doit rester lisible sur les appareils qui n'ont pas le verre.
 */
export function GlassSurface({
  glassEffectStyle = 'regular',
  isInteractive = false,
  tintColor,
  style,
  children,
  ...rest
}: GlassSurfaceProps) {
  const colorScheme = useColorScheme() ?? 'light';

  if (isLiquidGlassAvailable()) {
    return (
      <GlassView
        glassEffectStyle={glassEffectStyle}
        isInteractive={isInteractive}
        tintColor={tintColor}
        style={style}
        {...rest}>
        {children}
      </GlassView>
    );
  }

  if (process.env.EXPO_OS === 'ios') {
    return (
      <BlurView
        intensity={glassEffectStyle === 'clear' ? 40 : 80}
        tint={colorScheme === 'dark' ? 'systemThinMaterialDark' : 'systemThinMaterialLight'}
        style={style}
        {...rest}>
        {children}
      </BlurView>
    );
  }

  return (
    <View
      style={[
        style,
        colorScheme === 'dark' ? styles.fallbackDark : styles.fallbackLight,
        tintColor ? { backgroundColor: tintColor } : null,
      ]}
      {...rest}>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  fallbackLight: { backgroundColor: 'rgba(255, 255, 255, 0.72)' },
  fallbackDark: { backgroundColor: 'rgba(28, 28, 30, 0.72)' },
});
