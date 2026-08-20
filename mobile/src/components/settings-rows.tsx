import { ScrollView, StyleSheet, Switch, Text, View } from 'react-native';

import { GlassSurface } from '@/components/glass/glass-surface';
import { Icon } from '@/components/icon';
import { Radius, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useAppStore } from '@/store';

/**
 * Reglages en composants React Native.
 *
 * Utilise partout ou les vues SwiftUI de `@expo/ui` ne sont pas disponibles :
 * dans Expo Go, qui n'embarque que les modules compiles dans son propre
 * binaire, ainsi que sur Android et web.
 */
export function SettingsRows() {
  const { palette } = useTheme();

  const focusDuration = useAppStore((s) => s.focusDuration);
  const breakDuration = useAppStore((s) => s.breakDuration);
  const longBreakDuration = useAppStore((s) => s.longBreakDuration);
  const soundEnabled = useAppStore((s) => s.soundEnabled);
  const hapticsEnabled = useAppStore((s) => s.hapticsEnabled);
  const geoEnabled = useAppStore((s) => s.geoEnabled);
  const brainEnabled = useAppStore((s) => s.brainEnabled);
  const theme = useAppStore((s) => s.theme);

  const store = useAppStore.getState();

  return (
    <ScrollView
      style={{ backgroundColor: palette.background }}
      contentContainerStyle={styles.content}>
      <Section title="Durées">
        <Stepper
          label="Session"
          value={focusDuration}
          min={5}
          max={90}
          step={5}
          onChange={store.setFocusDuration}
        />
        <Stepper
          label="Pause"
          value={breakDuration}
          min={1}
          max={30}
          step={1}
          onChange={store.setBreakDuration}
        />
        <Stepper
          label="Pause longue"
          value={longBreakDuration}
          min={5}
          max={45}
          step={5}
          onChange={store.setLongBreakDuration}
          last
        />
      </Section>

      <Section title="Retours">
        <Row label="Carillon de fin" value={soundEnabled} onChange={store.toggleSound} />
        <Row label="Vibrations" value={hapticsEnabled} onChange={store.toggleHaptics} last />
      </Section>

      <Section title="Session">
        <Row label="Enregistrer le lieu" value={geoEnabled} onChange={store.toggleGeo} />
        <Row label="Visualisation 3D" value={brainEnabled} onChange={store.toggleBrain} last />
      </Section>

      <Section title="Apparence">
        <Row label="Thème sombre" value={theme === 'dark'} onChange={store.toggleTheme} last />
      </Section>
    </ScrollView>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  const { palette } = useTheme();
  return (
    <View style={styles.section}>
      <Text style={[styles.sectionTitle, { color: palette.textSecondary }]}>
        {title.toUpperCase()}
      </Text>
      <GlassSurface glassEffectStyle="regular" style={styles.card}>
        {children}
      </GlassSurface>
    </View>
  );
}

function Row({
  label,
  value,
  onChange,
  last,
}: {
  label: string;
  value: boolean;
  onChange: () => void;
  last?: boolean;
}) {
  const { palette } = useTheme();
  return (
    <View
      style={[
        styles.row,
        !last && { borderBottomWidth: StyleSheet.hairlineWidth, borderColor: palette.border },
      ]}>
      <Text style={[styles.label, { color: palette.text }]}>{label}</Text>
      <Switch value={value} onValueChange={onChange} />
    </View>
  );
}

function Stepper({
  label,
  value,
  min,
  max,
  step,
  onChange,
  last,
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  step: number;
  onChange: (value: number) => void;
  last?: boolean;
}) {
  const { palette } = useTheme();

  return (
    <View
      style={[
        styles.row,
        !last && { borderBottomWidth: StyleSheet.hairlineWidth, borderColor: palette.border },
      ]}>
      <Text style={[styles.label, { color: palette.text }]}>{label}</Text>
      <View style={styles.stepper}>
        <StepperButton
          symbol="minus"
          disabled={value <= min}
          onPress={() => onChange(Math.max(min, value - step))}
        />
        <Text style={[styles.value, { color: palette.text }]}>{value} min</Text>
        <StepperButton
          symbol="plus"
          disabled={value >= max}
          onPress={() => onChange(Math.min(max, value + step))}
        />
      </View>
    </View>
  );
}

function StepperButton({
  symbol,
  disabled,
  onPress,
}: {
  symbol: 'plus' | 'minus';
  disabled: boolean;
  onPress: () => void;
}) {
  const { palette } = useTheme();
  return (
    <Text
      onPress={disabled ? undefined : onPress}
      suppressHighlighting
      style={[
        styles.stepperButton,
        { backgroundColor: palette.secondary, opacity: disabled ? 0.35 : 1 },
      ]}>
      <Icon name={symbol} size={13} color={palette.text} />
    </Text>
  );
}

const styles = StyleSheet.create({
  content: { padding: Spacing.four, paddingBottom: Spacing.six, gap: Spacing.five },
  section: { gap: Spacing.two },
  sectionTitle: { fontSize: 11, fontWeight: '600', letterSpacing: 0.6, paddingHorizontal: Spacing.two },
  card: { borderRadius: Radius.medium, overflow: 'hidden', paddingHorizontal: Spacing.four },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    minHeight: 48,
    gap: Spacing.three,
  },
  label: { fontSize: 15, flexShrink: 1 },
  stepper: { flexDirection: 'row', alignItems: 'center', gap: Spacing.three },
  value: { fontSize: 14, fontVariant: ['tabular-nums'], minWidth: 58, textAlign: 'center' },
  stepperButton: {
    width: 30,
    height: 30,
    borderRadius: 15,
    textAlign: 'center',
    lineHeight: 30,
    overflow: 'hidden',
  },
});
