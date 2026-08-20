import { StyleSheet, View } from 'react-native';

import type { StatsChartProps } from './stats-chart.types';

/** Graphique en barres, utilise partout ou Swift Charts n'est pas disponible. */
export function StatsChartBars({ data }: StatsChartProps) {
  const max = Math.max(...data.map((point) => point.y), 1);

  return (
    <View style={styles.chart}>
      {data.map((point, index) => (
        <View key={index} style={styles.column}>
          <View
            style={[
              styles.bar,
              { height: `${(point.y / max) * 100}%`, backgroundColor: point.color },
            ]}
          />
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  chart: { height: 160, flexDirection: 'row', alignItems: 'flex-end', gap: 4 },
  column: { flex: 1, height: '100%', justifyContent: 'flex-end' },
  bar: { width: '100%', borderRadius: 3, minHeight: 2 },
});
