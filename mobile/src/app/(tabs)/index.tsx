import * as Haptics from 'expo-haptics';
import { Link } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BrainScene } from '@/components/brain/brain-scene';
import { GlassSurface } from '@/components/glass/glass-surface';
import { Icon } from '@/components/icon';
import { Radius, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useAppStore } from '@/store';

function formatTime(totalSeconds: number) {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

export default function SessionScreen() {
  const { palette } = useTheme();
  const insets = useSafeAreaInsets();

  const timerMode = useAppStore((s) => s.timerMode);
  const timerSeconds = useAppStore((s) => s.timerSeconds);
  const totalSeconds = useAppStore((s) => s.totalSeconds);
  const isRunning = useAppStore((s) => s.isRunning);
  const brainEnabled = useAppStore((s) => s.brainEnabled);
  const focusDuration = useAppStore((s) => s.focusDuration);
  const breakDuration = useAppStore((s) => s.breakDuration);
  const activeTaskId = useAppStore((s) => s.activeTaskId);
  const activeProjectId = useAppStore((s) => s.activeProjectId);
  const projects = useAppStore((s) => s.projects);

  const activeProject = projects.find((p) => p.id === activeProjectId);
  const activeTask = activeProject?.tasks.find((t) => t.id === activeTaskId);

  const progress = totalSeconds === 0 ? 0 : 1 - timerSeconds / totalSeconds;
  const isFocus = timerMode === 'focus';

  const toggle = () => {
    const state = useAppStore.getState();
    if (state.hapticsEnabled) Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    if (state.isRunning) state.pauseTimer();
    else state.startTimer();
  };

  const endEarly = () => {
    const state = useAppStore.getState();
    // Une session interrompue compte pour le temps reellement passe, pas pour
    // sa duree prevue.
    state.addSession({
      taskId: state.activeTaskId,
      projectId: state.activeProjectId,
      durationSeconds: state.totalSeconds - state.timerSeconds,
      type: state.timerMode,
    });
    if (state.timerMode === 'focus') state.switchToBreak();
    else state.switchToFocus();
  };

  return (
    <View style={[styles.root, { backgroundColor: palette.background }]}>
      <View style={styles.scene}>
        {brainEnabled ? (
          <BrainScene />
        ) : (
          <View style={styles.sceneOff}>
            <Text style={[styles.sceneOffText, { color: palette.textSecondary }]}>
              Visualisation désactivée
            </Text>
          </View>
        )}
      </View>

      <View style={[styles.top, { paddingTop: insets.top + Spacing.two }]}>
        <GlassSurface glassEffectStyle="clear" style={styles.badge}>
          <Text style={[styles.badgeText, { color: palette.text }]}>
            {isFocus ? 'Deep Focus' : 'Pause'}
          </Text>
        </GlassSurface>

        <Link href="/settings" asChild>
          <Pressable hitSlop={12}>
            <GlassSurface glassEffectStyle="clear" isInteractive style={styles.iconButton}>
              <Icon name="gearshape" size={17} color={palette.text} />
            </GlassSurface>
          </Pressable>
        </Link>
      </View>

      <View style={styles.bottom}>
        {activeTask && (
          <GlassSurface glassEffectStyle="regular" style={styles.taskCard}>
            <Text style={[styles.taskProject, { color: palette.textSecondary }]}>
              {activeProject?.name}
            </Text>
            <Text style={[styles.taskTitle, { color: palette.text }]} numberOfLines={1}>
              {activeTask.title}
            </Text>
            <View style={styles.pomodoroRow}>
              {Array.from({ length: activeTask.estimatedPomodoros }).map((_, index) => (
                <View
                  key={index}
                  style={[
                    styles.pomodoroDot,
                    {
                      backgroundColor:
                        index < activeTask.completedPomodoros ? palette.text : palette.border,
                    },
                  ]}
                />
              ))}
            </View>
          </GlassSurface>
        )}

        <GlassSurface glassEffectStyle="regular" style={styles.timerCard}>
          <View style={[styles.progressTrack, { backgroundColor: palette.border }]}>
            <View
              style={[
                styles.progressFill,
                { backgroundColor: palette.text, width: `${Math.min(100, progress * 100)}%` },
              ]}
            />
          </View>

          <Text style={[styles.timer, { color: palette.text }]}>{formatTime(timerSeconds)}</Text>
          <Text style={[styles.timerLabel, { color: palette.textSecondary }]}>
            {isFocus ? `Session · ${focusDuration} min` : `Pause · ${breakDuration} min`}
          </Text>

          <Pressable onPress={toggle} hitSlop={8}>
            <GlassSurface isInteractive glassEffectStyle="regular" style={styles.playButton}>
              <Icon
                name={isRunning ? 'pause.fill' : 'play.fill'}
                size={22}
                color={palette.text}
              />
            </GlassSurface>
          </Pressable>

          {progress > 0 && (
            <Pressable onPress={endEarly} hitSlop={8} style={styles.endEarly}>
              <Icon name="forward.end" size={11} color={palette.textSecondary} />
              <Text style={[styles.endEarlyText, { color: palette.textSecondary }]}>
                Terminer maintenant
              </Text>
            </Pressable>
          )}
        </GlassSurface>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  // La scene 3D occupe tout l'ecran ; les panneaux de verre flottent par dessus.
  scene: { position: 'absolute', top: 0, left: 0, right: 0, bottom: '38%' },
  sceneOff: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  sceneOffText: { fontSize: 12 },
  top: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.four,
    gap: Spacing.three,
  },
  badge: {
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.one + 2,
    borderRadius: Radius.pill,
    overflow: 'hidden',
  },
  badgeText: { fontSize: 12, fontWeight: '600' },
  iconButton: {
    width: 34,
    height: 34,
    borderRadius: Radius.pill,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },
  bottom: { marginTop: 'auto', padding: Spacing.four, gap: Spacing.three },
  taskCard: {
    padding: Spacing.four,
    borderRadius: Radius.medium,
    overflow: 'hidden',
    gap: Spacing.one,
  },
  taskProject: { fontSize: 11 },
  taskTitle: { fontSize: 15, fontWeight: '500' },
  pomodoroRow: { flexDirection: 'row', gap: Spacing.one, marginTop: Spacing.one },
  pomodoroDot: { flex: 1, height: 3, borderRadius: 2 },
  timerCard: {
    padding: Spacing.six,
    borderRadius: Radius.large,
    overflow: 'hidden',
    alignItems: 'center',
  },
  progressTrack: {
    height: 3,
    width: '70%',
    borderRadius: 2,
    overflow: 'hidden',
    marginBottom: Spacing.five,
  },
  progressFill: { height: '100%', borderRadius: 2 },
  timer: {
    fontSize: 58,
    fontWeight: '600',
    letterSpacing: -1.5,
    fontVariant: ['tabular-nums'],
  },
  timerLabel: { fontSize: 12, marginTop: Spacing.one, marginBottom: Spacing.five },
  playButton: {
    width: 62,
    height: 62,
    borderRadius: Radius.pill,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },
  endEarly: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.one + 2,
    marginTop: Spacing.four,
  },
  endEarlyText: { fontSize: 12 },
});
