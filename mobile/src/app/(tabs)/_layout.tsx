import { Icon as TabIcon, Label as TabLabel, NativeTabs } from 'expo-router/unstable-native-tabs';

import { useTheme } from '@/hooks/use-theme';

/**
 * NativeTabs rend une veritable UITabBarController. Sur iOS 26, la barre recoit
 * donc le Liquid Glass du systeme sans que l'app ait quoi que ce soit a dessiner,
 * y compris la reduction automatique au defilement.
 */
export default function TabsLayout() {
  const { palette } = useTheme();

  return (
    <NativeTabs
      backgroundColor={palette.background}
      labelStyle={{ color: palette.textSecondary }}
      tintColor={palette.text}>
      <NativeTabs.Trigger name="index">
        <TabLabel>Session</TabLabel>
        <TabIcon sf={{ default: 'timer', selected: 'timer' }} />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="projects">
        <TabLabel>Projets</TabLabel>
        <TabIcon sf={{ default: 'folder', selected: 'folder.fill' }} />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="stats">
        <TabLabel>Stats</TabLabel>
        <TabIcon sf={{ default: 'chart.bar', selected: 'chart.bar.fill' }} />
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
