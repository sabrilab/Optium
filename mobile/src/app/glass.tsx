import * as Device from 'expo-device';
import { GlassContainer, isGlassEffectAPIAvailable, isLiquidGlassAvailable } from 'expo-glass-effect';
import { useState } from 'react';
import { Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { GlassSurface } from '@/components/glass/glass-surface';

/**
 * Banc de test du Liquid Glass.
 * Ecran temporaire : il sert a verifier sur un vrai appareil que le verre iOS 26
 * s'applique bien avant de porter les ecrans d'Optium. A supprimer ensuite.
 */
export default function GlassLabScreen() {
  const [merged, setMerged] = useState(false);

  const liquid = isLiquidGlassAvailable();
  const api = isGlassEffectAPIAvailable();

  return (
    <ScrollView contentContainerStyle={styles.content}>
      {/* Aplats colores : sans quelque chose derriere, le verre est invisible. */}
      <View pointerEvents="none" style={styles.backdrop}>
        <View style={[styles.blob, styles.blobA]} />
        <View style={[styles.blob, styles.blobB]} />
        <View style={[styles.blob, styles.blobC]} />
      </View>

      <GlassSurface style={styles.card}>
        <Text style={styles.title}>Diagnostic</Text>
        <Row label="Plateforme" value={`${Platform.OS} ${Device.osVersion ?? ''}`} />
        <Row label="Appareil" value={Device.modelName ?? 'inconnu'} />
        <Row label="API UIGlassEffect" value={api ? 'disponible' : 'absente'} />
        <Row label="Liquid Glass actif" value={liquid ? 'oui' : 'non (fallback flou)'} />
      </GlassSurface>

      <GlassSurface glassEffectStyle="regular" style={styles.card}>
        <Text style={styles.title}>regular</Text>
        <Text style={styles.body}>Verre lisible, a utiliser pour tout contenu textuel.</Text>
      </GlassSurface>

      <GlassSurface glassEffectStyle="clear" style={styles.card}>
        <Text style={styles.title}>clear</Text>
        <Text style={styles.body}>Verre transparent, reserve aux surfaces posees sur un media.</Text>
      </GlassSurface>

      <GlassSurface isInteractive style={styles.card} tintColor="rgba(32,138,239,0.25)">
        <Text style={styles.title}>isInteractive + tintColor</Text>
        <Text style={styles.body}>Appuie longuement : le verre se deforme sous le doigt.</Text>
      </GlassSurface>

      <Text style={styles.section}>Fusion de deux surfaces (GlassContainer)</Text>
      <Pressable onPress={() => setMerged((value) => !value)}>
        <GlassContainer spacing={merged ? 0 : 24} style={styles.glassContainer}>
          <GlassSurface style={styles.pill} />
          <GlassSurface style={styles.pill} />
        </GlassContainer>
        <Text style={styles.hint}>
          {merged ? 'Fusionnees — appuie pour separer' : 'Separees — appuie pour fusionner'}
        </Text>
      </Pressable>
    </ScrollView>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={styles.rowValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  content: { padding: 20, gap: 16, paddingTop: 88, paddingBottom: 120 },
  backdrop: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
  blob: { position: 'absolute', width: 260, height: 260, borderRadius: 130, opacity: 0.85 },
  blobA: { backgroundColor: '#FF6B6B', top: 40, left: -60 },
  blobB: { backgroundColor: '#4ECDC4', top: 320, right: -80 },
  blobC: { backgroundColor: '#FFD93D', top: 640, left: 20 },
  card: { padding: 20, borderRadius: 24, overflow: 'hidden', gap: 6 },
  title: { fontSize: 17, fontWeight: '600' },
  body: { fontSize: 14, opacity: 0.8 },
  section: { fontSize: 13, fontWeight: '600', opacity: 0.6, marginTop: 12 },
  row: { flexDirection: 'row', justifyContent: 'space-between', gap: 12 },
  rowLabel: { fontSize: 14, opacity: 0.6 },
  rowValue: { fontSize: 14, fontWeight: '500' },
  glassContainer: { flexDirection: 'row', height: 90, alignItems: 'center', justifyContent: 'center' },
  pill: { width: 90, height: 90, borderRadius: 45 },
  hint: { fontSize: 13, textAlign: 'center', opacity: 0.6, marginTop: 8 },
});
