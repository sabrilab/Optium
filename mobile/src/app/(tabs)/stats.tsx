import { useMemo } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { GlassSurface } from '@/components/glass/glass-surface';
import { StatsChart } from '@/components/stats-chart';
import { Radius, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useAppStore, type Session } from '@/store';

const DAY_LABELS = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
const WINDOW_DAYS = 14;

function startOfDay(date: Date) {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

function formatDuration(seconds: number) {
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  return `${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, '0')}`;
}

function buildStats(sessions: Session[]) {
  const focusSessions = sessions.filter((session) => session.type === 'focus');
  const today = startOfDay(new Date());

  const days = Array.from({ length: WINDOW_DAYS }, (_, index) => {
    const date = new Date(today);
    date.setDate(date.getDate() - (WINDOW_DAYS - 1 - index));
    const next = new Date(date);
    next.setDate(next.getDate() + 1);

    const daySessions = focusSessions.filter(
      (session) => session.createdAt >= date.getTime() && session.createdAt < next.getTime()
    );

    return {
      date,
      label: DAY_LABELS[date.getDay()],
      seconds: daySessions.reduce((sum, session) => sum + session.durationSeconds, 0),
      count: daySessions.length,
    };
  });

  const todayEntry = days[days.length - 1];

  // Serie en cours : on remonte jour par jour tant qu'une session existe.
  // Le jour courant ne casse pas la serie s'il est encore vide.
  let streak = 0;
  for (let index = days.length - 1; index >= 0; index -= 1) {
    if (days[index].count > 0) streak += 1;
    else if (index !== days.length - 1) break;
  }

  const activeDays = days.filter((day) => day.count > 0);
  const totalSeconds = days.reduce((sum, day) => sum + day.seconds, 0);
  const best = days.reduce((top, day) => (day.seconds > top.seconds ? day : top), days[0]);

  return {
    days,
    todaySeconds: todayEntry.seconds,
    todayCount: todayEntry.count,
    streak,
    averageSeconds: activeDays.length ? totalSeconds / activeDays.length : 0,
    averageCount: activeDays.length
      ? days.reduce((sum, day) => sum + day.count, 0) / activeDays.length
      : 0,
    best: best.seconds > 0 ? best : null,
  };
}

export default function StatsScreen() {
  const { palette } = useTheme();
  const insets = useSafeAreaInsets();
  const sessions = useAppStore((s) => s.sessions);

  const stats = useMemo(() => buildStats(sessions), [sessions]);

  const chartData = stats.days.map((day, index) => ({
    x: `${day.label} ${day.date.getDate()}`,
    y: Math.round(day.seconds / 60),
    color: index === stats.days.length - 1 ? palette.accent : palette.textSecondary,
  }));

  return (
    <ScrollView
      style={{ backgroundColor: palette.background }}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + Spacing.two }]}>
      <Text style={[styles.title, { color: palette.text }]}>Statistiques</Text>

      <View style={styles.tileRow}>
        <Tile label="Sessions" value={String(stats.todayCount)} hint="aujourd’hui" />
        <Tile label="Concentration" value={formatDuration(stats.todaySeconds)} hint="aujourd’hui" />
        <Tile label="Série" value={`${stats.streak}j`} hint="consécutifs" />
      </View>

      <GlassSurface glassEffectStyle="regular" style={styles.card}>
        <Text style={[styles.cardLabel, { color: palette.textSecondary }]}>14 DERNIERS JOURS</Text>

        <StatsChart data={chartData} />
      </GlassSurface>

      <View style={styles.tileRow}>
        <Tile label="Moyenne" value={formatDuration(stats.averageSeconds)} hint="par jour actif" />
        <Tile label="Sessions" value={stats.averageCount.toFixed(1)} hint="par jour actif" />
        <Tile
          label="Meilleur jour"
          value={stats.best ? formatDuration(stats.best.seconds) : '—'}
          hint={stats.best ? `${stats.best.label} ${stats.best.date.getDate()}` : 'aucun'}
        />
      </View>
    </ScrollView>
  );
}

function Tile({ label, value, hint }: { label: string; value: string; hint: string }) {
  const { palette } = useTheme();
  return (
    <GlassSurface glassEffectStyle="regular" style={styles.tile}>
      <Text style={[styles.tileValue, { color: palette.text }]}>{value}</Text>
      <Text style={[styles.tileLabel, { color: palette.text }]}>{label}</Text>
      <Text style={[styles.tileHint, { color: palette.textSecondary }]}>{hint}</Text>
    </GlassSurface>
  );
}

const styles = StyleSheet.create({
  content: { padding: Spacing.four, paddingBottom: 120, gap: Spacing.three },
  title: { fontSize: 28, fontWeight: '700', letterSpacing: -0.5, marginBottom: Spacing.one },
  tileRow: { flexDirection: 'row', gap: Spacing.three },
  tile: {
    flex: 1,
    padding: Spacing.three,
    borderRadius: Radius.medium,
    overflow: 'hidden',
    alignItems: 'center',
    gap: 2,
  },
  tileValue: { fontSize: 20, fontWeight: '700', fontVariant: ['tabular-nums'] },
  tileLabel: { fontSize: 11, fontWeight: '500' },
  tileHint: { fontSize: 10 },
  card: { padding: Spacing.four, borderRadius: Radius.medium, overflow: 'hidden', gap: Spacing.three },
  cardLabel: { fontSize: 10, fontWeight: '600', letterSpacing: 0.8 },
});
