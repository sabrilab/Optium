import type { ColorValue } from 'react-native';

export type StatsChartPoint = { x: string; y: number; color?: ColorValue };
export type StatsChartProps = { data: StatsChartPoint[] };
