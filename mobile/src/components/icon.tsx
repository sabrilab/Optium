import { Text } from 'react-native';

export type SFSymbol = string;

/**
 * Repli hors iOS.
 *
 * expo-symbols appelle le pont natif des le chargement du module : il ne peut
 * donc pas etre simplement importe puis ignore a l'execution. La separation par
 * extension de fichier garantit qu'il n'entre jamais dans le bundle web ou
 * Android. On evite aussi d'embarquer une police d'icones entiere pour des
 * plateformes qui ne sont pas la cible du projet.
 */
const FALLBACK_GLYPHS: Record<string, string> = {
  timer: '⏱',
  folder: '🗂',
  'folder.fill': '🗂',
  'chart.bar': '▤',
  'chart.bar.fill': '▤',
  gearshape: '⚙',
  'play.fill': '▶',
  'pause.fill': '❚❚',
  plus: '＋',
  minus: '－',
  'chevron.up': '⌃',
  'chevron.down': '⌄',
  'checkmark.circle.fill': '◉',
  circle: '○',
  sparkles: '✦',
  'forward.end': '⏭',
};

export function Icon({ name, size = 17, color }: { name: SFSymbol; size?: number; color: string }) {
  return (
    <Text style={{ fontSize: size * 0.9, color, lineHeight: size * 1.2 }}>
      {FALLBACK_GLYPHS[name] ?? '•'}
    </Text>
  );
}
