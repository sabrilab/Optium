import { useRef, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import { useAppStore } from '@/store'

const vertexShader = `
  uniform vec3 u_boundsMin;
  uniform vec3 u_boundsMax;

  varying vec3 vPosition;
  varying vec3 vNormal;
  varying vec3 vWorldPosition;
  varying float vNormalizedY;

  void main() {
    vPosition = position;
    vNormal = normalize(normalMatrix * normal);
    vWorldPosition = (modelMatrix * vec4(position, 1.0)).xyz;

    // Normalize Y to 0-1 based on actual geometry bounds
    vNormalizedY = (position.y - u_boundsMin.y) / (u_boundsMax.y - u_boundsMin.y);

    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`

const fragmentShader = `
  uniform float u_fillLevel;
  uniform float u_time;
  uniform vec3 u_colorA;
  uniform vec3 u_colorB;
  uniform float u_wobble;

  varying vec3 vPosition;
  varying vec3 vNormal;
  varying vec3 vWorldPosition;
  varying float vNormalizedY;

  // Simple noise for organic movement
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
    // Multi-layered wave distortion at the surface
    float wave1 = sin(vPosition.x * 4.0 + u_time * 1.2) * 0.025;
    float wave2 = sin(vPosition.z * 3.5 + u_time * 0.9) * 0.02;
    float wave3 = sin((vPosition.x + vPosition.z) * 2.5 + u_time * 0.6) * 0.015;

    // Add noise-based wobble for fluid simulation feel
    float noiseVal = noise(vPosition.xz * 2.0 + u_time * 0.5) * 0.03;

    // Wobble from orbit controls interaction
    float wobbleEffect = u_wobble * sin(vPosition.x * 5.0 + u_time * 4.0) * 0.04;

    float totalWave = wave1 + wave2 + wave3 + noiseVal + wobbleEffect;
    float fillEdge = u_fillLevel + totalWave;

    // Smooth fill — below fillEdge = filled, above = empty
    float fill = 1.0 - smoothstep(fillEdge - 0.04, fillEdge + 0.04, vNormalizedY);

    // Discard empty parts (above the fill line)
    if (fill < 0.01) discard;

    // Gradient color inside the liquid
    vec3 baseColor = mix(u_colorA, u_colorB, vNormalizedY * 0.6 + 0.2);

    // Depth-based darkening for volume feel
    float depth = 1.0 - vNormalizedY * 0.3;
    baseColor *= depth;

    // Surface highlight near the fill edge (meniscus effect)
    float surfaceDist = abs(vNormalizedY - fillEdge);
    float surfaceHighlight = smoothstep(0.06, 0.0, surfaceDist) * 0.4;
    baseColor += surfaceHighlight * vec3(0.6, 0.7, 1.0);

    // Fresnel/rim effect for glass-like liquid
    float rimFactor = 1.0 - abs(dot(vNormal, vec3(0.0, 0.0, 1.0)));
    rimFactor = pow(rimFactor, 2.5);
    baseColor += rimFactor * u_colorA * 0.3;

    // Subtle internal caustics
    float caustic = sin(vPosition.x * 20.0 + u_time * 2.0)
                  * sin(vPosition.y * 20.0 + u_time * 1.5)
                  * sin(vPosition.z * 20.0 + u_time * 1.8);
    caustic = pow(max(0.0, caustic), 6.0) * 0.15;
    baseColor += caustic * u_colorB;

    // Alpha: more translucent at the edges, more opaque in the center
    float alpha = fill * (0.55 + rimFactor * 0.15);

    gl_FragColor = vec4(baseColor, alpha);
  }
`

interface FluidMeshProps {
  brainGeometry: THREE.BufferGeometry
  boundsMin: THREE.Vector3
  boundsMax: THREE.Vector3
}

export function FluidMesh({ brainGeometry, boundsMin, boundsMax }: FluidMeshProps) {
  const materialRef = useRef<THREE.ShaderMaterial>(null)
  const { timerMode, timerSeconds, totalSeconds } = useAppStore()
  const wobbleRef = useRef(0)
  const prevRotationRef = useRef(0)

  const fillLevel = useMemo(() => {
    const MAX_FILL = 0.8
    if (totalSeconds === 0) return timerMode === 'focus' ? MAX_FILL : 0.0
    if (timerMode === 'focus') {
      return (timerSeconds / totalSeconds) * MAX_FILL
    } else {
      return (1.0 - (timerSeconds / totalSeconds)) * MAX_FILL
    }
  }, [timerSeconds, totalSeconds, timerMode])

  const focusColorA = useMemo(() => new THREE.Color('#4A90D9'), [])
  const focusColorB = useMemo(() => new THREE.Color('#6C5CE7'), [])
  const breakColorA = useMemo(() => new THREE.Color('#2ECC71'), [])
  const breakColorB = useMemo(() => new THREE.Color('#27AE60'), [])

  const uniforms = useMemo(
    () => ({
      u_fillLevel: { value: 1.0 },
      u_time: { value: 0 },
      u_colorA: { value: focusColorA.clone() },
      u_colorB: { value: focusColorB.clone() },
      u_wobble: { value: 0 },
      u_boundsMin: { value: boundsMin.clone() },
      u_boundsMax: { value: boundsMax.clone() },
    }),
    [focusColorA, focusColorB, boundsMin, boundsMax]
  )

  useFrame((state) => {
    if (!materialRef.current) return

    const mat = materialRef.current

    mat.uniforms.u_time.value = state.clock.elapsedTime
    mat.uniforms.u_fillLevel.value += (fillLevel - mat.uniforms.u_fillLevel.value) * 0.05

    // Detect camera/orbit changes for wobble simulation
    const currentRot = state.camera.rotation.y
    const rotDelta = Math.abs(currentRot - prevRotationRef.current)
    prevRotationRef.current = currentRot
    wobbleRef.current = wobbleRef.current * 0.95 + rotDelta * 8
    wobbleRef.current = Math.min(wobbleRef.current, 1.0)
    mat.uniforms.u_wobble.value = wobbleRef.current

    mat.uniforms.u_mode = mat.uniforms.u_mode || { value: 0 }
    mat.uniforms.u_mode.value = timerMode === 'focus' ? 0 : 1

    const targetA = timerMode === 'focus' ? focusColorA : breakColorA
    const targetB = timerMode === 'focus' ? focusColorB : breakColorB
    mat.uniforms.u_colorA.value.lerp(targetA, 0.02)
    mat.uniforms.u_colorB.value.lerp(targetB, 0.02)
  })

  return (
    <mesh geometry={brainGeometry} scale={1.0}>
      <shaderMaterial
        ref={materialRef}
        vertexShader={vertexShader}
        fragmentShader={fragmentShader}
        uniforms={uniforms}
        transparent
        depthWrite={false}
        side={THREE.DoubleSide}
      />
    </mesh>
  )
}
