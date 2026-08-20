import { useEffect, useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { LogOut, Settings } from 'lucide-react'
import { TabBar, Sidebar } from '@/components/TabBar'
import { SettingsDialog } from '@/components/SettingsBar'
import { SessionScreen } from '@/screens/FocusScreen'
import { ProjectsScreen } from '@/screens/ProjectsScreen'
import { StatsScreen } from '@/screens/StatsScreen'
import { AuthScreen } from '@/screens/AuthScreen'
import { useAppStore } from '@/store'
import { useTimerTick } from '@/hooks/useTimerTick'
import { supabase } from '@/lib/supabase'
import { useShallow } from 'zustand/react/shallow'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import type { User } from '@supabase/supabase-js'

const screenVariants = {
  initial: { opacity: 0, y: 4 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: -4 },
}

const TAB_TITLES: Record<string, string> = {
  session: 'Session',
  projects: 'Projects',
  stats: 'Statistics',
}

function App() {
  const { activeTab, theme, setSettingsOpen, setUserName } = useAppStore(
    useShallow((state) => ({
      activeTab: state.activeTab,
      theme: state.theme,
      setSettingsOpen: state.setSettingsOpen,
      setUserName: state.setUserName,
    }))
  )
  const [user, setUser] = useState<User | null>(null)
  const [authLoading, setAuthLoading] = useState(true)
  const [showAuth, setShowAuth] = useState(false)

  // Global timer
  useTimerTick()

  // Auth state listener
  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null)
      if (session?.user?.email) setUserName(session.user.email.split('@')[0])
      setAuthLoading(false)
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null)
      if (session?.user?.email) {
        setUserName(session.user.email.split('@')[0])
        setShowAuth(false) // close auth screen on login
      }
    })

    return () => subscription.unsubscribe()
  }, [])

  useEffect(() => {
    document.documentElement.classList.toggle('dark', theme === 'dark')
  }, [theme])

  const handleLogout = async () => {
    await supabase.auth.signOut()
    setUser(null)
  }

  // Show auth screen overlay
  if (showAuth) {
    return (
      <AuthScreen onBack={() => setShowAuth(false)} />
    )
  }

  // Loading
  if (authLoading) {
    return (
      <div className="flex h-full items-center justify-center bg-background">
        <div className="animate-pulse text-muted-foreground text-sm">Loading...</div>
      </div>
    )
  }

  const pseudo = user?.user_metadata?.pseudo
  const displayName = pseudo || user?.email?.split('@')[0] || 'User'
  const initials = displayName.split(/[.\-_ ]/).map((w: string) => w[0]).join('').toUpperCase().slice(0, 2)
  const avatarUrl = user?.user_metadata?.avatar_url
  const job = user?.user_metadata?.job

  return (
    <div className="flex h-full bg-background">
      <Sidebar />

      <div className="flex flex-col flex-1 min-w-0">
        <header className="flex items-center justify-between px-4 md:px-6 py-3">
          <h1 className="text-sm font-semibold text-foreground">{TAB_TITLES[activeTab]}</h1>

          {user ? (
            /* Logged in → avatar + dropdown */
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button className="flex items-center gap-2 px-2 py-1 rounded-lg hover:bg-accent/50 transition-colors outline-none">
                  <Avatar className="h-7 w-7">
                    {avatarUrl && <AvatarImage src={avatarUrl} alt={displayName} className="object-cover" />}
                    <AvatarFallback className="text-[10px] font-medium bg-primary text-primary-foreground">
                      {initials}
                    </AvatarFallback>
                  </Avatar>
                  <span className="text-xs text-muted-foreground hidden sm:block">{displayName}</span>
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-48">
                <div className="px-2 py-1.5">
                  <p className="text-xs font-medium text-foreground">{displayName}</p>
                  {job && <p className="text-[10px] text-muted-foreground mt-0.5">{job}</p>}
                  <p className="text-[10px] text-muted-foreground opacity-70">{user.email}</p>
                </div>
                <DropdownMenuSeparator />
                <DropdownMenuItem onClick={() => setSettingsOpen(true)}>
                  <Settings size={14} className="mr-2" /> Preferences
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem onClick={handleLogout} className="text-destructive">
                  <LogOut size={14} className="mr-2" /> Log out
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          ) : (
            /* Not logged in → Sign in / Sign up buttons */
            <div className="flex items-center gap-2">
              <Button
                variant="ghost"
                size="sm"
                className="h-7 text-xs"
                onClick={() => setShowAuth(true)}
              >
                Sign in
              </Button>
              <Button
                variant="default"
                size="sm"
                className="h-7 text-xs"
                onClick={() => setShowAuth(true)}
              >
                Sign up
              </Button>
            </div>
          )}
        </header>

        <main className="flex-1 min-h-0 relative overflow-hidden">
          <AnimatePresence mode="wait">
            <motion.div
              key={activeTab}
              variants={screenVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              transition={{ duration: 0.15, ease: 'easeOut' }}
              className="absolute inset-0"
            >
              {activeTab === 'session' && <SessionScreen />}
              {activeTab === 'projects' && <ProjectsScreen />}
              {activeTab === 'stats' && <StatsScreen />}
            </motion.div>
          </AnimatePresence>
        </main>

        <TabBar />
      </div>

      <SettingsDialog />
    </div>
  )
}

export default App
