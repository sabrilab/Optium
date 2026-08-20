import { DarkTheme, DefaultTheme, ThemeProvider } from '@react-navigation/native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';

import { CompletionSheet } from '@/components/completion-sheet';
import { useTheme } from '@/hooks/use-theme';
import { useTimerTick } from '@/hooks/use-timer-tick';

export default function RootLayout() {
  const { scheme } = useTheme();

  // Le timer vit au niveau racine : il continue de tourner quel que soit
  // l'onglet affiche, et survit a la navigation.
  useTimerTick();

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      {/* Les couleurs de navigation restent celles du systeme : les surcharger
          reviendrait a figer des teintes que le mode sombre et le contraste
          augmente d'iOS savent deja resoudre. */}
      <ThemeProvider value={scheme === 'dark' ? DarkTheme : DefaultTheme}>
        <StatusBar style="auto" />
        <Stack>
          <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          <Stack.Screen
            name="settings"
            options={{
              presentation: 'modal',
              title: 'Réglages',
              headerLargeTitle: true,
            }}
          />
        </Stack>
        <CompletionSheet />
      </ThemeProvider>
    </GestureHandlerRootView>
  );
}
