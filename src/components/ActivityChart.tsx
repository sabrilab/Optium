import { useMemo } from 'react'
import { useAppStore } from '@/store'

interface ActivityChartProps {
    days?: number
}

export function ActivityChart({ days = 14 }: ActivityChartProps) {
    const { sessions } = useAppStore()

    const chartData = useMemo(() => {
        const data: { label: string; minutes: number; date: string }[] = []
        const now = new Date()

        for (let i = days - 1; i >= 0; i--) {
            const d = new Date(now)
            d.setDate(d.getDate() - i)
            d.setHours(0, 0, 0, 0)
            const nextDay = new Date(d)
            nextDay.setDate(nextDay.getDate() + 1)

            const dayMs = d.getTime()
            const nextDayMs = nextDay.getTime()

            const dayMinutes = Math.round(
                sessions
                    .filter(s => s.type === 'focus' && s.createdAt >= dayMs && s.createdAt < nextDayMs)
                    .reduce((sum, s) => sum + s.durationSeconds, 0) / 60
            )

            const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            data.push({
                label: dayNames[d.getDay()],
                minutes: dayMinutes,
                date: `${d.getDate()}/${d.getMonth() + 1}`,
            })
        }
        return data
    }, [sessions, days])

    const maxMinutes = Math.max(...chartData.map(d => d.minutes), 1)

    return (
        <div className="space-y-3">
            <div className="flex items-end gap-1 h-32">
                {chartData.map((day, i) => {
                    const height = (day.minutes / maxMinutes) * 100
                    return (
                        <div key={i} className="flex-1 flex flex-col items-center gap-1 group relative">
                            {/* Tooltip */}
                            <div className="absolute -top-7 left-1/2 -translate-x-1/2 opacity-0 group-hover:opacity-100 transition-opacity bg-popover text-popover-foreground text-[10px] px-1.5 py-0.5 rounded border border-border whitespace-nowrap z-10">
                                {day.minutes}m · {day.date}
                            </div>
                            <div
                                className="w-full rounded-sm bg-primary/70 hover:bg-primary transition-colors cursor-default"
                                style={{ height: `${Math.max(height, 2)}%` }}
                            />
                        </div>
                    )
                })}
            </div>
            <div className="flex gap-1">
                {chartData.map((day, i) => (
                    <div key={i} className="flex-1 text-center text-[9px] text-muted-foreground">
                        {day.label}
                    </div>
                ))}
            </div>
        </div>
    )
}
