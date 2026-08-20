import { ScrollView, StyleSheet, Switch, Text, View } from 'react-native';

import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useAppStore } from '@/store';

/**
 * Reglages hors iOS.
 *
 * La version iOS (settings.ios.tsx) utilise les vrais composants SwiftUI. Ils
 * initialisent le pont natif des le chargement du module, d'ou la separation
 * par extension de fichier plutot qu'un simple test de plateforme.
 */
export default function SettingsScreen() {
  const { palette } = useTheme();
  const store = useAppStore();

  const rows = [
    { label: 'Carillon de fin', value: store.soundEnabled, toggle: store.toggleSound },
    { label: 'Vibrations', value: store.hapticsEnabled, toggle: store.toggleHaptics },
    { label: 'Enregistrer le lieu', value: store.geoEnabled, toggle: store.toggleGeo },
    { label: 'Visualisation 3D', value: store.brainEnabled, toggle: store.toggleBrain },
    { label: 'Thème sombre', value: store.theme === 'dark', toggle: store.toggleTheme },
  ];

  return (
    <ScrollView
      style={{ backgroundColor: palette.background }}
      contentContainerStyle={styles.content}>
      {rows.map((row) => (
        <View key={row.label} style={[styles.row, { borderColor: palette.border }]}>
          <Text style={[styles.rowLabel, { color: palette.text }]}>{row.label}</Text>
          <Switch value={row.value} onValueChange={row.toggle} />
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { padding: Spacing.four, gap: Spacing.two },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: Spacing.three,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  rowLabel: { fontSize: 15 },
});
