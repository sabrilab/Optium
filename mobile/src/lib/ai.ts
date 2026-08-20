import { supabase } from '@/lib/supabase';

const SYSTEM_PROMPT = `Tu es un expert en productivité utilisant la méthode Pomodoro. L'utilisateur va te donner un objectif ou un projet brut. Ta mission est de décomposer ce projet en sous-tâches concrètes, actionnables et séquentielles.
Pour chaque sous-tâche, estime le nombre de 'Pomodoros' (sessions de 25 minutes) nécessaires.
Tu DOIS répondre UNIQUEMENT avec un objet JSON valide suivant ce schéma exact, sans aucun autre texte :
{
  "tasks": [
    { "title": "Titre court de l'action", "estimated_pomodoros": 2 },
    { "title": "Titre de l'action suivante", "estimated_pomodoros": 1 }
  ]
}
Règle stricte : Ne génère pas plus de 5 sous-tâches maximum pour éviter la surcharge mentale de l'utilisateur.`;

export interface GeneratedTask {
  title: string;
  estimated_pomodoros: number;
}

export class AiNotConfiguredError extends Error {
  constructor() {
    super(
      "La génération de tâches nécessite la fonction Supabase « generate-tasks ». " +
        'Renseigne les clés Supabase puis déploie-la.'
    );
    this.name = 'AiNotConfiguredError';
  }
}

/**
 * Decoupe un projet en sous-taches.
 *
 * Contrairement a la version web, la cle OpenRouter n'est jamais embarquee dans
 * l'application : l'appel passe par la fonction edge Supabase, qui detient la
 * cle cote serveur et verifie que l'utilisateur est authentifie. Une cle
 * placee dans le binaire mobile serait extractible par n'importe qui.
 */
export async function generateTasks(projectDescription: string): Promise<GeneratedTask[]> {
  if (!supabase) throw new AiNotConfiguredError();

  const { data: { session } } = await supabase.auth.getSession();
  if (!session) throw new AiNotConfiguredError();

  const { data, error } = await supabase.functions.invoke('generate-tasks', {
    body: { prompt: projectDescription, system: SYSTEM_PROMPT },
  });

  if (error) throw new Error(`Génération impossible : ${error.message}`);
  if (!data?.tasks || !Array.isArray(data.tasks)) {
    throw new Error('Réponse inattendue du modèle.');
  }

  return data.tasks.slice(0, 5).map((task: GeneratedTask) => ({
    title: String(task.title),
    estimated_pomodoros: Math.max(1, Math.round(Number(task.estimated_pomodoros) || 1)),
  }));
}
