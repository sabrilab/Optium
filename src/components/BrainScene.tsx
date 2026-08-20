import { Suspense, useRef, useMemo, Component, type ReactNode, useState } from 'react'
import { Canvas, useFrame } from '@react-three/fiber'
import { useGLTF, Environment, OrbitControls, Float } from '@react-three/drei'
import * as THREE from 'three'
import { FluidMesh } from './FluidMesh'
import { useAppStore } from '@/store'
import { useShallow } from 'zustand/react/shallow'

class Canvas3DErrorBoundary extends Component<{ children: ReactNode; fallback: ReactNode }, { hasError: boolean }> {
    constructor(props: { children: ReactNode; fallback: ReactNode }) {
        super(props)
        this.state = { hasError: false }
    }
    static getDerivedStateFromError() { return { hasError: true } }
    render() { return this.state.hasError ? this.props.fallback : this.props.children }
}

function BrainModel() {
    const groupRef = useRef<THREE.Group>(null)
    const { timerMode } = useAppStore(useShallow(state => ({ timerMode: state.timerMode })))

    const { scene } = useGLTF('/scene.gltf')

    // Center, scale, and extract geometries
    const { clonedScene, geometries, boundsMin, boundsMax } = useMemo(() => {
        const clone = scene.clone(true)

        // Compute world bounding box
        const box = new THREE.Box3().setFromObject(clone)
        const center = box.getCenter(new THREE.Vector3())
        const size = box.getSize(new THREE.Vector3())

        // Center at origin
        clone.position.sub(center)

        // Normalize scale to fit ~2.5 unit sphere
        const maxDim = Math.max(size.x, size.y, size.z)
        const scale = 2.5 / maxDim
        clone.scale.multiplyScalar(scale)
        clone.position.multiplyScalar(scale)

        // Apply transforms so geometry is in world space
        clone.updateMatrixWorld(true)

        // Collect all geometries with their world transforms applied
        const geos: THREE.BufferGeometry[] = []
        clone.traverse((child) => {
            if ((child as THREE.Mesh).isMesh) {
                const mesh = child as THREE.Mesh
                const geo = mesh.geometry.clone()
                // Apply the mesh's world matrix to the geometry so positions are in world-ish space
                geo.applyMatrix4(mesh.matrixWorld)
                geos.push(geo)
            }
        })

        // Compute bounds of the transformed geometries
        const allBox = new THREE.Box3()
        geos.forEach(geo => {
            geo.computeBoundingBox()
            if (geo.boundingBox) allBox.union(geo.boundingBox)
        })

        const bMin = allBox.min.clone()
        const bMax = allBox.max.clone()

        // Apply glass material
        clone.traverse((child) => {
            if ((child as THREE.Mesh).isMesh) {
                const mesh = child as THREE.Mesh
                mesh.material = new THREE.MeshPhysicalMaterial({
                    color: 0xffffff,
                    transmission: 0.95,
                    opacity: 0.7,
                    transparent: true,
                    roughness: 0.05,
                    metalness: 0.0,
                    ior: 1.52,
                    thickness: 1.2,
                    envMapIntensity: 1.0,
                    clearcoat: 1.0,
                    clearcoatRoughness: 0.05,
                    side: THREE.DoubleSide,
                    depthWrite: false,
                })
            }
        })

        return { clonedScene: clone, geometries: geos, boundsMin: bMin, boundsMax: bMax }
    }, [scene])

    // Float component handles the gentle bobbing animation natively.
    // We removed manual useFrame rotation to prevent conflicts with OrbitControls dragging.

    return (
        <Float speed={1.0} rotationIntensity={0.1} floatIntensity={0.3}>
            <group ref={groupRef}>
                {/* Glass brain shell */}
                <primitive object={clonedScene} />

                {/* Fluid fill inside each mesh */}
                {geometries.map((geo, i) => (
                    <FluidMesh
                        key={i}
                        brainGeometry={geo}
                        boundsMin={boundsMin}
                        boundsMax={boundsMax}
                    />
                ))}
            </group>
        </Float>
    )
}

useGLTF.preload('/scene.gltf')

export function BrainScene() {
    const { timerMode } = useAppStore(useShallow(state => ({ timerMode: state.timerMode })))

    return (
        <div className="w-full h-full relative">
            <Canvas3DErrorBoundary fallback={
                <div className="w-full h-full flex flex-col items-center justify-center gap-2 text-muted-foreground">
                    <span className="text-3xl">🧠</span>
                    <p className="text-xs">3D model unavailable</p>
                </div>
            }>
                <Canvas
                    camera={{ position: [0, 0, 5.5], fov: 40 }}
                    dpr={[1, 1.5]}
                    gl={{
                        antialias: true,
                        alpha: true,
                        toneMapping: THREE.ACESFilmicToneMapping,
                        toneMappingExposure: 1.0,
                    }}
                    style={{ background: 'transparent' }}
                >
                    <Suspense fallback={null}>
                        <ambientLight intensity={0.6} />
                        <directionalLight position={[5, 5, 5]} intensity={0.6} />
                        <directionalLight position={[-3, -2, -5]} intensity={0.2} />
                        <pointLight position={[0, 2, 3]} intensity={0.3} color={timerMode === 'focus' ? '#b0c4e8' : '#b0e8c4'} />
                        <BrainModel />
                        <Environment preset="studio" />
                        <OrbitControls
                            enableZoom={false}
                            enablePan={false}
                            autoRotate
                            autoRotateSpeed={0.3}
                            maxPolarAngle={Math.PI / 1.6}
                            minPolarAngle={Math.PI / 3}
                        />
                    </Suspense>
                </Canvas>
            </Canvas3DErrorBoundary>
        </div>
    )
}
