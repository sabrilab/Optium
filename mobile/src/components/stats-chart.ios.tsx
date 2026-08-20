import { Chart, Host } from '@expo/ui/swift-ui';

import type { StatsChartProps } from './stats-chart.types';

/**
 * Swift Charts — le meme moteur que les graphiques de Santé ou de Batterie
 * d'iOS : axes, graduations et accessibilite fournis par le systeme.
 */
export function StatsChart({ data }: StatsChartProps) {
  return (
    <Host style={{ height: 180 }} matchContents>
      <Chart data={data} type="bar" barStyle={{ cornerRadius: 4 }} />
    </Host>
  );
}
