const OPENROUTER_API_KEY = import.meta.env.VITE_OPENROUTER_API_KEY
const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions'
const MODEL = 'google/gemini-2.5-flash-preview'

const SYSTEM_PROMPT = `Tu es un expert en productivité utilisant la méthode Pomodoro. L'utilisateur va te donner un objectif ou un projet brut. Ta mission est de décomposer ce projet en sous-tâches concrètes, actionnables et séquentielles.
Pour chaque sous-tâche, estime le nombre de 'Pomodoros' (sessions de 25 minutes) nécessaires.
Tu DOIS répondre UNIQUEMENT avec un objet JSON valide suivant ce schéma exact, sans aucun autre texte :
{
  "tasks": [
    { "title": "Titre court de l'action", "estimated_pomodoros": 2 },
    { "title": "Titre de l'action suivante", "estimated_pomodoros": 1 }
  ]
}
Règle stricte : Ne génère pas plus de 5 sous-tâches maximum pour éviter la surcharge mentale de l'utilisateur.`

export interface GeneratedTask {
    title: string
    estimated_pomodoros: number
}

interface OpenRouterResponse {
    choices: { message: { content: string } }[]
}

export async function generateTasks(projectDescription: string): Promise<GeneratedTask[]> {
    if (!OPENROUTER_API_KEY) {
        throw new Error('OpenRouter API key not configured')
    }

    const response = await fetch(OPENROUTER_URL, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
            'Content-Type': 'application/json',
            'X-Title': 'Optium',
        },
        body: JSON.stringify({
            model: MODEL,
            messages: [
                { role: 'system', content: SYSTEM_PROMPT },
                { role: 'user', content: projectDescription },
            ],
            response_format: { type: 'json_object' },
            temperature: 0.7,
            max_tokens: 1024,
        }),
    })

    if (!response.ok) {
        const errorText = await response.text()
        throw new Error(`API error: ${response.status} — ${errorText}`)
    }

    const data: OpenRouterResponse = await response.json()
    const content = data.choices?.[0]?.message?.content

    if (!content) {
        throw new Error('No content in API response')
    }

    const parsed = JSON.parse(content)

    if (!parsed.tasks || !Array.isArray(parsed.tasks)) {
        throw new Error('Invalid response format')
    }

    return parsed.tasks.slice(0, 5).map((t: GeneratedTask) => ({
        title: t.title,
        estimated_pomodoros: Math.max(1, Math.round(t.estimated_pomodoros)),
    }))
}
