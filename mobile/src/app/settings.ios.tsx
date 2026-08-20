import { Host, Form, Section, Slider, Text as UIText, Toggle } from '@expo/ui/swift-ui';
import { StyleSheet } from 'react-native';

import { SettingsRows } from '@/components/settings-rows';
import { supportsSwiftUI } from '@/lib/runtime';

import { useAppStore } from '@/store';

/**
 * Reglages rendus avec les vrais composants SwiftUI (`Form`, `Section`,
 * `Toggle`, `Slider`) : c'est ici que le gain est le plus net, puisque l'ecran
 * herite du style systeme, du Liquid Glass et des animations d'Apple sans qu'on
 * ait une seule ligne de style a ecrire.
 *
 * Android et web n'ont pas SwiftUI : ils recoivent une version en composants
 * React Native, fonctionnellement identique.
 */
/**
 * Expo Go n'embarque pas @expo/ui : y rendre un Form SwiftUI afficherait un
 * ecran rouge « Unimplemented component ». Le choix se fait ici, une fois, et
 * chaque variante appelle ses propres hooks sans condition.
 */
export default function SettingsScreen() {
  return supportsSwiftUI ? <SwiftUISettings /> : <SettingsRows />;
}

function SwiftUISettings() {
  const focusDuration = useAppStore((s) => s.focusDuration);
  const breakDuration = useAppStore((s) => s.breakDuration);
  const longBreakDuration = useAppStore((s) => s.longBreakDuration);
  const soundEnabled = useAppStore((s) => s.soundEnabled);
  const hapticsEnabled = useAppStore((s) => s.hapticsEnabled);
  const geoEnabled = useAppStore((s) => s.geoEnabled);
  const brainEnabled = useAppStore((s) => s.brainEnabled);

  const store = useAppStore.getState();

  return (
    <Host style={styles.host}>
      <Form>
        <Section title="Durées">
          <UIText>{`Session · ${focusDuration} min`}</UIText>
          <Slider
            value={focusDuration}
            min={5}
            max={90}
            step={5}
            onValueChange={(value) => store.setFocusDuration(Math.round(value))}
          />
          <UIText>{`Pause · ${breakDuration} min`}</UIText>
          <Slider
            value={breakDuration}
            min={1}
            max={30}
            step={1}
            onValueChange={(value) => store.setBreakDuration(Math.round(value))}
          />
          <UIText>{`Pause longue · ${longBreakDuration} min`}</UIText>
          <Slider
            value={longBreakDuration}
            min={5}
            max={45}
            step={5}
            onValueChange={(value) => store.setLongBreakDuration(Math.round(value))}
          />
        </Section>

        <Section title="Retours">
          <Toggle
            label="Carillon de fin"
            isOn={soundEnabled}
            onIsOnChange={() => store.toggleSound()}
          />
          <Toggle
            label="Vibrations"
            isOn={hapticsEnabled}
            onIsOnChange={() => store.toggleHaptics()}
          />
        </Section>

        <Section title="Session">
          <Toggle
            label="Enregistrer le lieu"
            isOn={geoEnabled}
            onIsOnChange={() => store.toggleGeo()}
          />
          <Toggle
            label="Visualisation 3D"
            isOn={brainEnabled}
            onIsOnChange={() => store.toggleBrain()}
          />
        </Section>

      </Form>
    </Host>
  );
}

const styles = StyleSheet.create({
  host: { flex: 1 },
});
