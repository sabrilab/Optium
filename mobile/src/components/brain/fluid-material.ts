import * as THREE from 'three';

/**
 * Materiau du fluide qui remplit le cerveau au fil de la session.
 *
 * Ecarts assumes par rapport a la version web, tous motives par le GPU mobile :
 *
 *  - `discard` supprime. Les GPU d'iPhone sont a rendu par tuiles : un shader
 *    qui peut rejeter un fragment desactive l'elimination anticipee de la
 *    profondeur pour tout le mesh. On module l'alpha a la place.
 *  - Caustiques internes supprimees. Elles coutaient trois sinus et une
 *    puissance par pixel pour un detail invisible sur un ecran de telephone.
 *  - Le niveau de remplissage est pousse par le rendu (voir brain-scene), pas
 *    par un rendu React : le composant ne se re-rend jamais pendant la session.
 */
const vertexShader = /* glsl */ `
  uniform vec3 u_boundsMin;
  uniform vec3 u_boundsMax;

  varying vec3 vPosition;
  varying vec3 vNormal;
  varying float vNormalizedY;

  void main() {
    vPosition = position;
    vNormal = normalize(normalMatrix * normal);
    vNormalizedY = (position.y - u_boundsMin.y) / (u_boundsMax.y - u_boundsMin.y);
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const fragmentShader = /* glsl */ `
  precision mediump float;

  uniform float u_fillLevel;
  uniform float u_time;
  uniform vec3 u_colorA;
  uniform vec3 u_colorB;
  uniform float u_wobble;

  varying vec3 vPosition;
  varying vec3 vNormal;
  varying float vNormalizedY;

  float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
  }

  float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
  }

  void main() {
    // Surface du liquide : trois ondes de periodes differentes, plus un bruit
    // organique, plus une secousse quand l'utilisateur fait tourner le modele.
    float wave = sin(vPosition.x * 4.0 + u_time * 1.2) * 0.025
               + sin(vPosition.z * 3.5 + u_time * 0.9) * 0.02
               + sin((vPosition.x + vPosition.z) * 2.5 + u_time * 0.6) * 0.015
               + noise(vPosition.xz * 2.0 + u_time * 0.5) * 0.03
               + u_wobble * sin(vPosition.x * 5.0 + u_time * 4.0) * 0.04;

    float fillEdge = u_fillLevel + wave;
    float fill = 1.0 - smoothstep(fillEdge - 0.04, fillEdge + 0.04, vNormalizedY);

    vec3 color = mix(u_colorA, u_colorB, vNormalizedY * 0.6 + 0.2);
    color *= 1.0 - vNormalizedY * 0.3;

    // Menisque : liseré clair a la surface du liquide.
    color += smoothstep(0.06, 0.0, abs(vNormalizedY - fillEdge)) * 0.4 * vec3(0.6, 0.7, 1.0);

    float rim = pow(1.0 - abs(dot(vNormal, vec3(0.0, 0.0, 1.0))), 2.5);
    color += rim * u_colorA * 0.3;

    gl_FragColor = vec4(color, fill * (0.55 + rim * 0.15));
  }
`;

export const FOCUS_COLOR_A = new THREE.Color('#4A90D9');
export const FOCUS_COLOR_B = new THREE.Color('#6C5CE7');
export const BREAK_COLOR_A = new THREE.Color('#2ECC71');
export const BREAK_COLOR_B = new THREE.Color('#27AE60');

export function createFluidMaterial(boundsMin: THREE.Vector3, boundsMax: THREE.Vector3) {
  return new THREE.ShaderMaterial({
    vertexShader,
    fragmentShader,
    uniforms: {
      u_fillLevel: { value: 0.8 },
      u_time: { value: 0 },
      u_colorA: { value: FOCUS_COLOR_A.clone() },
      u_colorB: { value: FOCUS_COLOR_B.clone() },
      u_wobble: { value: 0 },
      u_boundsMin: { value: boundsMin.clone() },
      u_boundsMax: { value: boundsMax.clone() },
    },
    transparent: true,
    depthWrite: false,
    side: THREE.DoubleSide,
  });
}

/**
 * Coque en verre.
 *
 * La version web utilisait un MeshPhysicalMaterial avec `transmission: 0.95`.
 * La transmission oblige three.js a re-rendre toute la scene dans une cible
 * intermediaire a chaque image, et exige en plus une carte d'environnement
 * telechargee depuis un CDN. Un simple effet de Fresnel donne ici une lecture
 * de verre equivalente a cette taille d'affichage, sans passe supplementaire ni
 * dependance reseau.
 */
const shellVertexShader = /* glsl */ `
  varying vec3 vNormal;
  varying vec3 vViewDir;

  void main() {
    vec4 viewPosition = modelViewMatrix * vec4(position, 1.0);
    vNormal = normalize(normalMatrix * normal);
    vViewDir = normalize(-viewPosition.xyz);
    gl_Position = projectionMatrix * viewPosition;
  }
`;

const shellFragmentShader = /* glsl */ `
  precision mediump float;

  uniform vec3 u_tint;

  varying vec3 vNormal;
  varying vec3 vViewDir;

  void main() {
    float fresnel = pow(1.0 - abs(dot(normalize(vNormal), normalize(vViewDir))), 2.5);
    vec3 color = u_tint * (0.3 + fresnel * 1.7);
    gl_FragColor = vec4(color, 0.10 + fresnel * 0.7);
  }
`;

export function createShellMaterial() {
  return new THREE.ShaderMaterial({
    vertexShader: shellVertexShader,
    fragmentShader: shellFragmentShader,
    uniforms: { u_tint: { value: new THREE.Color('#cfe0ff') } },
    transparent: true,
    depthWrite: false,
    // Face avant uniquement : moitie moins de fragments que le DoubleSide de la
    // version web, pour une difference invisible sur une coque translucide.
    side: THREE.FrontSide,
  });
}
