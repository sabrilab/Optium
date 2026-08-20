import Constants, { ExecutionEnvironment } from 'expo-constants';

/**
 * Vrai lorsque les vues SwiftUI de `@expo/ui` sont reellement disponibles.
 *
 * Expo Go est une application publiee sur l'App Store : elle n'embarque que les
 * modules natifs compiles dans son propre binaire, et `@expo/ui` n'en fait pas
 * partie. Les rendre malgre tout affiche un ecran rouge « Unimplemented
 * component ». Ces composants ne redeviennent disponibles que dans un build de
 * developpement ou de production, qui compile les modules du projet.
 *
 * Le Liquid Glass, lui, reste disponible dans Expo Go : expo-glass-effect est
 * inclus dans le binaire d'Expo Go.
 */
export const supportsSwiftUI =
  Constants.executionEnvironment !== ExecutionEnvironment.StoreClient;
