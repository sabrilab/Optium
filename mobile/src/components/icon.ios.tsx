import { SymbolView } from 'expo-symbols';
import type { SFSymbol } from 'expo-symbols';
import type { ColorValue } from 'react-native';

/** Vrai SF Symbol : graisse, alignement optique et Dynamic Type d'Apple. */
export function Icon({ name, size = 17, color }: { name: SFSymbol; size?: number; color: ColorValue }) {
  return <SymbolView name={name} size={size} tintColor={color} />;
}
