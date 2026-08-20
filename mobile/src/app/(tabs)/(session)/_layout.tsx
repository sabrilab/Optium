import { Stack } from 'expo-router';

/**
 * La session est un ecran immersif, construit autour de la scene 3D : pas de
 * barre de navigation, sur le modele du lecteur de Musique. Les commandes
 * flottent en Liquid Glass au-dessus du contenu.
 */
export default function SessionLayout() {
  return <Stack screenOptions={{ headerShown: false }} />;
}
