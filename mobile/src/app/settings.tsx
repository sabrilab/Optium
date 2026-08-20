import { SettingsRows } from '@/components/settings-rows';

/**
 * Reglages hors iOS. La version iOS (settings.ios.tsx) utilise les composants
 * SwiftUI quand ils sont disponibles et retombe sur ce meme rendu sinon.
 */
export default function SettingsScreen() {
  return <SettingsRows />;
}
