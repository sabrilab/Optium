import { Settings, Sun, Moon, Volume2, VolumeX, Clock, MapPin, Bell, Coffee } from 'lucide-react'
import { Switch } from '@/components/ui/switch'
import { Button } from '@/components/ui/button'
import { useAppStore } from '@/store'
import { useShallow } from 'zustand/react/shallow'
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog'

export function SettingsButton() {
    const { setSettingsOpen } = useAppStore(
        useShallow((state) => ({ setSettingsOpen: state.setSettingsOpen }))
    )

    return (
        <Button
            variant="ghost"
            size="icon"
            onClick={() => setSettingsOpen(true)}
            className="h-8 w-8"
        >
            <Settings size={16} />
        </Button>
    )
}

function DurationSlider({ label, icon: Icon, value, min, max, step, onChange }: {
    label: string
    icon: typeof Clock
    value: number
    min: number
    max: number
    step: number
    onChange: (v: number) => void
}) {
    return (
        <div className="space-y-1.5">
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                    <Icon size={14} className="text-muted-foreground" />
                    <span className="text-xs text-foreground">{label}</span>
                </div>
                <span className="text-xs font-medium tabular-nums text-muted-foreground">{value} min</span>
            </div>
            <input
                type="range"
                min={min}
                max={max}
                step={step}
                value={value}
                onChange={(e) => onChange(parseInt(e.target.value))}
                className="w-full h-1.5 bg-secondary rounded-full appearance-none cursor-pointer accent-primary"
            />
        </div>
    )
}

export function SettingsDialog() {
    const {
        settingsOpen, setSettingsOpen,
        theme, toggleTheme,
        soundEnabled, toggleSound,
        geoEnabled, toggleGeo,
        focusDuration, setFocusDuration,
        breakDuration, setBreakDuration,
        longBreakDuration, setLongBreakDuration,
    } = useAppStore(
        useShallow((state) => ({
            settingsOpen: state.settingsOpen,
            setSettingsOpen: state.setSettingsOpen,
            theme: state.theme,
            toggleTheme: state.toggleTheme,
            soundEnabled: state.soundEnabled,
            toggleSound: state.toggleSound,
            geoEnabled: state.geoEnabled,
            toggleGeo: state.toggleGeo,
            focusDuration: state.focusDuration,
            setFocusDuration: state.setFocusDuration,
            breakDuration: state.breakDuration,
            setBreakDuration: state.setBreakDuration,
            longBreakDuration: state.longBreakDuration,
            setLongBreakDuration: state.setLongBreakDuration,
        }))
    )

    const handleNotificationPermission = () => {
        if ('Notification' in window) {
            Notification.requestPermission()
        }
    }

    const notificationStatus = typeof Notification !== 'undefined' ? Notification.permission : 'denied'

    return (
        <Dialog open={settingsOpen} onOpenChange={setSettingsOpen}>
            <DialogContent className="sm:max-w-sm">
                <DialogHeader>
                    <DialogTitle>Settings</DialogTitle>
                </DialogHeader>
                <div className="space-y-5 pt-2">
                    {/* Appearance */}
                    <div className="space-y-3">
                        <p className="text-[10px] uppercase tracking-wider font-medium text-muted-foreground">Appearance</p>
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-2.5">
                                {theme === 'dark' ? <Moon size={14} /> : <Sun size={14} />}
                                <span className="text-xs">{theme === 'dark' ? 'Dark Mode' : 'Light Mode'}</span>
                            </div>
                            <Switch checked={theme === 'dark'} onCheckedChange={toggleTheme} />
                        </div>
                    </div>

                    {/* Timer durations */}
                    <div className="space-y-3">
                        <p className="text-[10px] uppercase tracking-wider font-medium text-muted-foreground">Timer Durations</p>
                        <DurationSlider label="Focus" icon={Clock} value={focusDuration} min={15} max={60} step={5} onChange={setFocusDuration} />
                        <DurationSlider label="Short Break" icon={Coffee} value={breakDuration} min={3} max={15} step={1} onChange={setBreakDuration} />
                        <DurationSlider label="Long Break" icon={Coffee} value={longBreakDuration} min={10} max={30} step={5} onChange={setLongBreakDuration} />
                        <p className="text-[10px] text-muted-foreground">Long break every 4 focus sessions.</p>
                    </div>

                    {/* Notifications & Sound */}
                    <div className="space-y-3">
                        <p className="text-[10px] uppercase tracking-wider font-medium text-muted-foreground">Notifications</p>
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-2.5">
                                {soundEnabled ? <Volume2 size={14} /> : <VolumeX size={14} />}
                                <span className="text-xs">Sound Effects</span>
                            </div>
                            <Switch checked={soundEnabled} onCheckedChange={toggleSound} />
                        </div>
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-2.5">
                                <Bell size={14} />
                                <span className="text-xs">Browser Notifications</span>
                            </div>
                            {notificationStatus === 'granted' ? (
                                <span className="text-[10px] text-primary font-medium">Enabled</span>
                            ) : (
                                <Button variant="outline" size="sm" className="h-6 text-[10px] px-2" onClick={handleNotificationPermission}>
                                    Enable
                                </Button>
                            )}
                        </div>
                    </div>

                    {/* Privacy */}
                    <div className="space-y-3">
                        <p className="text-[10px] uppercase tracking-wider font-medium text-muted-foreground">Privacy</p>
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-2.5">
                                <MapPin size={14} />
                                <div>
                                    <span className="text-xs">Location Tracking</span>
                                    <p className="text-[10px] text-muted-foreground leading-tight">Track where you work for stats</p>
                                </div>
                            </div>
                            <Switch checked={geoEnabled} onCheckedChange={toggleGeo} />
                        </div>
                    </div>
                </div>
            </DialogContent>
        </Dialog>
    )
}
