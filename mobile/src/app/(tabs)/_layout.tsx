import { NativeTabs } from 'expo-router/unstable-native-tabs';

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
      labelStyle={{ selected: { color: palette.text } }}>
      <NativeTabs.Trigger name="index">
        <NativeTabs.Trigger.Label>Session</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'timer', selected: 'timer' }} />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="projects">
        <NativeTabs.Trigger.Label>Projets</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'folder', selected: 'folder.fill' }} />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="stats">
        <NativeTabs.Trigger.Label>Stats</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon
          sf={{ default: 'chart.bar', selected: 'chart.bar.fill' }}
        />
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
