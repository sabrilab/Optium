import * as Haptics from 'expo-haptics';
import { router } from 'expo-router';
import { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  FlatList,
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { GlassSurface } from '@/components/glass/glass-surface';
import { Icon } from '@/components/icon';
import { Radius, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { generateTasks } from '@/lib/ai';
import { useAppStore, type Project } from '@/store';

export default function ProjectsScreen() {
  const { palette } = useTheme();
  const insets = useSafeAreaInsets();

  const projects = useAppStore((s) => s.projects);
  const [composerOpen, setComposerOpen] = useState(false);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  return (
    <View style={[styles.root, { backgroundColor: palette.background }]}>
      <View style={[styles.header, { paddingTop: insets.top + Spacing.two }]}>
        <Text style={[styles.headerTitle, { color: palette.text }]}>Projets</Text>
        <Pressable onPress={() => setComposerOpen(true)} hitSlop={12}>
          <GlassSurface isInteractive glassEffectStyle="regular" style={styles.addButton}>
            <Icon name="plus" size={17} color={palette.text} />
          </GlassSurface>
        </Pressable>
      </View>

      <FlatList
        data={projects}
        keyExtractor={(project) => project.id}
        contentContainerStyle={[styles.list, projects.length === 0 && styles.listEmpty]}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Icon name="folder" size={30} color={palette.textSecondary} />
            <Text style={[styles.emptyText, { color: palette.textSecondary }]}>
              Aucun projet pour l’instant
            </Text>
            <Text style={[styles.emptyHint, { color: palette.textSecondary }]}>
              Crée-en un, puis laisse l’IA le découper en sessions.
            </Text>
          </View>
        }
        renderItem={({ item }) => (
          <ProjectCard
            project={item}
            expanded={expandedId === item.id}
            onToggle={() => setExpandedId(expandedId === item.id ? null : item.id)}
          />
        )}
      />

      <ProjectComposer visible={composerOpen} onClose={() => setComposerOpen(false)} />
    </View>
  );
}

function ProjectCard({
  project,
  expanded,
  onToggle,
}: {
  project: Project;
  expanded: boolean;
  onToggle: () => void;
}) {
  const { palette } = useTheme();
  const [generating, setGenerating] = useState(false);

  const doneCount = project.tasks.filter((task) => task.status === 'done').length;

  const generate = async () => {
    setGenerating(true);
    try {
      const tasks = await generateTasks(project.description || project.name);
      useAppStore.getState().addTasksToProject(project.id, tasks);
    } catch (cause) {
      Alert.alert('Génération impossible', (cause as Error).message);
    } finally {
      setGenerating(false);
    }
  };

  const startTask = (taskId: string) => {
    const state = useAppStore.getState();
    if (state.hapticsEnabled) Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    state.setActiveTask(taskId, project.id);
    state.resetTimer('focus');
    state.startTimer();
    router.navigate('/');
  };

  const confirmDelete = () => {
    Alert.alert('Supprimer ce projet ?', `« ${project.name} » et ses tâches seront perdus.`, [
      { text: 'Annuler', style: 'cancel' },
      {
        text: 'Supprimer',
        style: 'destructive',
        onPress: () => useAppStore.getState().deleteProject(project.id),
      },
    ]);
  };

  return (
    <GlassSurface glassEffectStyle="regular" style={styles.card}>
      <Pressable onPress={onToggle} onLongPress={confirmDelete} style={styles.cardHeader}>
        <View style={[styles.colorDot, { backgroundColor: project.color }]} />
        <View style={styles.cardTitles}>
          <Text style={[styles.cardTitle, { color: palette.text }]} numberOfLines={1}>
            {project.name}
          </Text>
          <Text style={[styles.cardMeta, { color: palette.textSecondary }]} numberOfLines={1}>
            {project.tasks.length === 0
              ? 'Aucune tâche'
              : `${doneCount}/${project.tasks.length} tâches terminées`}
          </Text>
        </View>
        <Icon
          name={expanded ? 'chevron.up' : 'chevron.down'}
          size={13}
          color={palette.textSecondary}
        />
      </Pressable>

      {expanded && (
        <View style={styles.cardBody}>
          {project.tasks.map((task) => (
            <Pressable key={task.id} onPress={() => startTask(task.id)} style={styles.taskRow}>
              <Icon
                name={task.status === 'done' ? 'checkmark.circle.fill' : 'circle'}
                size={18}
                color={task.status === 'done' ? palette.accent : palette.textSecondary}
              />
              <Text
                style={[
                  styles.taskTitle,
                  { color: palette.text },
                  task.status === 'done' && styles.taskDone,
                ]}
                numberOfLines={1}>
                {task.title}
              </Text>
              <Text style={[styles.taskCount, { color: palette.textSecondary }]}>
                {task.completedPomodoros}/{task.estimatedPomodoros}
              </Text>
            </Pressable>
          ))}

          <Pressable onPress={generate} disabled={generating} style={styles.generateRow}>
            {generating ? (
              <ActivityIndicator size="small" />
            ) : (
              <Icon name="sparkles" size={15} color={palette.accent} />
            )}
            <Text style={[styles.generateText, { color: palette.accent }]}>
              {generating ? 'Génération…' : 'Découper en tâches avec l’IA'}
            </Text>
          </Pressable>
        </View>
      )}
    </GlassSurface>
  );
}

function ProjectComposer({ visible, onClose }: { visible: boolean; onClose: () => void }) {
  const { palette } = useTheme();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');

  const submit = () => {
    if (!name.trim()) return;
    useAppStore.getState().addProject(name.trim(), description.trim());
    setName('');
    setDescription('');
    onClose();
  };

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={styles.composerBackdrop}>
        <GlassSurface glassEffectStyle="regular" style={styles.composer}>
          <Text style={[styles.composerTitle, { color: palette.text }]}>Nouveau projet</Text>

          <TextInput
            value={name}
            onChangeText={setName}
            placeholder="Nom du projet"
            placeholderTextColor={palette.textSecondary}
            autoFocus
            style={[styles.input, { color: palette.text, borderColor: palette.border }]}
          />
          <TextInput
            value={description}
            onChangeText={setDescription}
            placeholder="Objectif — sert à l’IA pour découper le travail"
            placeholderTextColor={palette.textSecondary}
            multiline
            style={[
              styles.input,
              styles.inputMultiline,
              { color: palette.text, borderColor: palette.border },
            ]}
          />

          <View style={styles.composerActions}>
            <Pressable onPress={onClose} style={[styles.button, { borderColor: palette.border }]}>
              <Text style={[styles.buttonLabel, { color: palette.text }]}>Annuler</Text>
            </Pressable>
            <Pressable
              onPress={submit}
              style={[styles.button, styles.buttonPrimary, { backgroundColor: palette.text }]}>
              <Text style={[styles.buttonLabel, { color: palette.background }]}>Créer</Text>
            </Pressable>
          </View>
        </GlassSurface>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.four,
    paddingBottom: Spacing.three,
  },
  headerTitle: { fontSize: 28, fontWeight: '700', letterSpacing: -0.5 },
  addButton: {
    width: 34,
    height: 34,
    borderRadius: Radius.pill,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },
  list: { paddingHorizontal: Spacing.four, paddingBottom: 120, gap: Spacing.three },
  listEmpty: { flexGrow: 1, justifyContent: 'center' },
  empty: { alignItems: 'center', gap: Spacing.two },
  emptyText: { fontSize: 15, fontWeight: '500' },
  emptyHint: { fontSize: 13, textAlign: 'center', paddingHorizontal: Spacing.six },
  card: { borderRadius: Radius.medium, overflow: 'hidden' },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.three,
    padding: Spacing.four,
  },
  colorDot: { width: 10, height: 10, borderRadius: 5 },
  cardTitles: { flex: 1, gap: 2 },
  cardTitle: { fontSize: 15, fontWeight: '600' },
  cardMeta: { fontSize: 12 },
  cardBody: { paddingHorizontal: Spacing.four, paddingBottom: Spacing.four, gap: Spacing.one },
  taskRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.three,
    paddingVertical: Spacing.two,
  },
  taskTitle: { flex: 1, fontSize: 14 },
  taskDone: { textDecorationLine: 'line-through', opacity: 0.5 },
  taskCount: { fontSize: 12, fontVariant: ['tabular-nums'] },
  generateRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.two,
    paddingVertical: Spacing.three,
  },
  generateText: { fontSize: 13, fontWeight: '500' },
  composerBackdrop: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(0, 0, 0, 0.45)',
    padding: Spacing.four,
  },
  composer: { padding: Spacing.five, borderRadius: Radius.large, overflow: 'hidden', gap: Spacing.three },
  composerTitle: { fontSize: 18, fontWeight: '600' },
  input: {
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: Radius.small,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.three,
    fontSize: 15,
  },
  inputMultiline: { minHeight: 76, textAlignVertical: 'top' },
  composerActions: { flexDirection: 'row', gap: Spacing.three, marginTop: Spacing.one },
  button: {
    flex: 1,
    height: 44,
    borderRadius: Radius.small,
    borderWidth: StyleSheet.hairlineWidth,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonPrimary: { borderWidth: 0 },
  buttonLabel: { fontSize: 14, fontWeight: '600' },
});
