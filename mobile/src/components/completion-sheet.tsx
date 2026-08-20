import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';

import { GlassSurface } from '@/components/glass/glass-surface';
import { Radius, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useAppStore } from '@/store';

/**
 * Panneau affiche a la fin d'une session ou d'une pause.
 * Monte au niveau racine pour rester visible quel que soit l'onglet actif.
 */
export function CompletionSheet() {
  const { palette } = useTheme();
  const visible = useAppStore((s) => s.showCompletionModal);
  const timerMode = useAppStore((s) => s.timerMode);
  const close = useAppStore((s) => s.setShowCompletionModal);

  const isFocus = timerMode === 'focus';

  const dismiss = () => close(false);

  const secondary = () => {
    const state = useAppStore.getState();
    if (isFocus) {
      state.addTime(5 * 60);
      state.startTimer();
    } else {
      state.switchToFocus();
    }
    close(false);
  };

  const primary = () => {
    const state = useAppStore.getState();
    if (isFocus) state.switchToBreak();
    else {
      state.switchToFocus();
      state.startTimer();
    }
    close(false);
  };

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={dismiss}>
      <Pressable style={styles.backdrop} onPress={dismiss}>
        {/* L'appui est stoppe ici pour qu'un tap sur le panneau ne le ferme pas. */}
        <Pressable onPress={(event) => event.stopPropagation()}>
          <GlassSurface glassEffectStyle="regular" style={styles.sheet}>
            <Text style={[styles.title, { color: palette.text }]}>
              {isFocus ? 'Session terminée' : 'Pause terminée'}
            </Text>
            <Text style={[styles.body, { color: palette.textSecondary }]}>
              {isFocus ? 'Prêt pour une pause de 5 minutes ?' : 'Prêt à replonger ?'}
            </Text>

            <View style={styles.actions}>
              <Pressable
                onPress={secondary}
                style={[styles.button, { borderColor: palette.border }]}>
                <Text style={[styles.buttonLabel, { color: palette.text }]}>
                  {isFocus ? '+5 min' : 'Passer'}
                </Text>
              </Pressable>

              <Pressable
                onPress={primary}
                style={[styles.button, styles.buttonPrimary, { backgroundColor: palette.text }]}>
                <Text style={[styles.buttonLabel, { color: palette.background }]}>
                  {isFocus ? 'Démarrer la pause' : 'Démarrer'}
                </Text>
              </Pressable>
            </View>
          </GlassSurface>
        </Pressable>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.45)',
    padding: Spacing.six,
  },
  sheet: {
    width: 320,
    maxWidth: '100%',
    padding: Spacing.six,
    borderRadius: Radius.large,
    overflow: 'hidden',
    gap: Spacing.two,
  },
  title: { fontSize: 18, fontWeight: '600' },
  body: { fontSize: 14 },
  actions: { flexDirection: 'row', gap: Spacing.three, marginTop: Spacing.four },
  button: {
    flex: 1,
    height: 44,
    borderRadius: Radius.small,
    borderWidth: StyleSheet.hairlineWidth,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonPrimary: { borderWidth: 0 },
  buttonLabel: { fontSize: 14, fontWeight: '600' },
});
