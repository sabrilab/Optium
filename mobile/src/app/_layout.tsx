import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';

import { CompletionSheet } from '@/components/completion-sheet';
import { Colors } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useTimerTick } from '@/hooks/use-timer-tick';

export default function RootLayout() {
  const { scheme } = useTheme();

  // Le timer vit au niveau racine : il continue de tourner quel que soit
  // l'onglet affiche, et survit a la navigation.
  useTimerTick();

  const base = scheme === 'dark' ? DarkTheme : DefaultTheme;
  const palette = Colors[scheme];

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <ThemeProvider
        value={{
          ...base,
          colors: {
            ...base.colors,
            background: palette.background,
            card: palette.card,
            border: palette.border,
            text: palette.text,
            primary: palette.accent,
          },
        }}>
        <StatusBar style={scheme === 'dark' ? 'light' : 'dark'} />
        <Stack screenOptions={{ headerShown: false }}>
          <Stack.Screen name="(tabs)" />
          <Stack.Screen
            name="settings"
            options={{
              presentation: 'modal',
              headerShown: true,
              title: 'Réglages',
            }}
          />
        </Stack>
        <CompletionSheet />
      </ThemeProvider>
    </GestureHandlerRootView>
  );
}
