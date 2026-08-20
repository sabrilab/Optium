import { useMemo, useEffect, useRef } from 'react'
import { useAppStore } from '@/store'
import 'leaflet/dist/leaflet.css'

export function LocationMap() {
    const { sessions } = useAppStore()
    const mapRef = useRef<HTMLDivElement>(null)
    const mapInstanceRef = useRef<any>(null)

    const locations = useMemo(() => {
        const locs: { lat: number; lng: number; count: number; minutes: number }[] = []
        const focusSessions = sessions.filter(s => s.type === 'focus' && s.location)

        // Group by rough location (round to ~100m)
        const grouped = new Map<string, { lat: number; lng: number; count: number; minutes: number }>()
        focusSessions.forEach(s => {
            if (!s.location) return
            const key = `${s.location.lat.toFixed(3)},${s.location.lng.toFixed(3)}`
            const existing = grouped.get(key)
            if (existing) {
                existing.count++
                existing.minutes += Math.round(s.durationSeconds / 60)
            } else {
                grouped.set(key, { lat: s.location.lat, lng: s.location.lng, count: 1, minutes: Math.round(s.durationSeconds / 60) })
            }
        })
        grouped.forEach(v => locs.push(v))
        return locs
    }, [sessions])

    useEffect(() => {
        if (!mapRef.current || mapInstanceRef.current) return

        // Dynamically import leaflet to avoid SSR issues
        import('leaflet').then((L) => {
            if (!mapRef.current) return

            const defaultCenter: [number, number] = locations.length > 0
                ? [locations[0].lat, locations[0].lng]
                : [48.8566, 2.3522] // Paris default

            const map = L.map(mapRef.current, {
                zoomControl: false,
                attributionControl: false,
            }).setView(defaultCenter, 13)

            L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
                maxZoom: 19,
            }).addTo(map)

            // Add markers
            locations.forEach(loc => {
                const radius = Math.min(20, 6 + loc.count * 2)
                L.circleMarker([loc.lat, loc.lng], {
                    radius,
                    fillColor: '#6366f1',
                    color: '#818cf8',
                    weight: 1,
                    opacity: 0.8,
                    fillOpacity: 0.6,
                }).addTo(map).bindPopup(
                    `<div style="font-size:12px;"><strong>${loc.count} sessions</strong><br/>${loc.minutes} min focus</div>`
                )
            })

            mapInstanceRef.current = map
        })

        return () => {
            if (mapInstanceRef.current) {
                mapInstanceRef.current.remove()
                mapInstanceRef.current = null
            }
        }
    }, [locations])

    if (locations.length === 0) {
        return (
            <div className="h-48 flex items-center justify-center text-xs text-muted-foreground">
                <p>Location tracking will appear here after your first session with geolocation enabled.</p>
            </div>
        )
    }

    return (
        <div ref={mapRef} className="h-48 rounded-lg overflow-hidden" style={{ zIndex: 0 }} />
    )
}
