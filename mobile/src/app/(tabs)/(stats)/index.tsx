import { useMemo } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { ListRow, ListSection } from '@/components/list';
import { StatsChart } from '@/components/stats-chart';
import { Layout, Spacing, Typography } from '@/constants/theme';
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
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest === 0 ? `${hours} h` : `${hours} h ${rest}`;
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

  // Serie en cours : on remonte jour par jour tant qu'une session existe. Le
  // jour courant ne casse pas la serie s'il est encore vide.
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
  const sessions = useAppStore((s) => s.sessions);

  const stats = useMemo(() => buildStats(sessions), [sessions]);

  const chartData = stats.days.map((day, index) => ({
    x: `${day.date.getDate()}`,
    y: Math.round(day.seconds / 60),
    color: index === stats.days.length - 1 ? palette.tint : palette.tertiaryLabel,
  }));

  const value = (text: string) => (
    <Text style={[styles.value, { color: palette.secondaryLabel }]}>{text}</Text>
  );

  return (
    <ScrollView
      style={{ backgroundColor: palette.groupedBackground }}
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={styles.content}>
      <ListSection header="Aujourd’hui">
        <ListRow title="Sessions terminées" accessory={value(String(stats.todayCount))} />
        <ListRow title="Temps de concentration" accessory={value(formatDuration(stats.todaySeconds))} />
        <ListRow
          title="Série en cours"
          accessory={value(stats.streak <= 1 ? `${stats.streak} jour` : `${stats.streak} jours`)}
        />
      </ListSection>

      <ListSection header="14 derniers jours" footer="Minutes de concentration par jour.">
        <View style={styles.chart}>
          <StatsChart data={chartData} />
        </View>
      </ListSection>

      <ListSection header="Moyennes" footer="Calculées sur les jours où au moins une session a été menée.">
        <ListRow title="Concentration par jour" accessory={value(formatDuration(stats.averageSeconds))} />
        <ListRow title="Sessions par jour" accessory={value(stats.averageCount.toFixed(1))} />
        <ListRow
          title="Meilleur jour"
          accessory={value(
            stats.best
              ? `${formatDuration(stats.best.seconds)} · ${stats.best.label} ${stats.best.date.getDate()}`
              : '—'
          )}
        />
      </ListSection>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { paddingBottom: 120, gap: Spacing.six, paddingTop: Spacing.two },
  chart: { paddingHorizontal: Layout.margin, paddingVertical: Spacing.four },
  value: { ...Typography.body, fontVariant: ['tabular-nums'] },
});
