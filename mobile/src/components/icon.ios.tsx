import { SymbolView } from 'expo-symbols';
import type { SFSymbol } from 'expo-symbols';

/** Vrai SF Symbol : graisse, alignement optique et Dynamic Type d'Apple. */
export function Icon({ name, size = 17, color }: { name: SFSymbol; size?: number; color: string }) {
  return <SymbolView name={name} size={size} tintColor={color} />;
}
