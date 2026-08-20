import { Chart, Host } from '@expo/ui/swift-ui';

import { StatsChartBars } from './stats-chart-bars';
import type { StatsChartProps } from './stats-chart.types';

import { supportsSwiftUI } from '@/lib/runtime';

/**
 * Swift Charts — le meme moteur que les graphiques de Santé ou de Batterie
 * d'iOS. Indisponible dans Expo Go, qui n'embarque pas @expo/ui : on retombe
 * alors sur un rendu en barres.
 */
export function StatsChart({ data }: StatsChartProps) {
  if (!supportsSwiftUI) return <StatsChartBars data={data} />;

  return (
    <Host style={{ height: 180 }} matchContents>
      <Chart data={data} type="bar" barStyle={{ cornerRadius: 4 }} />
    </Host>
  );
}
