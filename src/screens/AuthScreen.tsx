import { useState } from 'react'
import { motion } from 'framer-motion'
import { Mail, Lock, Loader2, AlertCircle, ArrowLeft, User, Briefcase, Image as ImageIcon } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { supabase } from '@/lib/supabase'

type AuthMode = 'signin' | 'signup'

interface AuthScreenProps {
    onBack?: () => void
}

export function AuthScreen({ onBack }: AuthScreenProps) {
    const [mode, setMode] = useState<AuthMode>('signin')
    const [email, setEmail] = useState('')
    const [password, setPassword] = useState('')
    const [pseudo, setPseudo] = useState('')
    const [job, setJob] = useState('')
    const [avatarUrl, setAvatarUrl] = useState('')
    const [loading, setLoading] = useState(false)
    const [error, setError] = useState<string | null>(null)
    const [success, setSuccess] = useState<string | null>(null)

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)
        setError(null)
        setSuccess(null)

        try {
            if (mode === 'signup') {
                const { error } = await supabase.auth.signUp({
                    email,
                    password,
                    options: {
                        data: {
                            pseudo,
                            job,
                            avatar_url: avatarUrl || null
                        }
                    }
                })
                if (error) throw error
                setSuccess('Account created successfully! You can sign in now.')
                setMode('signin')
            } else {
                const { error } = await supabase.auth.signInWithPassword({ email, password })
                if (error) throw error
            }
        } catch (e: any) {
            setError(e.message || 'An error occurred')
        } finally {
            setLoading(false)
        }
    }

    return (
        <div className="min-h-screen flex items-center justify-center bg-background p-4">
            <motion.div
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.3 }}
                className="w-full max-w-sm"
            >
                {/* Back button */}
                {onBack && (
                    <button
                        onClick={onBack}
                        className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors mb-6"
                    >
                        <ArrowLeft size={14} />
                        Back
                    </button>
                )}

                {/* Branding */}
                <div className="text-center mb-8">
                    <h1 className="text-3xl font-bold tracking-[-0.04em] text-foreground mb-1">Optium</h1>
                    <p className="text-sm text-muted-foreground">Focus smarter, achieve more.</p>
                </div>

                {/* Card */}
                <div className="rounded-xl border border-border bg-card p-6">
                    <h2 className="text-base font-semibold text-foreground mb-1">
                        {mode === 'signin' ? 'Welcome back' : 'Create an account'}
                    </h2>
                    <p className="text-xs text-muted-foreground mb-5">
                        {mode === 'signin'
                            ? 'Sign in to continue to Optium.'
                            : 'Sign up to start tracking your focus.'}
                    </p>

                    <form onSubmit={handleSubmit} className="space-y-3">
                        {mode === 'signup' && (
                            <>
                                <div className="relative">
                                    <User size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
                                    <input
                                        type="text"
                                        placeholder="Pseudo"
                                        value={pseudo}
                                        onChange={(e) => setPseudo(e.target.value)}
                                        required
                                        className="w-full pl-9 pr-3 py-2.5 text-sm border border-input bg-background rounded-lg outline-none focus-visible:ring-1 focus-visible:ring-ring placeholder:text-muted-foreground/50"
                                    />
                                </div>
                                <div className="relative">
                                    <Briefcase size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
                                    <input
                                        type="text"
                                        placeholder="Métier (ex: Web Developer)"
                                        value={job}
                                        onChange={(e) => setJob(e.target.value)}
                                        className="w-full pl-9 pr-3 py-2.5 text-sm border border-input bg-background rounded-lg outline-none focus-visible:ring-1 focus-visible:ring-ring placeholder:text-muted-foreground/50"
                                    />
                                </div>
                                <div className="relative">
                                    <ImageIcon size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
                                    <input
                                        type="url"
                                        placeholder="Avatar URL (optional)"
                                        value={avatarUrl}
                                        onChange={(e) => setAvatarUrl(e.target.value)}
                                        className="w-full pl-9 pr-3 py-2.5 text-sm border border-input bg-background rounded-lg outline-none focus-visible:ring-1 focus-visible:ring-ring placeholder:text-muted-foreground/50"
                                    />
                                </div>
                            </>
                        )}
                        <div className="relative">
                            <Mail size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
                            <input
                                type="email"
                                placeholder="Email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                required
                                className="w-full pl-9 pr-3 py-2.5 text-sm border border-input bg-background rounded-lg outline-none focus-visible:ring-1 focus-visible:ring-ring placeholder:text-muted-foreground/50"
                            />
                        </div>
                        <div className="relative">
                            <Lock size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
                            <input
                                type="password"
                                placeholder="Password"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                required
                                minLength={6}
                                className="w-full pl-9 pr-3 py-2.5 text-sm border border-input bg-background rounded-lg outline-none focus-visible:ring-1 focus-visible:ring-ring placeholder:text-muted-foreground/50"
                            />
                        </div>

                        {error && (
                            <motion.div
                                initial={{ opacity: 0, y: -4 }}
                                animate={{ opacity: 1, y: 0 }}
                                className="flex items-start gap-2 rounded-lg bg-destructive/10 border border-destructive/20 px-3 py-2"
                            >
                                <AlertCircle size={13} className="text-destructive mt-0.5 shrink-0" />
                                <p className="text-[11px] text-destructive">{error}</p>
                            </motion.div>
                        )}

                        {success && (
                            <motion.div
                                initial={{ opacity: 0, y: -4 }}
                                animate={{ opacity: 1, y: 0 }}
                                className="rounded-lg bg-primary/10 border border-primary/20 px-3 py-2"
                            >
                                <p className="text-[11px] text-primary">{success}</p>
                            </motion.div>
                        )}

                        <Button type="submit" className="w-full" disabled={loading}>
                            {loading ? (
                                <Loader2 size={14} className="animate-spin mr-2" />
                            ) : null}
                            {mode === 'signin' ? 'Sign in' : 'Create account'}
                        </Button>
                    </form>

                    <div className="mt-4 text-center">
                        <button
                            onClick={() => { setMode(mode === 'signin' ? 'signup' : 'signin'); setError(null); setSuccess(null) }}
                            className="text-xs text-muted-foreground hover:text-foreground transition-colors"
                        >
                            {mode === 'signin'
                                ? "Don't have an account? Sign up"
                                : 'Already have an account? Sign in'}
                        </button>
                    </div>
                </div>

                <p className="text-center text-[10px] text-muted-foreground/50 mt-4">
                    By continuing, you agree to our terms of service.
                </p>
            </motion.div>
        </div>
    )
}
