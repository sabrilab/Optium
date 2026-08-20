import { useState, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
    Sparkles, Play, CheckCircle2, Circle, Loader2, Plus, Trash2,
    FolderOpen, ArrowLeft, GripVertical, Clock, Check, Send, Bot, User, ChevronDown, ChevronUp
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { Progress } from '@/components/ui/progress'
import { Skeleton } from '@/components/ui/skeleton'
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog'
import { useAppStore } from '@/store'
import { useShallow } from 'zustand/react/shallow'
import { generateTasks } from '@/lib/api'

export function ProjectsScreen() {
    const {
        projects, selectedProjectId, setSelectedProjectId,
        addProject, deleteProject, addTasksToProject, deleteTask, reorderTasks,
        setActiveTask, setActiveTab, switchToFocus, updateTaskStatus,
        updateTaskPomodoros, toggleProjectStatus, addAiMessage, getProjectTimeSpent, sessions,
    } = useAppStore(
        useShallow((state) => ({
            projects: state.projects,
            selectedProjectId: state.selectedProjectId,
            setSelectedProjectId: state.setSelectedProjectId,
            addProject: state.addProject,
            deleteProject: state.deleteProject,
            addTasksToProject: state.addTasksToProject,
            deleteTask: state.deleteTask,
            reorderTasks: state.reorderTasks,
            setActiveTask: state.setActiveTask,
            setActiveTab: state.setActiveTab,
            switchToFocus: state.switchToFocus,
            updateTaskStatus: state.updateTaskStatus,
            updateTaskPomodoros: state.updateTaskPomodoros,
            toggleProjectStatus: state.toggleProjectStatus,
            addAiMessage: state.addAiMessage,
            getProjectTimeSpent: state.getProjectTimeSpent,
            sessions: state.sessions,
        }))
    )

    const [showCreate, setShowCreate] = useState(false)
    const [newName, setNewName] = useState('')
    const [newDesc, setNewDesc] = useState('')
    const [taskPrompt, setTaskPrompt] = useState('')
    const [isGenerating, setIsGenerating] = useState(false)
    const [error, setError] = useState<string | null>(null)
    const [deleteConfirm, setDeleteConfirm] = useState<string | null>(null)
    const [showAiChat, setShowAiChat] = useState(false)
    const [editingPomodoroId, setEditingPomodoroId] = useState<string | null>(null)
    const [editingPomodoroValue, setEditingPomodoroValue] = useState(1)

    const [manualTaskName, setManualTaskName] = useState('')
    const [manualPomodoros, setManualPomodoros] = useState(1)

    const dragItem = useRef<number | null>(null)
    const dragOverItem = useRef<number | null>(null)
    const [dragOverIndex, setDragOverIndex] = useState<number | null>(null)

    const selectedProject = selectedProjectId ? projects.find(p => p.id === selectedProjectId) : null

    const handleCreateProject = () => {
        if (!newName.trim()) return
        addProject(newName.trim(), newDesc.trim())
        setNewName('')
        setNewDesc('')
        setShowCreate(false)
    }

    const handleManualAddTask = () => {
        if (!manualTaskName.trim() || !selectedProjectId) return
        addTasksToProject(selectedProjectId, [
            { title: manualTaskName.trim(), estimated_pomodoros: manualPomodoros }
        ])
        setManualTaskName('')
        setManualPomodoros(1)
    }

    const handleGenerateTasks = async () => {
        if (!taskPrompt.trim() || !selectedProjectId || !selectedProject) return
        setIsGenerating(true)
        setError(null)

        // Save user message to AI history
        addAiMessage(selectedProjectId, { role: 'user', content: taskPrompt.trim(), timestamp: Date.now() })

        try {
            const tasks = await generateTasks(taskPrompt.trim())
            addTasksToProject(selectedProjectId, tasks)
            // Save AI response to history
            const aiResponse = tasks.map(t => `• ${t.title} (${t.estimated_pomodoros} pomodoros)`).join('\n')
            addAiMessage(selectedProjectId, { role: 'ai', content: `Generated ${tasks.length} tasks:\n${aiResponse}`, timestamp: Date.now() })
            setTaskPrompt('')
        } catch (e) {
            const errMsg = e instanceof Error ? e.message : 'Failed to generate tasks'
            setError(errMsg)
            addAiMessage(selectedProjectId, { role: 'ai', content: `Error: ${errMsg}`, timestamp: Date.now() })
        } finally {
            setIsGenerating(false)
        }
    }

    const handleStartTask = (projectId: string, taskId: string) => {
        setActiveTask(taskId, projectId)
        switchToFocus()
        setActiveTab('session')
    }

    const formatTimeSpent = (seconds: number) => {
        if (seconds < 60) return '0m'
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.round((seconds % 3600) / 60)
        return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`
    }

    return (
        <div className="flex h-full">
            {/* Folder list panel */}
            <div className={`${selectedProject ? 'hidden md:flex' : 'flex'} flex-col md:w-[240px] bg-background`}>
                <div className="flex items-center justify-between px-4 pt-4 pb-3">
                    <h1 className="text-sm font-medium">Projects</h1>
                    <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => setShowCreate(true)}>
                        <Plus size={14} />
                    </Button>
                </div>
                <div className="flex-1 overflow-y-auto px-3 pb-3">
                    <div className="grid grid-cols-2 md:grid-cols-1 gap-2">
                        <AnimatePresence>
                            {projects.map((project, i) => {
                                const isSelected = selectedProjectId === project.id
                                const isCompleted = project.status === 'completed'
                                return (
                                    <motion.button
                                        key={project.id}
                                        initial={{ opacity: 0, scale: 0.95 }}
                                        animate={{ opacity: 1, scale: 1 }}
                                        exit={{ opacity: 0, scale: 0.95 }}
                                        transition={{ delay: i * 0.02 }}
                                        onClick={() => setSelectedProjectId(project.id)}
                                        onContextMenu={(e) => { e.preventDefault(); setDeleteConfirm(project.id) }}
                                        className={`flex flex-col items-center gap-1 p-3 rounded-xl border transition-colors text-center group ${isSelected
                                            ? 'border-foreground/20 bg-accent'
                                            : 'border-transparent hover:bg-accent/50'
                                            } ${isCompleted ? 'opacity-60' : ''}`}
                                    >
                                        <FolderOpen
                                            size={22}
                                            style={{ color: project.color }}
                                            strokeWidth={1.5}
                                        />
                                        <span className={`text-[11px] font-medium leading-tight line-clamp-2 ${isCompleted ? 'line-through' : ''}`}>
                                            {project.name}
                                        </span>
                                    </motion.button>
                                )
                            })}
                        </AnimatePresence>
                    </div>
                    {projects.length === 0 && (
                        <div className="text-center py-10">
                            <FolderOpen size={28} className="mx-auto text-muted-foreground/30 mb-2" />
                            <p className="text-xs text-muted-foreground">No projects yet</p>
                        </div>
                    )}
                </div>
            </div>

            {/* Project detail panel */}
            {selectedProject ? (
                <div className="flex-1 flex flex-col min-w-0 p-3 md:p-4">
                    {/* Header card */}
                    <div className="rounded-xl border border-border bg-card p-4 mb-3">
                        <div className="flex items-start gap-3">
                            <button
                                onClick={() => setSelectedProjectId(null)}
                                className="md:hidden mt-0.5 text-muted-foreground hover:text-foreground transition-colors"
                            >
                                <ArrowLeft size={16} />
                            </button>
                            <div className="flex-1 min-w-0">
                                <div className="flex items-center gap-2">
                                    <h2 className={`text-base font-semibold truncate ${selectedProject.status === 'completed' ? 'line-through text-muted-foreground' : ''}`}>
                                        {selectedProject.name}
                                    </h2>
                                    {selectedProject.status === 'completed' && (
                                        <span className="text-[10px] px-1.5 py-0.5 rounded bg-accent text-muted-foreground font-medium">Done</span>
                                    )}
                                </div>
                                <p className="text-xs text-muted-foreground mt-0.5 truncate">{selectedProject.description}</p>
                                <div className="flex items-center gap-3 mt-2">
                                    <span className="text-[10px] text-muted-foreground flex items-center gap-1">
                                        <Clock size={10} /> {formatTimeSpent(getProjectTimeSpent(selectedProject.id))}
                                    </span>
                                    <span className="text-[10px] text-muted-foreground">
                                        {selectedProject.tasks.filter(t => t.status === 'done').length}/{selectedProject.tasks.length} tasks
                                    </span>
                                </div>
                            </div>
                            <div className="flex items-center gap-1">
                                <Button
                                    variant="outline"
                                    size="sm"
                                    className="h-7 text-[11px]"
                                    onClick={() => toggleProjectStatus(selectedProject.id)}
                                >
                                    {selectedProject.status === 'completed' ? 'Reopen' : (
                                        <><Check size={11} className="mr-1" /> Complete</>
                                    )}
                                </Button>
                                <Button variant="ghost" size="icon" className="h-7 w-7 text-muted-foreground hover:text-destructive" onClick={() => setDeleteConfirm(selectedProject.id)}>
                                    <Trash2 size={13} />
                                </Button>
                            </div>
                        </div>
                        <Progress
                            value={selectedProject.tasks.length ? (selectedProject.tasks.filter(t => t.status === 'done').length / selectedProject.tasks.length) * 100 : 0}
                            className="h-1 mt-3"
                        />
                    </div>

                    {/* AI Assist — collapsible */}
                    <div className="rounded-xl border border-border bg-card mb-3 overflow-hidden">
                        <button
                            onClick={() => setShowAiChat(!showAiChat)}
                            className="w-full flex items-center justify-between px-4 py-2.5 text-xs font-medium text-muted-foreground hover:text-foreground transition-colors"
                        >
                            <span className="flex items-center gap-1.5">
                                <Sparkles size={12} /> AI Task Assistant
                            </span>
                            {showAiChat ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                        </button>

                        <AnimatePresence>
                            {showAiChat && (
                                <motion.div
                                    initial={{ height: 0, opacity: 0 }}
                                    animate={{ height: 'auto', opacity: 1 }}
                                    exit={{ height: 0, opacity: 0 }}
                                    transition={{ duration: 0.2 }}
                                >
                                    {/* AI History */}
                                    {selectedProject.aiHistory && selectedProject.aiHistory.length > 0 && (
                                        <div className="max-h-40 overflow-y-auto px-4 space-y-2 mb-2">
                                            {selectedProject.aiHistory.map((msg, i) => (
                                                <div key={i} className={`flex gap-2 text-[11px] ${msg.role === 'user' ? 'justify-end' : ''}`}>
                                                    {msg.role === 'ai' && <Bot size={12} className="text-muted-foreground mt-0.5 shrink-0" />}
                                                    <div className={`rounded-lg px-2.5 py-1.5 max-w-[80%] whitespace-pre-wrap ${msg.role === 'user'
                                                        ? 'bg-primary text-primary-foreground'
                                                        : 'bg-accent text-accent-foreground'
                                                        }`}>
                                                        {msg.content}
                                                    </div>
                                                    {msg.role === 'user' && <User size={12} className="text-muted-foreground mt-0.5 shrink-0" />}
                                                </div>
                                            ))}
                                        </div>
                                    )}

                                    {/* Input */}
                                    <div className="px-4 pb-3 flex gap-2">
                                        <Textarea
                                            placeholder="Describe tasks to generate..."
                                            value={taskPrompt}
                                            onChange={(e) => setTaskPrompt(e.target.value)}
                                            className="min-h-[48px] max-h-[80px] resize-none text-xs"
                                            disabled={isGenerating}
                                            onKeyDown={(e) => {
                                                if (e.key === 'Enter' && !e.shiftKey) {
                                                    e.preventDefault()
                                                    handleGenerateTasks()
                                                }
                                            }}
                                        />
                                        <Button
                                            onClick={handleGenerateTasks}
                                            disabled={!taskPrompt.trim() || isGenerating}
                                            size="sm"
                                            className="h-auto px-3"
                                        >
                                            {isGenerating ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />}
                                        </Button>
                                    </div>
                                    {error && <p className="px-4 pb-2 text-[11px] text-destructive">{error}</p>}
                                </motion.div>
                            )}
                        </AnimatePresence>
                    </div>

                    {/* Loading skeleton */}
                    {isGenerating && (
                        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-2 mb-3">
                            {[...Array(3)].map((_, i) => (
                                <div key={i} className="flex items-center gap-2.5 p-3 rounded-xl border border-border bg-card">
                                    <Skeleton className="h-3.5 w-3.5 rounded" />
                                    <Skeleton className="h-3 w-3/4" />
                                    <Skeleton className="h-6 w-12 ml-auto rounded-md" />
                                </div>
                            ))}
                        </motion.div>
                    )}

                    {/* Task list + inline add */}
                    <div className="flex-1 overflow-y-auto">
                        <div className="rounded-xl border border-border bg-card overflow-hidden">
                            {selectedProject.tasks.map((task, i) => (
                                <div
                                    key={task.id}
                                    draggable
                                    onDragStart={() => { dragItem.current = i }}
                                    onDragEnter={() => { dragOverItem.current = i; setDragOverIndex(i) }}
                                    onDragOver={(e) => e.preventDefault()}
                                    onDragEnd={() => {
                                        if (dragItem.current !== null && dragOverItem.current !== null && dragItem.current !== dragOverItem.current) {
                                            reorderTasks(selectedProject.id, dragItem.current, dragOverItem.current)
                                        }
                                        dragItem.current = null
                                        dragOverItem.current = null
                                        setDragOverIndex(null)
                                    }}
                                    className={`flex items-center gap-1.5 px-2 py-3 text-sm border-b border-border hover:bg-accent/30 transition-colors group ${dragOverIndex === i ? 'border-t-2 border-t-primary' : ''
                                        }`}
                                >
                                    <GripVertical
                                        size={14}
                                        className="shrink-0 text-muted-foreground/30 cursor-grab active:cursor-grabbing group-hover:text-muted-foreground transition-colors"
                                    />
                                    {task.status === 'done' ? (
                                        <CheckCircle2
                                            size={14}
                                            className="text-muted-foreground shrink-0 cursor-pointer hover:text-foreground transition-colors"
                                            onClick={(e) => { e.stopPropagation(); updateTaskStatus(selectedProject.id, task.id, 'todo') }}
                                        />
                                    ) : (
                                        <Circle
                                            size={14}
                                            className={`shrink-0 cursor-pointer hover:text-foreground transition-colors ${task.status === 'in_progress' ? 'text-foreground' : 'text-muted-foreground/40'}`}
                                            onClick={(e) => { e.stopPropagation(); updateTaskStatus(selectedProject.id, task.id, 'done') }}
                                        />
                                    )}
                                    <div className="flex-1 min-w-0 ml-1">
                                        <p className={`text-sm leading-tight truncate ${task.status === 'done' ? 'text-muted-foreground line-through' : ''}`}>{task.title}</p>
                                    </div>
                                    {/* Editable pomodoro count */}
                                    {editingPomodoroId === task.id ? (
                                        <input
                                            type="number"
                                            min="1"
                                            max="20"
                                            value={editingPomodoroValue}
                                            onChange={(e) => setEditingPomodoroValue(parseInt(e.target.value) || 1)}
                                            onBlur={() => {
                                                updateTaskPomodoros(selectedProject.id, task.id, editingPomodoroValue)
                                                setEditingPomodoroId(null)
                                            }}
                                            onKeyDown={(e) => {
                                                if (e.key === 'Enter') {
                                                    updateTaskPomodoros(selectedProject.id, task.id, editingPomodoroValue)
                                                    setEditingPomodoroId(null)
                                                }
                                            }}
                                            autoFocus
                                            className="w-10 text-center text-[10px] bg-accent border border-input rounded py-0.5 outline-none focus-visible:ring-1 focus-visible:ring-ring"
                                        />
                                    ) : (
                                        <button
                                            onClick={() => { setEditingPomodoroId(task.id); setEditingPomodoroValue(task.estimatedPomodoros) }}
                                            className="text-[10px] text-muted-foreground tabular-nums hover:text-foreground transition-colors px-1 rounded hover:bg-accent"
                                            title="Click to edit pomodoros"
                                        >
                                            {task.completedPomodoros}/{task.estimatedPomodoros} 🍅
                                        </button>
                                    )}
                                    {task.status !== 'done' && (
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            className="h-7 px-2 text-[11px] shrink-0"
                                            onClick={() => handleStartTask(selectedProject.id, task.id)}
                                        >
                                            <Play size={9} className="mr-1" /> Start
                                        </Button>
                                    )}
                                    <button
                                        className="shrink-0 text-muted-foreground/30 hover:text-destructive transition-colors opacity-0 group-hover:opacity-100"
                                        onClick={(e) => { e.stopPropagation(); deleteTask(selectedProject.id, task.id) }}
                                        title="Delete task"
                                    >
                                        <Trash2 size={13} />
                                    </button>
                                </div>
                            ))}

                            {/* Inline add task row */}
                            <div className="flex items-center gap-2 px-4 py-2.5">
                                <Plus size={14} className="text-muted-foreground/40 shrink-0" />
                                <input
                                    type="text"
                                    placeholder="Add a task..."
                                    value={manualTaskName}
                                    onChange={(e) => setManualTaskName(e.target.value)}
                                    onKeyDown={(e) => {
                                        if (e.key === 'Enter') {
                                            e.preventDefault()
                                            handleManualAddTask()
                                        }
                                    }}
                                    className="flex-1 bg-transparent text-sm outline-none placeholder:text-muted-foreground/40"
                                />
                                <input
                                    type="number"
                                    min="1"
                                    max="10"
                                    value={manualPomodoros}
                                    onChange={(e) => setManualPomodoros(parseInt(e.target.value) || 1)}
                                    className="w-12 text-center text-xs bg-transparent border border-input rounded-md py-1 outline-none focus-visible:ring-1 focus-visible:ring-ring"
                                    title="Estimated pomodoros"
                                />
                                <Button
                                    type="button"
                                    size="sm"
                                    variant="ghost"
                                    className="h-7 px-2 text-xs shrink-0"
                                    disabled={!manualTaskName.trim()}
                                    onClick={handleManualAddTask}
                                >
                                    Add
                                </Button>
                            </div>
                        </div>

                        {selectedProject.tasks.length === 0 && !isGenerating && (
                            <div className="text-center py-8">
                                <p className="text-xs text-muted-foreground">No tasks yet — use AI or add manually above.</p>
                            </div>
                        )}
                    </div>
                </div>
            ) : (
                <div className="hidden md:flex flex-1 items-center justify-center">
                    <p className="text-xs text-muted-foreground">Select a project to view details</p>
                </div>
            )}

            {/* Create dialog */}
            <Dialog open={showCreate} onOpenChange={setShowCreate}>
                <DialogContent className="sm:max-w-sm">
                    <DialogHeader>
                        <DialogTitle className="text-base">New Project</DialogTitle>
                        <DialogDescription>Create a new project to organize your tasks.</DialogDescription>
                    </DialogHeader>
                    <div className="space-y-3 pt-2">
                        <input
                            type="text"
                            placeholder="Project name"
                            value={newName}
                            onChange={(e) => setNewName(e.target.value)}
                            className="w-full px-3 py-2 text-sm border border-input bg-background rounded-md outline-none focus-visible:ring-1 focus-visible:ring-ring"
                            onKeyDown={(e) => { if (e.key === 'Enter') handleCreateProject() }}
                        />
                        <input
                            type="text"
                            placeholder="Description (optional)"
                            value={newDesc}
                            onChange={(e) => setNewDesc(e.target.value)}
                            className="w-full px-3 py-2 text-sm border border-input bg-background rounded-md outline-none focus-visible:ring-1 focus-visible:ring-ring"
                            onKeyDown={(e) => { if (e.key === 'Enter') handleCreateProject() }}
                        />
                    </div>
                    <DialogFooter>
                        <Button size="sm" onClick={handleCreateProject} disabled={!newName.trim()}>Create</Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            {/* Delete confirmation */}
            <Dialog open={!!deleteConfirm} onOpenChange={() => setDeleteConfirm(null)}>
                <DialogContent className="sm:max-w-xs">
                    <DialogHeader>
                        <DialogTitle className="text-base">Delete Project</DialogTitle>
                        <DialogDescription>This will permanently delete the project and all its tasks.</DialogDescription>
                    </DialogHeader>
                    <DialogFooter className="flex gap-2 sm:gap-2">
                        <Button variant="outline" size="sm" onClick={() => setDeleteConfirm(null)}>Cancel</Button>
                        <Button variant="destructive" size="sm" onClick={() => { if (deleteConfirm) deleteProject(deleteConfirm); setDeleteConfirm(null) }}>Delete</Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    )
}
