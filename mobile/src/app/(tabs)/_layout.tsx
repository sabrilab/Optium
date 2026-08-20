import { Icon, Label, NativeTabs } from 'expo-router/unstable-native-tabs';

/**
 * UITabBarController natif.
 *
 * Aucune couleur n'est imposee : la barre garde son apparence systeme, donc le
 * Liquid Glass et la reduction au defilement d'iOS 26, exactement comme dans
 * Livres ou Musique. Chaque onglet possede sa propre pile de navigation, ce qui
 * lui donne un grand titre et conserve son historique quand on change d'onglet.
 */
export default function TabsLayout() {
  return (
    <NativeTabs>
      <NativeTabs.Trigger name="(session)">
        <Label>Session</Label>
        <Icon sf={{ default: 'timer', selected: 'timer' }} />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="(projects)">
        <Label>Projets</Label>
        <Icon sf={{ default: 'folder', selected: 'folder.fill' }} />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="(stats)">
        <Label>Statistiques</Label>
        <Icon sf={{ default: 'chart.bar', selected: 'chart.bar.fill' }} />
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
