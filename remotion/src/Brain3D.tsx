import React, {useMemo, useRef} from "react";
import * as THREE from "three";
import {GLTFLoader} from "three/examples/jsm/loaders/GLTFLoader.js";
import {useLoader, useThree} from "@react-three/fiber";
import {staticFile} from "remotion";
import {Ink} from "./Ink";

/**
 * Le cerveau, en vrai.
 *
 * **Le maillage est celui de l'application** — `brain.glb`, le meme fichier
 * que charge le rendu Metal. Un blob dessine a la main ne ressemble a rien
 * d'autre qu'a un blob : c'est ce que le premier montage a prouve.
 *
 * Trois couches, et chacune fait un travail que les deux autres ne font pas :
 *
 * 1. **La coque de verre** — sombre, presque transparente, en `DoubleSide`.
 *    Elle donne le volume et laisse voir le liquide au travers.
 * 2. **Le liquide** — la MEME geometrie, coupee par un plan horizontal.
 *    C'est un vrai volume tranche, pas un remplissage 2D : quand le cerveau
 *    tourne, la surface reste horizontale, et c'est ce detail qui vend
 *    l'objet.
 * 3. **Le Fresnel** — une arete qui s'allume la ou la surface fuit le regard.
 *    On l'a prefere a `transmission`, qui exige une carte d'environnement :
 *    sur fond noir il n'y a rien a refracter, et le cout serait paye pour
 *    rien.
 */

/** L'arete de Fresnel : additive, invisible de face, vive sur les bords. */
const fresnelMaterial = (color: THREE.Color, power: number, strength: number) =>
  new THREE.ShaderMaterial({
    uniforms: {
      uColor: {value: color},
      uPower: {value: power},
      uStrength: {value: strength},
    },
    vertexShader: `
      varying vec3 vN;
      varying vec3 vV;
      void main(){
        vec4 wp = modelMatrix * vec4(position, 1.0);
        vN = normalize(mat3(modelMatrix) * normal);
        vV = normalize(cameraPosition - wp.xyz);
        gl_Position = projectionMatrix * viewMatrix * wp;
      }`,
    fragmentShader: `
      uniform vec3 uColor;
      uniform float uPower;
      uniform float uStrength;
      varying vec3 vN;
      varying vec3 vV;
      void main(){
        float f = pow(1.0 - clamp(dot(normalize(vN), normalize(vV)), 0.0, 1.0), uPower);
        gl_FragColor = vec4(uColor * f * uStrength, f);
      }`,
    transparent: true,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
    side: THREE.FrontSide,
  });

export const Brain3D: React.FC<{
  /** Niveau du liquide, 0…1 dans la hauteur du maillage. */
  fill: number;
  /** Le sommet du jour, 0…1. `null` pour ne pas le tracer. */
  summit?: number | null;
  /** Rotation en radians. Le film la pilote, jamais une horloge interne. */
  spin: number;
  /** Teinte du liquide : effort ou repos. */
  tone?: "focus" | "rest" | "critical";
  opacity?: number;
}> = ({fill, summit = null, spin, tone = "focus", opacity = 1}) => {
  const gltf = useLoader(GLTFLoader, staticFile("brain.glb"));
  const {gl} = useThree();
  gl.localClippingEnabled = true;

  // Le maillage arrive dans l'echelle de sa source : on le centre et on le
  // normalise une fois, pas a chaque image.
  const {geometry, height, bottom, radius} = useMemo(() => {
    const parts: THREE.BufferGeometry[] = [];
    gltf.scene.traverse((o) => {
      const m = o as THREE.Mesh;
      if (m.isMesh && m.geometry) {
        const g = m.geometry.clone();
        m.updateWorldMatrix(true, false);
        g.applyMatrix4(m.matrixWorld);
        parts.push(g);
      }
    });
    const merged = parts[0] ?? new THREE.SphereGeometry(1, 32, 32);
    for (let i = 1; i < parts.length; i++) {
      // Une seule geometrie : le maillage d'Optium est deja fusionne en
      // amont, ce chemin ne sert que si la source change.
      merged.groups.push(...parts[i].groups);
    }
    merged.computeBoundingBox();
    const bb = merged.boundingBox!;
    const size = new THREE.Vector3();
    bb.getSize(size);
    const center = new THREE.Vector3();
    bb.getCenter(center);
    // 1,35 unite pour la plus grande dimension. Le cadre est vertical :
    // c'est la LARGEUR visible qui contraint, et elle vaut la hauteur
    // multipliee par 9/16. Normaliser a 2 faisait deborder l'organe.
    const s = 1.35 / Math.max(size.x, size.y, size.z);
    merged.translate(-center.x, -center.y, -center.z);
    merged.scale(s, s, s);
    merged.computeVertexNormals();
    merged.computeBoundingBox();
    const nb = merged.boundingBox!;
    return {
      geometry: merged,
      height: nb.max.y - nb.min.y,
      bottom: nb.min.y,
      // Le rayon de l'anneau suit l'objet, il n'est pas devine.
      radius: Math.max(nb.max.x - nb.min.x, nb.max.z - nb.min.z) / 2 * 1.10,
    };
  }, [gltf]);

  const near = tone === "rest" ? Ink.restGlow : tone === "critical" ? Ink.critical : Ink.focusGlow;
  const far = tone === "rest" ? Ink.restGlowFar : tone === "critical" ? "#8C282C" : Ink.focusGlowFar;

  const level = bottom + height * fill;
  const clip = useMemo(
    () => new THREE.Plane(new THREE.Vector3(0, -1, 0), level),
    [level],
  );

  const shell = useMemo(
    () =>
      new THREE.MeshPhysicalMaterial({
        color: new THREE.Color("#0B0B14"),
        roughness: 0.14,
        metalness: 0,
        clearcoat: 1,
        clearcoatRoughness: 0.08,
        transparent: true,
        opacity: 0.30,
        side: THREE.DoubleSide,
        depthWrite: false,
      }),
    [],
  );

  const liquid = useMemo(
    () =>
      new THREE.MeshStandardMaterial({
        color: new THREE.Color(far),
        emissive: new THREE.Color(near),
        emissiveIntensity: 0.85,
        roughness: 0.28,
        metalness: 0.05,
        transparent: true,
        opacity: 0.96,
      }),
    [near, far],
  );
  liquid.clippingPlanes = [clip];
  liquid.clipShadows = true;

  const rim = useMemo(() => fresnelMaterial(new THREE.Color(near), 2.6, 1.5), [near]);
  const rimLit = useMemo(() => fresnelMaterial(new THREE.Color("#FFFFFF"), 4.2, 0.75), []);

  const group = useRef<THREE.Group>(null);

  return (
    <group ref={group} rotation={[0, spin, 0]}>
      {/* Le liquide, tranche par le plan. Il tourne avec l'organe, mais sa
          surface reste horizontale — c'est ce qui le rend credible. */}
      <mesh geometry={geometry} material={liquid} />
      {/* La coque. En DoubleSide, pour que l'interieur existe. */}
      <mesh geometry={geometry} material={shell} />
      {/* Deux Fresnel : un teinte pour la matiere, un blanc pour l'arete. */}
      <mesh geometry={geometry} material={rim} scale={1.004} />
      <mesh geometry={geometry} material={rimLit} scale={1.012} />

      {/* Le sommet du jour : un anneau plein, jamais un pointille.
          Il se lit comme un rendez-vous, pas comme une barriere. */}
      {summit != null && (
        <mesh
          position={[0, bottom + height * summit, 0]}
          rotation={[Math.PI / 2, 0, 0]}
          // L'anneau ne tourne pas avec l'organe : c'est un repere du monde.
          onUpdate={(m) => {
            m.rotation.set(Math.PI / 2, 0, -spin);
          }}
        >
          <ringGeometry args={[radius, radius + 0.012, 128]} />
          <meshBasicMaterial
            color={Ink.marker}
            transparent
            opacity={fill >= summit - 0.02 ? 0.95 : 0.45}
            side={THREE.DoubleSide}
          />
        </mesh>
      )}
    </group>
  );
};

/** L'eclairage : une cle haute, un contre-jour froid, un remplissage sourd. */
export const BrainLights: React.FC<{tone?: "focus" | "rest" | "critical"}> = ({
  tone = "focus",
}) => {
  const key = tone === "rest" ? Ink.restGlow : tone === "critical" ? Ink.critical : Ink.focusGlow;
  return (
    <>
      <ambientLight intensity={0.35} />
      <directionalLight position={[3, 5, 4]} intensity={2.2} color="#FFFFFF" />
      {/* Le contre-jour detache l'organe du noir. Sans lui, il s'y fond. */}
      <directionalLight position={[-4, 2, -5]} intensity={3.0} color={key} />
      <pointLight position={[0, -2.5, 1.5]} intensity={6} color={key} distance={9} />
    </>
  );
};
