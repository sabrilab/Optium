import { motion } from 'framer-motion'
import { Timer, FolderOpen, BarChart3, Settings } from 'lucide-react'
import { useAppStore, type Tab } from '@/store'
import { useShallow } from 'zustand/react/shallow'

const tabs: { id: Tab; label: string; icon: typeof Timer }[] = [
    { id: 'session', label: 'Session', icon: Timer },
    { id: 'projects', label: 'Projects', icon: FolderOpen },
    { id: 'stats', label: 'Statistics', icon: BarChart3 },
]

export function TabBar() {
    const { activeTab, setActiveTab } = useAppStore(
        useShallow((state) => ({
            activeTab: state.activeTab,
            setActiveTab: state.setActiveTab,
        }))
    )

    return (
        <nav className="md:hidden flex items-center justify-around px-2 py-2 bg-card/60 backdrop-blur-sm">
            {tabs.map((tab) => {
                const isActive = activeTab === tab.id
                const Icon = tab.icon
                return (
                    <button
                        key={tab.id}
                        onClick={() => setActiveTab(tab.id)}
                        className="relative flex flex-col items-center gap-0.5 py-1.5 px-5 transition-colors"
                    >
                        {isActive && (
                            <motion.div
                                layoutId="tab-indicator"
                                className="absolute inset-0 bg-accent rounded-md"
                                transition={{ type: 'spring', bounce: 0.2, duration: 0.5 }}
                            />
                        )}
                        <Icon
                            size={20}
                            className={`relative z-10 transition-colors ${isActive ? 'text-foreground' : 'text-muted-foreground'}`}
                            strokeWidth={isActive ? 2 : 1.5}
                        />
                        <span className={`relative z-10 text-[10px] font-medium transition-colors ${isActive ? 'text-foreground' : 'text-muted-foreground'}`}>
                            {tab.label}
                        </span>
                    </button>
                )
            })}
            <button
                onClick={() => useAppStore.getState().setSettingsOpen(true)}
                className="flex flex-col items-center gap-0.5 py-1.5 px-3 transition-colors"
            >
                <Settings size={20} className="text-muted-foreground" strokeWidth={1.5} />
                <span className="text-[10px] font-medium text-muted-foreground">Settings</span>
            </button>
        </nav>
    )
}

export function Sidebar() {
    const { activeTab, setActiveTab } = useAppStore(
        useShallow((state) => ({
            activeTab: state.activeTab,
            setActiveTab: state.setActiveTab,
        }))
    )

    return (
        <aside className="hidden md:flex flex-col w-52 shrink-0 bg-card/40 px-3 py-4">
            {/* Logo */}
            <div className="px-2 mb-6">
                <span className="text-lg font-bold tracking-[-0.04em] text-foreground">Optium</span>
            </div>

            {/* Nav items */}
            <nav className="flex flex-col gap-0.5 flex-1">
                {tabs.map((tab) => {
                    const isActive = activeTab === tab.id
                    const Icon = tab.icon
                    return (
                        <button
                            key={tab.id}
                            onClick={() => setActiveTab(tab.id)}
                            className={`flex items-center gap-2.5 px-2.5 py-2 rounded-lg text-sm font-medium transition-colors ${isActive
                                ? 'bg-accent text-foreground'
                                : 'text-muted-foreground hover:bg-accent/50 hover:text-foreground'
                                }`}
                        >
                            <Icon size={16} strokeWidth={isActive ? 2 : 1.5} />
                            {tab.label}
                        </button>
                    )
                })}
            </nav>

            {/* Settings at bottom */}
            <button
                onClick={() => useAppStore.getState().setSettingsOpen(true)}
                className="flex items-center gap-2.5 px-2.5 py-2 rounded-lg text-sm text-muted-foreground hover:bg-accent/50 hover:text-foreground transition-colors"
            >
                <Settings size={16} strokeWidth={1.5} />
                Settings
            </button>
        </aside>
    )
}
