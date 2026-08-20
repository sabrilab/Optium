import { createAudioPlayer } from 'expo-audio';
import * as Haptics from 'expo-haptics';
import * as Location from 'expo-location';
import * as Notifications from 'expo-notifications';
import { useCallback, useEffect, useRef } from 'react';
import { AppState } from 'react-native';

import { useAppStore } from '@/store';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldPlaySound: true,
    shouldSetBadge: false,
    shouldShowBanner: true,
    shouldShowList: true,
  }),
});

let chimePlayer: ReturnType<typeof createAudioPlayer> | null = null;

/**
 * Le lecteur est cree au premier carillon, pas au chargement du module : le
 * rendu statique web s'execute sans API audio, et rien ne justifie de reserver
 * une ressource audio tant que l'utilisateur n'a pas termine de session.
 */
function playChime() {
  try {
    chimePlayer ??= createAudioPlayer(require('@/assets/audio/chime.wav'));
    chimePlayer.seekTo(0);
    chimePlayer.play();
  } catch {
    // Audio indisponible : la vibration et la notification suffisent a prevenir.
  }
}

/**
 * Timer global, monte une seule fois dans le layout racine.
 *
 * Deux mecanismes cohabitent, parce qu'iOS suspend le JavaScript des que l'app
 * quitte le premier plan :
 *
 *  - un intervalle d'une seconde met a jour l'affichage tant que l'app est
 *    visible. Il recalcule le restant depuis l'horodatage de depart, donc un
 *    retour au premier plan reprend au bon endroit sans rattrapage.
 *  - une notification locale est programmee a l'avance pour l'instant de fin.
 *    C'est elle qui previent l'utilisateur quand l'app est fermee — un
 *    intervalle JavaScript, lui, ne tournerait plus.
 */
export function useTimerTick() {
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const notificationIdRef = useRef<string | null>(null);
  const locationRef = useRef<{ lat: number; lng: number } | undefined>(undefined);
  const completionHandledRef = useRef(false);

  const isRunning = useAppStore((s) => s.isRunning);
  const timerSeconds = useAppStore((s) => s.timerSeconds);
  const timerMode = useAppStore((s) => s.timerMode);
  const geoEnabled = useAppStore((s) => s.geoEnabled);
  const tick = useAppStore((s) => s.tick);

  // ── Position, capturee une fois par activation du reglage ──
  useEffect(() => {
    if (!geoEnabled) {
      locationRef.current = undefined;
      return;
    }
    let active = true;
    (async () => {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted' || !active) return;
      const position = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.Balanced,
      });
      if (active) {
        locationRef.current = {
          lat: position.coords.latitude,
          lng: position.coords.longitude,
        };
      }
    })().catch(() => {
      // Permission refusee ou position indisponible : la session sera juste
      // enregistree sans coordonnees.
    });
    return () => {
      active = false;
    };
  }, [geoEnabled]);

  // ── Notification de fin, programmee a l'avance ──
  useEffect(() => {
    let cancelled = false;

    async function schedule() {
      const existing = notificationIdRef.current;
      notificationIdRef.current = null;
      if (existing) await Notifications.cancelScheduledNotificationAsync(existing);

      const { isRunning: running, timerSeconds: remaining, timerMode: mode } =
        useAppStore.getState();
      if (!running || remaining <= 0) return;

      const permission = await Notifications.getPermissionsAsync();
      const granted =
        permission.granted || (await Notifications.requestPermissionsAsync()).granted;
      if (!granted || cancelled) return;

      const id = await Notifications.scheduleNotificationAsync({
        content:
          mode === 'focus'
            ? { title: 'Session terminée 🎯', body: 'C’est l’heure de la pause.' }
            : { title: 'Pause terminée ☕', body: 'Prêt à replonger ?' },
        trigger: {
          type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL,
          seconds: remaining,
        },
      });

      if (cancelled) await Notifications.cancelScheduledNotificationAsync(id);
      else notificationIdRef.current = id;
    }

    schedule().catch(() => {
      // Notifications indisponibles (simulateur, permission refusee) : le timer
      // reste parfaitement fonctionnel au premier plan.
    });

    return () => {
      cancelled = true;
    };
    // Volontairement lie au seul demarrage/arret : re-programmer a chaque
    // seconde ecoulee annulerait et recreerait la notification en boucle.
  }, [isRunning, timerMode]);

  // ── Intervalle d'affichage ──
  useEffect(() => {
    if (!isRunning) {
      if (intervalRef.current) clearInterval(intervalRef.current);
      intervalRef.current = null;
      return;
    }

    intervalRef.current = setInterval(tick, 1000);
    // Un retour au premier plan doit rattraper le temps ecoule pendant la
    // suspension sans attendre le prochain battement.
    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') tick();
    });

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
      intervalRef.current = null;
      subscription.remove();
    };
  }, [isRunning, tick]);

  // ── Fin de session ──
  const complete = useCallback(() => {
    const state = useAppStore.getState();

    state.pauseTimer();
    if (state.soundEnabled) playChime();
    if (state.hapticsEnabled) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
    }

    state.addSession({
      taskId: state.activeTaskId,
      projectId: state.activeProjectId,
      durationSeconds: state.totalSeconds,
      type: state.timerMode,
      location: state.geoEnabled ? locationRef.current : undefined,
    });

    if (state.timerMode === 'focus' && state.activeTaskId && state.activeProjectId) {
      state.incrementTaskPomodoro(state.activeProjectId, state.activeTaskId);
    }

    state.setShowCompletionModal(true);
  }, []);

  useEffect(() => {
    if (timerSeconds > 0) {
      completionHandledRef.current = false;
      return;
    }
    // Le tick peut atteindre zero plusieurs fois avant que l'etat ne se propage :
    // ce garde-fou evite d'enregistrer la meme session deux fois.
    if (isRunning && !completionHandledRef.current) {
      completionHandledRef.current = true;
      complete();
    }
  }, [timerSeconds, isRunning, complete]);
}
