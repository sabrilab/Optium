import 'react-native-url-polyfill/auto';

import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { AppState, Platform } from 'react-native';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

/** Vrai lorsque les cles sont presentes et qu'un client a pu etre construit. */
export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

/**
 * Optium stocke ses donnees localement : Supabase ne sert qu'a
 * l'authentification et a la fonction de generation de taches.
 *
 * Le client n'est donc pas indispensable au fonctionnement de l'app, et lever
 * une exception au chargement du module — comme le faisait la version web —
 * ferait echouer le demarrage entier pour une fonctionnalite optionnelle.
 * Sans cles, on expose un client nul et les appels concernes echouent
 * proprement, la ou ils sont faits.
 */
export const supabase: SupabaseClient | null = isSupabaseConfigured
  ? createClient(supabaseUrl!, supabaseAnonKey!, {
      auth: {
        storage: AsyncStorage,
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: Platform.OS === 'web',
      },
    })
  : null;

if (supabase && Platform.OS !== 'web') {
  // Sur mobile, Supabase ne peut pas savoir seul que l'app repasse au premier
  // plan : on pilote le rafraichissement du jeton depuis l'etat de l'app.
  AppState.addEventListener('change', (state) => {
    if (state === 'active') supabase.auth.startAutoRefresh();
    else supabase.auth.stopAutoRefresh();
  });
}
