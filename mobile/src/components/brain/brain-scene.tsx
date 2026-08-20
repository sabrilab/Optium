/* eslint-disable react-hooks/immutability, react-hooks/refs --
 * react-three-fiber pilote son propre boucle de rendu : le callback passe a
 * useFrame s'execute soixante fois par seconde en dehors du cycle de rendu de
 * React, et c'est precisement l'interet de ce composant — muter des uniformes
 * GPU et des refs sans provoquer le moindre rendu React. Le meme raisonnement
 * vaut pour les callbacks de geste, invoques par le systeme apres le rendu.
 * Ces deux regles supposent un flux de donnees gere par React et produisent ici
 * des faux positifs.
 */
import { Canvas, useFrame } from '@react-three/fiber';
import { useFocusEffect } from 'expo-router';
import { useCallback, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, AppState, PixelRatio, StyleSheet, Text, View } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import * as THREE from 'three';

import {
  BREAK_COLOR_A,
  BREAK_COLOR_B,
  createFluidMaterial,
  createShellMaterial,
  FOCUS_COLOR_A,
  FOCUS_COLOR_B,
} from './fluid-material';
import { useBrainModel, type BrainModel } from './use-brain-model';

import { useAppStore } from '@/store';

const MAX_FILL = 0.8;

type DragState = { velocity: number };

function BrainMeshes({ model, drag }: { model: BrainModel; drag: React.RefObject<DragState> }) {
  'use no memo';

  const groupRef = useRef<THREE.Group>(null);

  const fluidMaterial = useMemo(
    () => createFluidMaterial(model.boundsMin, model.boundsMax),
    [model]
  );
  const shellMaterial = useMemo(() => createShellMaterial(), []);
  const wobbleRef = useRef(0);

  useFrame((state, delta) => {
    // On lit le store imperativement plutot que de s'y abonner : le timer change
    // toutes les secondes, et un abonnement declencherait un rendu React a chaque
    // fois alors que seule une uniforme GPU doit bouger.
    const { timerMode, timerSeconds, totalSeconds } = useAppStore.getState();

    const progress = totalSeconds === 0 ? 1 : timerSeconds / totalSeconds;
    const targetFill =
      timerMode === 'focus' ? progress * MAX_FILL : (1 - progress) * MAX_FILL;

    const uniforms = fluidMaterial.uniforms;
    uniforms.u_time.value = state.clock.elapsedTime;
    uniforms.u_fillLevel.value += (targetFill - uniforms.u_fillLevel.value) * 0.05;

    wobbleRef.current = Math.min(1, wobbleRef.current * 0.95 + Math.abs(drag.current.velocity) * 0.6);
    drag.current.velocity *= 0.9;
    uniforms.u_wobble.value = wobbleRef.current;

    uniforms.u_colorA.value.lerp(timerMode === 'focus' ? FOCUS_COLOR_A : BREAK_COLOR_A, 0.02);
    uniforms.u_colorB.value.lerp(timerMode === 'focus' ? FOCUS_COLOR_B : BREAK_COLOR_B, 0.02);

    const group = groupRef.current;
    if (group) {
      group.rotation.y += delta * 0.3 + drag.current.velocity;
      // Leger flottement vertical, equivalent du composant Float de drei.
      group.position.y = Math.sin(state.clock.elapsedTime * 1.0) * 0.06;
      group.rotation.x = Math.sin(state.clock.elapsedTime * 0.6) * 0.04;
    }
  });

  return (
    <group ref={groupRef}>
      {/* Le fluide est dessine avant la coque pour que le verre se compose par dessus. */}
      <mesh geometry={model.geometry} material={fluidMaterial} renderOrder={0} />
      <mesh geometry={model.geometry} material={shellMaterial} renderOrder={1} />
    </group>
  );
}

function Fallback({ label }: { label: string }) {
  return (
    <View style={styles.center}>
      <Text style={styles.fallbackEmoji}>🧠</Text>
      <Text style={styles.fallbackText}>{label}</Text>
    </View>
  );
}

export function BrainScene() {
  'use no memo';

  const { model, error } = useBrainModel();
  const drag = useRef<DragState>({ velocity: 0 });

  const [screenFocused, setScreenFocused] = useState(true);
  const [appActive, setAppActive] = useState(() => AppState.currentState === 'active');

  useFocusEffect(
    useCallback(() => {
      setScreenFocused(true);
      const subscription = AppState.addEventListener('change', (next) =>
        setAppActive(next === 'active')
      );
      return () => {
        setScreenFocused(false);
        subscription.remove();
      };
    }, [])
  );

  const pan = useMemo(
    () =>
      Gesture.Pan()
        .runOnJS(true)
        .onUpdate((event) => {
          drag.current.velocity = event.velocityX / 12000;
        })
        .onEnd(() => {
          drag.current.velocity *= 0.5;
        }),
    []
  );

  if (error) return <Fallback label="Modèle 3D indisponible" />;

  if (!model) {
    return (
      <View style={styles.center}>
        <ActivityIndicator />
      </View>
    );
  }

  return (
    <GestureDetector gesture={pan}>
      <View style={StyleSheet.absoluteFill}>
        <Canvas
          // Le rendu est totalement suspendu hors de l'ecran Session ou quand
          // l'app passe en arriere-plan : sans cela, la boucle 3D continuerait
          // de tourner a 60 images par seconde et viderait la batterie.
          frameloop={screenFocused && appActive ? 'always' : 'never'}
          camera={{ position: [0, 0, 5.5], fov: 40 }}
          // Les ecrans d'iPhone sont en densite 3. Rendre la scene a cette
          // densite triple le nombre de fragments pour un gain invisible sur un
          // contenu aussi diffus : on plafonne a 2.
          dpr={Math.min(PixelRatio.get(), 2)}
          flat
          gl={{ antialias: true, alpha: true }}
          style={styles.canvas}>
          <ambientLight intensity={0.6} />
          <directionalLight position={[5, 5, 5]} intensity={0.6} />
          <BrainMeshes model={model} drag={drag} />
        </Canvas>
      </View>
    </GestureDetector>
  );
}

const styles = StyleSheet.create({
  canvas: { flex: 1, backgroundColor: 'transparent' },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 8 },
  fallbackEmoji: { fontSize: 32 },
  fallbackText: { fontSize: 12, opacity: 0.6 },
});
