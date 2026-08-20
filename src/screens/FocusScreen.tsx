import { useCallback } from 'react'
import { motion } from 'framer-motion'
import { Play, Pause, SkipForward, CheckCircle2, Circle } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog'
import { BrainScene } from '@/components/BrainScene'
import { useAppStore } from '@/store'
import { useShallow } from 'zustand/react/shallow'

export function SessionScreen() {
    const {
        timerMode, timerSeconds, totalSeconds, isRunning,
        activeTaskId, activeProjectId, projects,
        startTimer, pauseTimer, addTime,
        switchToBreak, switchToFocus,
        addSession, updateTaskStatus,
        setActiveTask,
        showCompletionModal, setShowCompletionModal,
        focusDuration, breakDuration,
    } = useAppStore(
        useShallow((state) => ({
            timerMode: state.timerMode,
            timerSeconds: state.timerSeconds,
            totalSeconds: state.totalSeconds,
            isRunning: state.isRunning,
            activeTaskId: state.activeTaskId,
            activeProjectId: state.activeProjectId,
            projects: state.projects,
            startTimer: state.startTimer,
            pauseTimer: state.pauseTimer,
            addTime: state.addTime,
            switchToBreak: state.switchToBreak,
            switchToFocus: state.switchToFocus,
            addSession: state.addSession,
            updateTaskStatus: state.updateTaskStatus,
            setActiveTask: state.setActiveTask,
            showCompletionModal: state.showCompletionModal,
            setShowCompletionModal: state.setShowCompletionModal,
            focusDuration: state.focusDuration,
            breakDuration: state.breakDuration,
        }))
    )

    const activeProject = activeProjectId ? projects.find(p => p.id === activeProjectId) : null
    const activeTask = activeTaskId ? activeProject?.tasks.find(t => t.id === activeTaskId) : null

    const handleCompleteYes = () => {
        setShowCompletionModal(false)
        if (timerMode === 'focus') {
            if (activeTaskId && activeProjectId) updateTaskStatus(activeProjectId, activeTaskId, 'done')
            switchToBreak()
        } else {
            switchToFocus()
        }
    }

    const handleCompleteNo = () => {
        setShowCompletionModal(false)
        if (timerMode === 'focus') { addTime(5 * 60); startTimer() }
        else switchToFocus()
    }

    const handleEndEarly = () => {
        pauseTimer()
        addSession({ taskId: activeTaskId, projectId: activeProjectId, durationSeconds: totalSeconds - timerSeconds, type: timerMode })
        timerMode === 'focus' ? switchToBreak() : switchToFocus()
    }

    const minutes = Math.floor(timerSeconds / 60)
    const seconds = timerSeconds % 60
    const formattedTime = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
    const progress = totalSeconds > 0 ? ((totalSeconds - timerSeconds) / totalSeconds) * 100 : 0

    return (
        <div className="flex h-full">
            {/* Main session area */}
            <div className="flex-1 flex flex-col min-w-0 p-3 md:p-4 gap-3">
                {/* Active project / task label */}
                {activeProject && (
                    <div className="px-1">
                        <p className="text-xs text-muted-foreground">{activeProject.name}</p>
                        {activeTask && (
                            <p className="text-sm font-medium text-foreground truncate">{activeTask.title}</p>
                        )}
                    </div>
                )}

                {/* Brain card */}
                <div className="flex-1 min-h-0 rounded-xl border border-border bg-card overflow-hidden relative">
                    <BrainScene />
                    {/* Mode badge */}
                    <div className="absolute top-3 left-1/2 -translate-x-1/2 z-10">
                        <span className="text-[11px] font-medium text-muted-foreground bg-background/80 backdrop-blur-sm border border-border px-2.5 py-1 rounded-md">
                            {timerMode === 'focus' ? 'Deep Focus' : 'Break'}
                        </span>
                    </div>
                </div>

                {/* Segmented task progress bar */}
                {activeProject && activeProject.tasks.length > 0 && (
                    <div className="rounded-xl border border-border bg-card px-4 py-3">
                        <div className="flex items-center justify-between mb-2">
                            <span className="text-[10px] text-muted-foreground uppercase tracking-wider font-medium">Task Progress</span>
                            <span className="text-[10px] text-muted-foreground tabular-nums">
                                {activeProject.tasks.filter(t => t.status === 'done').length}/{activeProject.tasks.length}
                            </span>
                        </div>
                        <div className="flex gap-1">
                            {activeProject.tasks.map((task) => {
                                const isDone = task.status === 'done'
                                const isCurrent = task.id === activeTaskId
                                const currentFill = isCurrent && task.estimatedPomodoros > 0
                                    ? (task.completedPomodoros / task.estimatedPomodoros) * 100
                                    : 0
                                return (
                                    <div
                                        key={task.id}
                                        className={`h-1.5 flex-1 rounded-full overflow-hidden transition-colors ${isDone ? 'bg-foreground' : 'bg-secondary'
                                            }`}
                                        title={task.title}
                                    >
                                        {isCurrent && !isDone && (
                                            <div
                                                className="h-full bg-foreground/60 rounded-full transition-all duration-500"
                                                style={{ width: `${currentFill}%` }}
                                            />
                                        )}
                                    </div>
                                )
                            })}
                        </div>
                    </div>
                )}

                {/* Timer card */}
                <div className="rounded-xl border border-border bg-card p-6 flex flex-col items-center">
                    {/* Progress */}
                    <div className="w-full max-w-xs mb-4">
                        <div className="h-1 bg-secondary rounded-full overflow-hidden">
                            <div
                                className="h-full bg-foreground rounded-full transition-all duration-1000 ease-linear"
                                style={{ width: `${progress}%` }}
                            />
                        </div>
                    </div>

                    <div
                        className="text-5xl md:text-6xl font-semibold tracking-tight text-foreground"
                        style={{ fontVariantNumeric: 'tabular-nums' }}
                    >
                        {formattedTime}
                    </div>

                    <p className="text-xs text-muted-foreground mt-1.5 mb-4">
                        {timerMode === 'focus' ? `Focus Session · ${focusDuration} min` : `Break · ${breakDuration} min`}
                    </p>

                    <div className="flex items-center gap-3">
                        <Button
                            variant="default"
                            size="lg"
                            onClick={isRunning ? pauseTimer : startTimer}
                            className="h-10 w-10 p-0 rounded-lg"
                        >
                            {isRunning ? <Pause size={16} /> : <Play size={16} className="ml-0.5" />}
                        </Button>
                    </div>

                    {isRunning && (
                        <motion.button
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            transition={{ delay: 0.5 }}
                            onClick={handleEndEarly}
                            className="flex items-center gap-1.5 mt-3 text-xs text-muted-foreground hover:text-foreground transition-colors"
                        >
                            <SkipForward size={11} /> End early
                        </motion.button>
                    )}
                </div>
            </div>

            {/* Desktop: task preview panel */}
            <aside className="hidden lg:flex flex-col w-[280px] p-3 pl-0">
                <div className="rounded-xl border border-border bg-card overflow-hidden flex-1 flex flex-col">
                    <div className="px-4 py-3 border-b border-border">
                        <h2 className="text-xs font-medium text-foreground">
                            {activeProject ? activeProject.name : 'No Project'}
                        </h2>
                        {activeProject && (
                            <p className="text-[11px] text-muted-foreground mt-0.5 line-clamp-1">{activeProject.description}</p>
                        )}
                    </div>

                    {activeProject && activeProject.tasks.length > 0 ? (
                        <div className="flex-1 overflow-y-auto p-2">
                            {activeProject.tasks.map(task => (
                                <div
                                    key={task.id}
                                    onClick={() => { if (task.status !== 'done') setActiveTask(task.id, activeProject.id) }}
                                    className={`flex items-center gap-2 px-2.5 py-2 rounded-md text-xs transition-colors cursor-pointer ${task.id === activeTaskId
                                        ? 'bg-accent text-accent-foreground'
                                        : 'text-foreground hover:bg-accent/50'
                                        }`}
                                >
                                    {task.status === 'done' ? (
                                        <CheckCircle2
                                            size={13}
                                            className="text-muted-foreground shrink-0 cursor-pointer hover:text-foreground transition-colors"
                                            onClick={(e) => { e.stopPropagation(); updateTaskStatus(activeProject.id, task.id, 'todo') }}
                                        />
                                    ) : (
                                        <Circle
                                            size={13}
                                            className={`shrink-0 cursor-pointer hover:text-foreground transition-colors ${task.id === activeTaskId ? 'text-foreground' : 'text-muted-foreground/40'}`}
                                            onClick={(e) => { e.stopPropagation(); updateTaskStatus(activeProject.id, task.id, 'done') }}
                                        />
                                    )}
                                    <span className={`truncate flex-1 ${task.status === 'done' ? 'text-muted-foreground line-through' : ''}`}>
                                        {task.title}
                                    </span>
                                    <span className="text-[10px] text-muted-foreground shrink-0 tabular-nums">
                                        {task.completedPomodoros}/{task.estimatedPomodoros}
                                    </span>
                                </div>
                            ))}
                        </div>
                    ) : (
                        <div className="flex-1 flex items-center justify-center p-4">
                            <p className="text-[11px] text-muted-foreground text-center leading-relaxed">
                                Select a project and start a task to see progress here.
                            </p>
                        </div>
                    )}
                </div>
            </aside>

            {/* Completion Modal */}
            <Dialog open={showCompletionModal} onOpenChange={setShowCompletionModal}>
                <DialogContent className="sm:max-w-sm">
                    <DialogHeader>
                        <DialogTitle className="text-base">{timerMode === 'focus' ? 'Session Complete' : 'Break Over'}</DialogTitle>
                        <DialogDescription>
                            {timerMode === 'focus' ? 'Ready for a 5-minute break?' : 'Ready to focus again?'}
                        </DialogDescription>
                    </DialogHeader>
                    <DialogFooter className="flex gap-2 sm:gap-2">
                        <Button variant="outline" size="sm" onClick={handleCompleteNo}>
                            {timerMode === 'focus' ? 'Add +5 min' : 'Skip'}
                        </Button>
                        <Button variant="default" size="sm" onClick={handleCompleteYes}>
                            {timerMode === 'focus' ? 'Start Break' : 'Start Focus'}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    )
}
