import * as Haptics from 'expo-haptics';
import { router, Stack } from 'expo-router';
import { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

import { Icon } from '@/components/icon';
import { ListRow, ListSection } from '@/components/list';
import { Layout, Radius, Spacing, Typography } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { generateTasks } from '@/lib/ai';
import { useAppStore, type Project } from '@/store';

export default function ProjectsScreen() {
  const { palette } = useTheme();
  const projects = useAppStore((s) => s.projects);
  const [composerOpen, setComposerOpen] = useState(false);

  return (
    <View style={[styles.root, { backgroundColor: palette.groupedBackground }]}>
      <Stack.Screen
        options={{
          headerRight: () => (
            <Pressable
              onPress={() => setComposerOpen(true)}
              hitSlop={12}
              accessibilityRole="button"
              accessibilityLabel="Nouveau projet">
              <Icon name="plus" size={20} color={palette.tint} />
            </Pressable>
          ),
        }}
      />

      <ScrollView
        // Laisse iOS gerer les marges sous le grand titre et au-dessus de la
        // barre d'onglets, plutot que de les coder en dur.
        contentInsetAdjustmentBehavior="automatic"
        contentContainerStyle={styles.content}>
        {projects.length === 0 ? (
          <View style={styles.empty}>
            <Icon name="folder" size={44} color={palette.tertiaryLabel} />
            <Text style={[styles.emptyTitle, { color: palette.label }]}>Aucun projet</Text>
            <Text style={[styles.emptyBody, { color: palette.secondaryLabel }]}>
              Créez un projet, puis laissez l’IA le découper en sessions de travail.
            </Text>
          </View>
        ) : (
          projects.map((project) => <ProjectSection key={project.id} project={project} />)
        )}
      </ScrollView>

      <ProjectComposer visible={composerOpen} onClose={() => setComposerOpen(false)} />
    </View>
  );
}

function ProjectSection({ project }: { project: Project }) {
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
    <ListSection
      header={project.name}
      footer={
        project.tasks.length === 0
          ? undefined
          : `${doneCount} sur ${project.tasks.length} tâches terminées`
      }>
      {project.tasks.map((task) => (
        <ListRow
          key={task.id}
          title={task.title}
          onPress={() => startTask(task.id)}
          leading={
            <Icon
              name={task.status === 'done' ? 'checkmark.circle.fill' : 'circle'}
              size={20}
              color={task.status === 'done' ? palette.tint : palette.tertiaryLabel}
            />
          }
          accessory={
            <Text style={[styles.count, { color: palette.secondaryLabel }]}>
              {task.completedPomodoros}/{task.estimatedPomodoros}
            </Text>
          }
        />
      ))}

      <ListRow
        title={generating ? 'Génération…' : 'Découper en tâches avec l’IA'}
        onPress={generating ? undefined : generate}
        leading={
          generating ? (
            <ActivityIndicator size="small" />
          ) : (
            <Icon name="sparkles" size={20} color={palette.tint} />
          )
        }
      />

      <ListRow title="Supprimer le projet" destructive onPress={confirmDelete} />
    </ListSection>
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
    <Modal
      visible={visible}
      // Feuille modale : la presentation attendue d'iOS pour une saisie courte.
      presentationStyle="pageSheet"
      animationType="slide"
      onRequestClose={onClose}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={[styles.sheet, { backgroundColor: palette.groupedBackground }]}>
        <View style={[styles.sheetBar, { borderColor: palette.separator }]}>
          <Pressable onPress={onClose} hitSlop={12} accessibilityRole="button">
            <Text style={[styles.sheetAction, { color: palette.tint }]}>Annuler</Text>
          </Pressable>
          <Text style={[styles.sheetTitle, { color: palette.label }]}>Nouveau projet</Text>
          <Pressable
            onPress={submit}
            hitSlop={12}
            disabled={!name.trim()}
            accessibilityRole="button">
            <Text
              style={[
                styles.sheetAction,
                styles.sheetActionStrong,
                { color: name.trim() ? palette.tint : palette.tertiaryLabel },
              ]}>
              Créer
            </Text>
          </Pressable>
        </View>

        <ScrollView contentContainerStyle={styles.sheetContent}>
          <ListSection footer="L’objectif sert à l’IA pour découper le travail en sessions.">
            <View style={styles.field}>
              <TextInput
                value={name}
                onChangeText={setName}
                placeholder="Nom du projet"
                placeholderTextColor={palette.tertiaryLabel}
                autoFocus
                style={[styles.input, { color: palette.label }]}
              />
            </View>
            <View style={styles.field}>
              <TextInput
                value={description}
                onChangeText={setDescription}
                placeholder="Objectif"
                placeholderTextColor={palette.tertiaryLabel}
                multiline
                style={[styles.input, styles.inputMultiline, { color: palette.label }]}
              />
            </View>
          </ListSection>
        </ScrollView>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  content: { paddingBottom: 120, gap: Spacing.six, paddingTop: Spacing.two },
  empty: { alignItems: 'center', gap: Spacing.two, paddingTop: 100, paddingHorizontal: Spacing.six },
  emptyTitle: Typography.title2,
  emptyBody: { ...Typography.subheadline, textAlign: 'center' },
  count: { ...Typography.subheadline, fontVariant: ['tabular-nums'] },
  sheet: { flex: 1 },
  sheetBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Layout.margin,
    height: 56,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  sheetTitle: Typography.headline,
  sheetAction: Typography.body,
  sheetActionStrong: { fontWeight: '600' },
  sheetContent: { paddingTop: Spacing.five },
  field: { paddingHorizontal: Layout.margin, justifyContent: 'center', minHeight: Layout.minTouchTarget },
  input: { ...Typography.body, paddingVertical: Spacing.three },
  inputMultiline: { minHeight: 88, textAlignVertical: 'top' },
});
