import { useSyncExternalStore } from 'react';
import { useColorScheme as useRNColorScheme } from 'react-native';

const emptySubscribe = () => () => {};

/**
 * To support static rendering, this value needs to be re-calculated on the client side for web.
 *
 * useSyncExternalStore distingue serveur et client sans passer par un setState en effet :
 * le snapshot serveur force 'light' au rendu statique, le snapshot client prend le relais
 * des la premiere hydratation.
 */
export function useColorScheme() {
  const hasHydrated = useSyncExternalStore(
    emptySubscribe,
    () => true,
    () => false
  );

  const colorScheme = useRNColorScheme();

  return hasHydrated ? colorScheme : 'light';
}
