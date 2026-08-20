import { ScrollView, StyleSheet, Switch, Text, View } from 'react-native';

import { Icon } from '@/components/icon';
import { ListRow, ListSection } from '@/components/list';
import { Layout, Spacing, Typography } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useAppStore } from '@/store';

/**
 * Reglages en composants React Native, sur la structure de l'app Reglages
 * d'iOS : listes groupees insérées, interrupteurs alignes a droite, pas-a-pas
 * pour les valeurs numeriques.
 *
 * Utilise partout ou les vues SwiftUI de `@expo/ui` ne sont pas disponibles :
 * dans Expo Go, qui n'embarque que les modules compiles dans son binaire, ainsi
 * que sur Android et web.
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

  const store = useAppStore.getState();

  const toggle = (value: boolean, onChange: () => void) => (
    <Switch value={value} onValueChange={onChange} />
  );

  return (
    <ScrollView
      style={{ backgroundColor: palette.groupedBackground }}
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={styles.content}>
      <ListSection header="Durées">
        <ListRow
          title="Session"
          accessory={
            <Stepper value={focusDuration} min={5} max={90} step={5} onChange={store.setFocusDuration} />
          }
        />
        <ListRow
          title="Pause"
          accessory={
            <Stepper value={breakDuration} min={1} max={30} step={1} onChange={store.setBreakDuration} />
          }
        />
        <ListRow
          title="Pause longue"
          accessory={
            <Stepper
              value={longBreakDuration}
              min={5}
              max={45}
              step={5}
              onChange={store.setLongBreakDuration}
            />
          }
        />
      </ListSection>

      <ListSection header="Retours" footer="Le carillon respecte le mode silencieux de l’iPhone.">
        <ListRow title="Carillon de fin" accessory={toggle(soundEnabled, store.toggleSound)} />
        <ListRow title="Vibrations" accessory={toggle(hapticsEnabled, store.toggleHaptics)} />
      </ListSection>

      <ListSection
        header="Session"
        footer="La position n’est enregistrée qu’au démarrage d’une session, et reste sur l’appareil. L’apparence claire ou sombre suit le réglage d’iOS.">
        <ListRow title="Enregistrer le lieu" accessory={toggle(geoEnabled, store.toggleGeo)} />
        <ListRow title="Visualisation 3D" accessory={toggle(brainEnabled, store.toggleBrain)} />
      </ListSection>

    </ScrollView>
  );
}

function Stepper({
  value,
  min,
  max,
  step,
  onChange,
}: {
  value: number;
  min: number;
  max: number;
  step: number;
  onChange: (value: number) => void;
}) {
  const { palette } = useTheme();

  return (
    <View style={styles.stepper}>
      <Text style={[styles.value, { color: palette.secondaryLabel }]}>{value} min</Text>
      <View style={[styles.stepperControl, { backgroundColor: palette.fill }]}>
        <StepperButton
          symbol="minus"
          label="Diminuer"
          disabled={value <= min}
          onPress={() => onChange(Math.max(min, value - step))}
        />
        <View style={[styles.stepperDivider, { backgroundColor: palette.separator }]} />
        <StepperButton
          symbol="plus"
          label="Augmenter"
          disabled={value >= max}
          onPress={() => onChange(Math.min(max, value + step))}
        />
      </View>
    </View>
  );
}

function StepperButton({
  symbol,
  label,
  disabled,
  onPress,
}: {
  symbol: 'plus' | 'minus';
  label: string;
  disabled: boolean;
  onPress: () => void;
}) {
  const { palette } = useTheme();
  return (
    <Text
      onPress={disabled ? undefined : onPress}
      suppressHighlighting
      accessibilityRole="button"
      accessibilityLabel={label}
      style={[styles.stepperButton, { opacity: disabled ? 0.3 : 1 }]}>
      <Icon name={symbol} size={15} color={palette.label} />
    </Text>
  );
}

const styles = StyleSheet.create({
  content: { paddingBottom: Spacing.six, gap: Spacing.six, paddingTop: Spacing.two },
  value: { ...Typography.body, fontVariant: ['tabular-nums'], minWidth: 56, textAlign: 'right' },
  stepper: { flexDirection: 'row', alignItems: 'center', gap: Spacing.three },
  stepperControl: { flexDirection: 'row', borderRadius: 7, overflow: 'hidden' },
  stepperDivider: { width: StyleSheet.hairlineWidth },
  stepperButton: {
    width: 44,
    height: 32,
    textAlign: 'center',
    lineHeight: 32,
  },
});
