import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';

import { GlassSurface } from '@/components/glass/glass-surface';
import { Layout, Radius, Spacing, Typography } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useAppStore } from '@/store';

/**
 * Alerte de fin de session.
 *
 * Reprend la forme d'un UIAlertController : titre, message court, et deux
 * actions dont la principale est mise en avant. Montee au niveau racine pour
 * rester visible quel que soit l'onglet actif.
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
      <View style={styles.backdrop}>
        <GlassSurface glassEffectStyle="regular" style={styles.sheet}>
          <View style={styles.body}>
            <Text style={[styles.title, { color: palette.label }]}>
              {isFocus ? 'Session terminée' : 'Pause terminée'}
            </Text>
            <Text style={[styles.message, { color: palette.secondaryLabel }]}>
              {isFocus ? 'Prêt pour une pause de 5 minutes ?' : 'Prêt à replonger ?'}
            </Text>
          </View>

          <View style={[styles.divider, { backgroundColor: palette.separator }]} />

          <View style={styles.actions}>
            <Pressable onPress={secondary} style={styles.action} accessibilityRole="button">
              <Text style={[styles.actionLabel, { color: palette.tint }]}>
                {isFocus ? 'Ajouter 5 min' : 'Passer'}
              </Text>
            </Pressable>

            <View style={[styles.actionDivider, { backgroundColor: palette.separator }]} />

            <Pressable onPress={primary} style={styles.action} accessibilityRole="button">
              <Text style={[styles.actionLabel, styles.actionStrong, { color: palette.tint }]}>
                {isFocus ? 'Démarrer la pause' : 'Démarrer'}
              </Text>
            </Pressable>
          </View>
        </GlassSurface>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.4)',
    padding: Spacing.six,
  },
  sheet: { width: 280, maxWidth: '100%', borderRadius: Radius.medium, overflow: 'hidden' },
  body: { padding: Spacing.five, gap: Spacing.one, alignItems: 'center' },
  title: { ...Typography.headline, textAlign: 'center' },
  message: { ...Typography.footnote, textAlign: 'center' },
  divider: { height: StyleSheet.hairlineWidth },
  actions: { flexDirection: 'row' },
  actionDivider: { width: StyleSheet.hairlineWidth },
  action: {
    flex: 1,
    minHeight: Layout.minTouchTarget,
    alignItems: 'center',
    justifyContent: 'center',
  },
  actionLabel: Typography.body,
  actionStrong: { fontWeight: '600' },
});
