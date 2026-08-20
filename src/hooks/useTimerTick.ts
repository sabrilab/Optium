import { useEffect, useRef, useCallback } from 'react'
import { useAppStore } from '@/store'

/**
 * Global timer hook — must be called once at App level.
 * Keeps the pomodoro countdown running regardless of which tab/screen is active.
 * Features: drift correction, browser notifications, long break tracking.
 */
export function useTimerTick() {
    const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

    const isRunning = useAppStore((s) => s.isRunning)
    const timerSeconds = useAppStore((s) => s.timerSeconds)
    const timerMode = useAppStore((s) => s.timerMode)
    const totalSeconds = useAppStore((s) => s.totalSeconds)
    const activeTaskId = useAppStore((s) => s.activeTaskId)
    const activeProjectId = useAppStore((s) => s.activeProjectId)
    const soundEnabled = useAppStore((s) => s.soundEnabled)
    const geoEnabled = useAppStore((s) => s.geoEnabled)

    const tick = useAppStore((s) => s.tick)
    const pauseTimer = useAppStore((s) => s.pauseTimer)
    const addSession = useAppStore((s) => s.addSession)
    const incrementTaskPomodoro = useAppStore((s) => s.incrementTaskPomodoro)
    const setShowCompletionModal = useAppStore((s) => s.setShowCompletionModal)

    const playSound = useCallback(() => {
        try {
            const ctx = new (window.AudioContext || (window as any).webkitAudioContext)()
            const notes = [523.25, 659.25, 783.99]
            notes.forEach((freq, i) => {
                const osc = ctx.createOscillator()
                const gain = ctx.createGain()
                osc.connect(gain); gain.connect(ctx.destination)
                osc.frequency.setValueAtTime(freq, ctx.currentTime + i * 0.15)
                osc.type = 'sine'
                gain.gain.setValueAtTime(0, ctx.currentTime)
                gain.gain.setValueAtTime(0.2, ctx.currentTime + i * 0.15)
                gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + i * 0.15 + 0.5)
                osc.start(ctx.currentTime + i * 0.15)
                osc.stop(ctx.currentTime + i * 0.15 + 0.5)
            })
        } catch { }
    }, [])

    // Send browser notification
    const sendNotification = useCallback((title: string, body: string) => {
        if ('Notification' in window && Notification.permission === 'granted') {
            new Notification(title, {
                body,
                icon: '/favicon.ico',
                badge: '/favicon.ico',
            })
        }
    }, [])

    // Request notification permission on first timer start
    useEffect(() => {
        if (isRunning && 'Notification' in window && Notification.permission === 'default') {
            Notification.requestPermission()
        }
    }, [isRunning])

    // Get user location (cached, only if geo enabled)
    const locationRef = useRef<{ lat: number; lng: number } | undefined>(undefined)
    useEffect(() => {
        if (geoEnabled && navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (pos) => { locationRef.current = { lat: pos.coords.latitude, lng: pos.coords.longitude } },
                () => { /* permission denied — ignore */ },
                { enableHighAccuracy: false, timeout: 5000 }
            )
        } else if (!geoEnabled) {
            locationRef.current = undefined
        }
    }, [geoEnabled])

    // Tick interval
    useEffect(() => {
        if (isRunning && timerSeconds > 0) {
            intervalRef.current = setInterval(() => tick(), 1000)
        } else {
            if (intervalRef.current) { clearInterval(intervalRef.current); intervalRef.current = null }
        }
        return () => { if (intervalRef.current) clearInterval(intervalRef.current) }
    }, [isRunning, timerSeconds, tick])

    // Completion detection
    useEffect(() => {
        if (timerSeconds === 0 && isRunning) {
            pauseTimer()
            if (soundEnabled) playSound()

            // Browser notification
            if (timerMode === 'focus') {
                sendNotification('Session Complete 🎯', 'Time for a break!')
            } else {
                sendNotification('Break Over ☕', 'Ready to focus again?')
            }

            addSession({
                taskId: activeTaskId,
                projectId: activeProjectId,
                durationSeconds: totalSeconds,
                type: timerMode,
                location: geoEnabled ? locationRef.current : undefined,
            })
            if (timerMode === 'focus' && activeTaskId && activeProjectId) {
                incrementTaskPomodoro(activeProjectId, activeTaskId)
            }
            setShowCompletionModal(true)
        }
    }, [timerSeconds, isRunning])
}
