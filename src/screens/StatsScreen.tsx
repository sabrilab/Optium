import { useMemo } from 'react'
import { motion } from 'framer-motion'
import { Target, Clock, Flame, TrendingUp, Calendar, MapPin } from 'lucide-react'
import { useAppStore } from '@/store'
import { useShallow } from 'zustand/react/shallow'
import { ActivityChart } from '@/components/ActivityChart'
import { LocationMap } from '@/components/LocationMap'

export function StatsScreen() {
    const { sessions, projects, timerSeconds, totalSeconds, timerMode, getTodaySessions } = useAppStore(
        useShallow((state) => ({
            sessions: state.sessions,
            projects: state.projects,
            timerSeconds: state.timerSeconds,
            totalSeconds: state.totalSeconds,
            timerMode: state.timerMode,
            getTodaySessions: state.getTodaySessions,
        }))
    )

    const todaySessions = useMemo(() => getTodaySessions(), [sessions])
    const todayFocusSessions = todaySessions.filter(s => s.type === 'focus')
    const totalFocusMinutes = Math.round(todayFocusSessions.reduce((sum, s) => sum + s.durationSeconds, 0) / 60)

    const streak = useMemo(() => {
        if (sessions.length === 0) return 0
        const uniqueDays = new Set(
            sessions.filter(s => s.type === 'focus').map(s => {
                const d = new Date(s.createdAt)
                return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`
            })
        )
        let count = 0
        const today = new Date(); today.setHours(0, 0, 0, 0)
        for (let i = 0; i < 365; i++) {
            const d = new Date(today); d.setDate(d.getDate() - i)
            const key = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`
            if (uniqueDays.has(key)) count++
            else if (i > 0) break
        }
        return count
    }, [sessions])

    // Averages
    const averages = useMemo(() => {
        const focusSessions = sessions.filter(s => s.type === 'focus')
        if (focusSessions.length === 0) return { avgMinPerDay: 0, avgSessionsPerDay: 0, bestDay: '—' }

        const dayMap = new Map<string, { minutes: number; count: number }>()
        focusSessions.forEach(s => {
            const d = new Date(s.createdAt)
            const key = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`
            const existing = dayMap.get(key) || { minutes: 0, count: 0 }
            existing.minutes += s.durationSeconds / 60
            existing.count++
            dayMap.set(key, existing)
        })

        const days = Array.from(dayMap.values())
        const totalDays = days.length || 1
        const avgMinPerDay = Math.round(days.reduce((s, d) => s + d.minutes, 0) / totalDays)
        const avgSessionsPerDay = Math.round((days.reduce((s, d) => s + d.count, 0) / totalDays) * 10) / 10

        // Best day of week
        const dayOfWeekMinutes = [0, 0, 0, 0, 0, 0, 0]
        const dayOfWeekCounts = [0, 0, 0, 0, 0, 0, 0]
        focusSessions.forEach(s => {
            const dow = new Date(s.createdAt).getDay()
            dayOfWeekMinutes[dow] += s.durationSeconds / 60
            dayOfWeekCounts[dow]++
        })
        const bestDowIndex = dayOfWeekMinutes.indexOf(Math.max(...dayOfWeekMinutes))
        const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
        const bestDay = dayNames[bestDowIndex]

        return { avgMinPerDay, avgSessionsPerDay, bestDay }
    }, [sessions])

    const statCards = [
        { icon: Target, label: 'Sessions Today', value: todayFocusSessions.length.toString() },
        { icon: Clock, label: 'Focus Time', value: `${totalFocusMinutes}m` },
        { icon: Flame, label: 'Streak', value: `${streak}d` },
    ]

    const avgCards = [
        { icon: TrendingUp, label: 'Avg / Day', value: `${averages.avgMinPerDay}m` },
        { icon: Target, label: 'Avg Sessions', value: averages.avgSessionsPerDay.toString() },
        { icon: Calendar, label: 'Best Day', value: averages.bestDay },
    ]

    return (
        <div className="flex-1 overflow-y-auto p-3 md:p-4">
            {/* Today stats */}
            <div className="grid grid-cols-3 gap-3 mb-4">
                {statCards.map((card, i) => {
                    const Icon = card.icon
                    return (
                        <motion.div
                            key={card.label}
                            initial={{ opacity: 0, y: 6 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ delay: i * 0.04 }}
                            className="rounded-xl border border-border bg-card p-4 flex flex-col items-center gap-1.5"
                        >
                            <Icon size={16} className="text-muted-foreground" strokeWidth={1.5} />
                            <span className="text-xl font-semibold tabular-nums">{card.value}</span>
                            <span className="text-[10px] text-muted-foreground text-center leading-tight">{card.label}</span>
                        </motion.div>
                    )
                })}
            </div>

            {/* Activity chart */}
            <div className="rounded-xl border border-border bg-card p-4 mb-4">
                <h2 className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-4">Last 14 Days</h2>
                <ActivityChart days={14} />
            </div>

            {/* Averages */}
            <div className="grid grid-cols-3 gap-3 mb-4">
                {avgCards.map((card, i) => {
                    const Icon = card.icon
                    return (
                        <motion.div
                            key={card.label}
                            initial={{ opacity: 0, y: 6 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ delay: 0.15 + i * 0.04 }}
                            className="rounded-xl border border-border bg-card p-4 flex flex-col items-center gap-1.5"
                        >
                            <Icon size={16} className="text-muted-foreground" strokeWidth={1.5} />
                            <span className="text-lg font-semibold tabular-nums">{card.value}</span>
                            <span className="text-[10px] text-muted-foreground text-center leading-tight">{card.label}</span>
                        </motion.div>
                    )
                })}
            </div>

            {/* Location map */}
            <div className="rounded-xl border border-border bg-card p-4 mb-4">
                <div className="flex items-center gap-2 mb-3">
                    <MapPin size={14} className="text-muted-foreground" />
                    <h2 className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Work Locations</h2>
                </div>
                <LocationMap />
            </div>

            {/* Timeline */}
            <div className="rounded-xl border border-border bg-card overflow-hidden">
                <div className="px-4 py-3 border-b border-border">
                    <h2 className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Today's Timeline</h2>
                </div>
                {todaySessions.length > 0 ? (
                    <div>
                        {todaySessions.slice().reverse().map((session, i) => (
                            <motion.div
                                key={session.id}
                                initial={{ opacity: 0, x: -4 }}
                                animate={{ opacity: 1, x: 0 }}
                                transition={{ delay: 0.03 * i }}
                                className={`flex items-center gap-2.5 px-4 py-2.5 ${i < todaySessions.length - 1 ? 'border-b border-border' : ''}`}
                            >
                                <div className={`w-1.5 h-1.5 rounded-full shrink-0 ${session.type === 'focus' ? 'bg-foreground' : 'bg-muted-foreground/40'}`} />
                                <span className="text-sm flex-1">{session.type === 'focus' ? 'Focus' : 'Break'}</span>
                                <span className="text-xs text-muted-foreground tabular-nums">{Math.round(session.durationSeconds / 60)}m</span>
                                <span className="text-[11px] text-muted-foreground tabular-nums">
                                    {new Date(session.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                </span>
                            </motion.div>
                        ))}
                    </div>
                ) : (
                    <div className="px-4 py-10 text-center">
                        <p className="text-xs text-muted-foreground">No sessions yet today.</p>
                    </div>
                )}
            </div>
        </div>
    )
}
