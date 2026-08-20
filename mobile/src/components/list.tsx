import { Pressable, StyleSheet, Text, View, type ViewStyle } from 'react-native';

import { Icon } from '@/components/icon';
import { Layout, Spacing, Typography } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';

/**
 * Liste groupee inseree, telle que la definit le Human Interface Guidelines.
 *
 * Reproduit la structure des Reglages d'iOS : un en-tete en capitales
 * discretes, un bloc arrondi pose sur le fond groupe, et des separateurs
 * retraités a gauche pour s'aligner sur le texte plutot que sur le bord.
 */
export function ListSection({
  header,
  footer,
  children,
  style,
}: {
  header?: string;
  footer?: string;
  children: React.ReactNode;
  style?: ViewStyle;
}) {
  const { palette } = useTheme();
  const rows = Array.isArray(children) ? children.filter(Boolean) : [children];

  return (
    <View style={[styles.section, style]}>
      {header && (
        <Text style={[styles.header, { color: palette.secondaryLabel }]}>
          {header.toUpperCase()}
        </Text>
      )}

      <View style={[styles.card, { backgroundColor: palette.groupedCard }]}>
        {rows.map((row, index) => (
          <View key={index}>
            {index > 0 && (
              <View style={[styles.separator, { backgroundColor: palette.separator }]} />
            )}
            {row}
          </View>
        ))}
      </View>

      {footer && (
        <Text style={[styles.footer, { color: palette.secondaryLabel }]}>{footer}</Text>
      )}
    </View>
  );
}

/**
 * Cellule de liste. `onPress` ajoute le chevron et le retour visuel au toucher
 * attendus d'une ligne navigable.
 */
export function ListRow({
  title,
  subtitle,
  accessory,
  onPress,
  onLongPress,
  leading,
  destructive,
}: {
  title: string;
  subtitle?: string;
  accessory?: React.ReactNode;
  onPress?: () => void;
  onLongPress?: () => void;
  leading?: React.ReactNode;
  destructive?: boolean;
}) {
  const { palette } = useTheme();

  const content = (
    <View style={styles.row}>
      {leading}
      <View style={styles.rowText}>
        <Text
          style={[
            styles.title,
            { color: destructive ? palette.destructive : palette.label },
          ]}
          numberOfLines={1}>
          {title}
        </Text>
        {subtitle && (
          <Text style={[styles.subtitle, { color: palette.secondaryLabel }]} numberOfLines={1}>
            {subtitle}
          </Text>
        )}
      </View>
      {accessory}
      {onPress && <Icon name="chevron.right" size={14} color={palette.tertiaryLabel} />}
    </View>
  );

  if (!onPress && !onLongPress) return content;

  return (
    <Pressable
      onPress={onPress}
      onLongPress={onLongPress}
      style={({ pressed }) => (pressed ? { backgroundColor: palette.fill } : null)}>
      {content}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  section: { gap: Spacing.two },
  header: {
    ...Typography.footnote,
    letterSpacing: 0.5,
    paddingHorizontal: Layout.margin,
  },
  card: {
    marginHorizontal: Layout.margin,
    borderRadius: Layout.cornerRadius,
    overflow: 'hidden',
  },
  footer: {
    ...Typography.footnote,
    paddingHorizontal: Layout.margin,
  },
  separator: {
    height: StyleSheet.hairlineWidth,
    marginLeft: Layout.separatorInset,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.three,
    minHeight: Layout.minTouchTarget,
    paddingHorizontal: Layout.margin,
    paddingVertical: Spacing.two,
  },
  rowText: { flex: 1, gap: 1 },
  title: Typography.body,
  subtitle: Typography.footnote,
});
