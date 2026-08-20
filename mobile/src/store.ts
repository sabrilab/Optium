import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

// ─── Types ─────────────────────────────────────────────
export type TimerMode = 'focus' | 'break';
export type TaskStatus = 'todo' | 'in_progress' | 'done';
export type ProjectStatus = 'active' | 'completed';

export interface Task {
  id: string;
  projectId: string;
  title: string;
  estimatedPomodoros: number;
  completedPomodoros: number;
  status: TaskStatus;
  order: number;
}

export interface AiMessage {
  role: 'user' | 'ai';
  content: string;
  timestamp: number;
}

export interface Project {
  id: string;
  name: string;
  description: string;
  status: ProjectStatus;
  tasks: Task[];
  createdAt: number;
  color: string;
  aiHistory: AiMessage[];
}

export interface Session {
  id: string;
  taskId: string | null;
  projectId: string | null;
  durationSeconds: number;
  type: 'focus' | 'break';
  createdAt: number;
  location?: { lat: number; lng: number };
}

export const PROJECT_COLORS = [
  '#5B9BD5', '#70AD47', '#FFC000', '#ED7D31',
  '#A855F7', '#EC4899', '#14B8A6', '#F97316',
];

const generateId = () =>
  Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);

const MAX_SESSIONS = 1000;

interface UISlice {
  showCompletionModal: boolean;
  setShowCompletionModal: (show: boolean) => void;
}

interface TimerSlice {
  timerMode: TimerMode;
  timerSeconds: number;
  totalSeconds: number;
  isRunning: boolean;
  activeTaskId: string | null;
  activeProjectId: string | null;
  timerStartedAt: number | null;
  sessionCount: number;

  focusDuration: number;
  breakDuration: number;
  longBreakDuration: number;
  longBreakInterval: number;

  startTimer: () => void;
  pauseTimer: () => void;
  resetTimer: (mode?: TimerMode) => void;
  tick: () => void;
  addTime: (seconds: number) => void;
  setActiveTask: (taskId: string | null, projectId: string | null) => void;
  switchToBreak: () => void;
  switchToFocus: () => void;
  setFocusDuration: (min: number) => void;
  setBreakDuration: (min: number) => void;
  setLongBreakDuration: (min: number) => void;
}

interface ProjectsSlice {
  projects: Project[];
  selectedProjectId: string | null;
  setSelectedProjectId: (id: string | null) => void;
  addProject: (name: string, description: string) => string;
  deleteProject: (id: string) => void;
  addTasksToProject: (
    projectId: string,
    tasks: { title: string; estimated_pomodoros: number }[]
  ) => void;
  deleteTask: (projectId: string, taskId: string) => void;
  updateTaskStatus: (projectId: string, taskId: string, status: TaskStatus) => void;
  incrementTaskPomodoro: (projectId: string, taskId: string) => void;
  toggleProjectStatus: (projectId: string) => void;
  addAiMessage: (projectId: string, message: AiMessage) => void;
}

interface SessionsSlice {
  sessions: Session[];
  addSession: (session: Omit<Session, 'id' | 'createdAt'>) => void;
  getTodaySessions: () => Session[];
  getProjectTimeSpent: (projectId: string) => number;
}

interface SettingsSlice {
  soundEnabled: boolean;
  toggleSound: () => void;
  hapticsEnabled: boolean;
  toggleHaptics: () => void;
  geoEnabled: boolean;
  toggleGeo: () => void;
  /** Coupe la 3D : economise la batterie et debloque les appareils lents. */
  brainEnabled: boolean;
  toggleBrain: () => void;
  userName: string;
  setUserName: (name: string) => void;
}

type AppState = UISlice & TimerSlice & ProjectsSlice & SessionsSlice & SettingsSlice;

export const useAppStore = create<AppState>()(
  persist(
    (set, get) => ({
      // ── UI ──
      showCompletionModal: false,
      setShowCompletionModal: (show) => set({ showCompletionModal: show }),

      // ── Timer ──
      timerMode: 'focus',
      timerSeconds: 25 * 60,
      totalSeconds: 25 * 60,
      isRunning: false,
      activeTaskId: null,
      activeProjectId: null,
      timerStartedAt: null,
      sessionCount: 0,

      focusDuration: 25,
      breakDuration: 5,
      longBreakDuration: 15,
      longBreakInterval: 4,

      startTimer: () => {
        // On memorise l'instant de depart plutot qu'un compteur : l'app peut etre
        // suspendue par iOS, seul l'horodatage survit a la mise en arriere-plan.
        const { totalSeconds, timerSeconds } = get();
        set({ isRunning: true, timerStartedAt: Date.now() - (totalSeconds - timerSeconds) * 1000 });
      },
      pauseTimer: () => set({ isRunning: false, timerStartedAt: null }),
      resetTimer: (mode) => {
        const timerMode = mode || get().timerMode;
        const dur = timerMode === 'focus' ? get().focusDuration : get().breakDuration;
        const totalSeconds = dur * 60;
        set({ timerMode, timerSeconds: totalSeconds, totalSeconds, isRunning: false, timerStartedAt: null });
      },
      tick: () => {
        const { timerSeconds, timerStartedAt, totalSeconds } = get();
        if (timerSeconds <= 0) return;

        if (timerStartedAt) {
          const elapsed = Math.floor((Date.now() - timerStartedAt) / 1000);
          const newSeconds = Math.max(0, totalSeconds - elapsed);
          if (newSeconds !== timerSeconds) set({ timerSeconds: newSeconds });
        } else {
          set({ timerSeconds: timerSeconds - 1 });
        }
      },
      addTime: (seconds) => {
        const { timerSeconds, totalSeconds } = get();
        const nextTotal = totalSeconds + seconds;
        const nextRemaining = timerSeconds + seconds;
        set({
          timerSeconds: nextRemaining,
          totalSeconds: nextTotal,
          timerStartedAt: Date.now() - (nextTotal - nextRemaining) * 1000,
        });
      },
      setActiveTask: (taskId, projectId) => {
        set({ activeTaskId: taskId, activeProjectId: projectId });
        if (taskId && projectId) get().updateTaskStatus(projectId, taskId, 'in_progress');
      },
      switchToBreak: () => {
        const { sessionCount, longBreakInterval, breakDuration, longBreakDuration } = get();
        const newCount = sessionCount + 1;
        const isLongBreak = newCount % longBreakInterval === 0;
        const dur = isLongBreak ? longBreakDuration : breakDuration;
        set({
          timerMode: 'break',
          timerSeconds: dur * 60,
          totalSeconds: dur * 60,
          isRunning: true,
          timerStartedAt: Date.now(),
          sessionCount: newCount,
        });
      },
      switchToFocus: () => {
        const dur = get().focusDuration;
        set({
          timerMode: 'focus',
          timerSeconds: dur * 60,
          totalSeconds: dur * 60,
          isRunning: false,
          timerStartedAt: null,
        });
      },
      setFocusDuration: (min) => {
        set({ focusDuration: min });
        if (!get().isRunning && get().timerMode === 'focus') {
          set({ timerSeconds: min * 60, totalSeconds: min * 60 });
        }
      },
      setBreakDuration: (min) => {
        set({ breakDuration: min });
        if (!get().isRunning && get().timerMode === 'break') {
          set({ timerSeconds: min * 60, totalSeconds: min * 60 });
        }
      },
      setLongBreakDuration: (min) => set({ longBreakDuration: min }),

      // ── Projets ──
      projects: [],
      selectedProjectId: null,
      setSelectedProjectId: (id) => set({ selectedProjectId: id }),
      addProject: (name, description) => {
        const id = generateId();
        const color = PROJECT_COLORS[get().projects.length % PROJECT_COLORS.length];
        const newProject: Project = {
          id, name, description, status: 'active',
          createdAt: Date.now(), tasks: [], color, aiHistory: [],
        };
        set({ projects: [newProject, ...get().projects], selectedProjectId: id });
        return id;
      },
      deleteProject: (id) => {
        const { projects, selectedProjectId, activeProjectId, activeTaskId } = get();
        set({
          projects: projects.filter((p) => p.id !== id),
          selectedProjectId: selectedProjectId === id ? null : selectedProjectId,
          activeProjectId: activeProjectId === id ? null : activeProjectId,
          activeTaskId: activeProjectId === id ? null : activeTaskId,
        });
      },
      addTasksToProject: (projectId, tasks) => {
        set({
          projects: get().projects.map((p) =>
            p.id === projectId
              ? {
                  ...p,
                  tasks: [
                    ...p.tasks,
                    ...tasks.map((t, i) => ({
                      id: generateId(),
                      projectId,
                      title: t.title,
                      estimatedPomodoros: t.estimated_pomodoros,
                      completedPomodoros: 0,
                      status: 'todo' as TaskStatus,
                      order: p.tasks.length + i,
                    })),
                  ],
                }
              : p
          ),
        });
      },
      deleteTask: (projectId, taskId) => {
        const { activeTaskId } = get();
        set({
          projects: get().projects.map((p) =>
            p.id === projectId ? { ...p, tasks: p.tasks.filter((t) => t.id !== taskId) } : p
          ),
          activeTaskId: activeTaskId === taskId ? null : activeTaskId,
        });
      },
      updateTaskStatus: (projectId, taskId, status) => {
        set({
          projects: get().projects.map((p) =>
            p.id === projectId
              ? { ...p, tasks: p.tasks.map((t) => (t.id === taskId ? { ...t, status } : t)) }
              : p
          ),
        });
      },
      incrementTaskPomodoro: (projectId, taskId) => {
        set({
          projects: get().projects.map((p) =>
            p.id === projectId
              ? {
                  ...p,
                  tasks: p.tasks.map((t) => {
                    if (t.id !== taskId) return t;
                    const completedPomodoros = t.completedPomodoros + 1;
                    return {
                      ...t,
                      completedPomodoros,
                      status: completedPomodoros >= t.estimatedPomodoros ? 'done' : t.status,
                    };
                  }),
                }
              : p
          ),
        });
      },
      toggleProjectStatus: (projectId) => {
        set({
          projects: get().projects.map((p) =>
            p.id === projectId
              ? { ...p, status: p.status === 'active' ? 'completed' : 'active' }
              : p
          ),
        });
      },
      addAiMessage: (projectId, message) => {
        set({
          projects: get().projects.map((p) =>
            p.id === projectId ? { ...p, aiHistory: [...p.aiHistory, message] } : p
          ),
        });
      },

      // ── Sessions ──
      sessions: [],
      addSession: (session) => {
        const sessions = [...get().sessions, { ...session, id: generateId(), createdAt: Date.now() }];
        set({ sessions: sessions.slice(-MAX_SESSIONS) });
      },
      getTodaySessions: () => {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        return get().sessions.filter((s) => s.createdAt >= today.getTime());
      },
      getProjectTimeSpent: (projectId) => {
        const project = get().projects.find((p) => p.id === projectId);
        if (!project) return 0;
        const taskIds = new Set(project.tasks.map((t) => t.id));
        return get()
          .sessions.filter(
            (s) => s.type === 'focus' && (s.projectId === projectId || (s.taskId && taskIds.has(s.taskId)))
          )
          .reduce((sum, s) => sum + s.durationSeconds, 0);
      },

      // ── Reglages ──
      soundEnabled: true,
      toggleSound: () => set({ soundEnabled: !get().soundEnabled }),
      hapticsEnabled: true,
      toggleHaptics: () => set({ hapticsEnabled: !get().hapticsEnabled }),
      geoEnabled: false,
      toggleGeo: () => set({ geoEnabled: !get().geoEnabled }),
      brainEnabled: true,
      toggleBrain: () => set({ brainEnabled: !get().brainEnabled }),
      userName: 'User',
      setUserName: (name) => set({ userName: name }),
    }),
    {
      name: 'optium-storage',
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (state) => ({
        projects: state.projects,
        sessions: state.sessions,
        soundEnabled: state.soundEnabled,
        hapticsEnabled: state.hapticsEnabled,
        geoEnabled: state.geoEnabled,
        brainEnabled: state.brainEnabled,
        selectedProjectId: state.selectedProjectId,
        userName: state.userName,
        focusDuration: state.focusDuration,
        breakDuration: state.breakDuration,
        longBreakDuration: state.longBreakDuration,
        longBreakInterval: state.longBreakInterval,
        sessionCount: state.sessionCount,
      }),
    }
  )
);
