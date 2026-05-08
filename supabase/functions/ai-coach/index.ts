import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const modelNames = [
  "gemini-3.1-flash-lite-preview",
  "gemini-flash-latest",
  "gemini-1.5-flash",
  "gemini-2.0-flash",
];

type JsonMap = Record<string, unknown>;
type GenerateTextOptions = {
  maxOutputTokens?: number;
  temperature?: number;
};

const MAX_ACTIVE_LOGS = 8;
const MAX_LOG_CHARS = 140;
const MAX_HISTORY_MESSAGES = 8;
const MAX_HISTORY_CHARS = 320;
const MAX_USER_MESSAGE_CHARS = 800;
const MAX_CONTEXT_CHARS = 500;
const MAX_TRANSCRIPT_CHARS = 1200;

const healthFactSignal =
  /\b(allerg|avoid|can't|cannot|condition|diet|goal|high metab|low metab|injur|metab|metabolism|pain|prefer|pure veg|sleep|sore|vegetarian|vegan|weight)\b/i;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    await requireAuthenticatedUser(req);

    const body = await req.json();
    const action = stringValue(body.action);

    switch (action) {
      case "generatePlan":
        return json({ result: await generatePlan(body) });
      case "analyzeVoiceLog":
        return json({ text: await analyzeVoiceLog(body) });
      case "chat":
        return json({ text: await chat(body) });
      case "extractInsights":
        return json({ insights: await extractInsights(body) });
      case "getSmartNudge":
        return json({ text: await getSmartNudge(body) });
      case "generateDailyInsight":
        return json({ text: await generateDailyInsight(body) });
      case "analyzeHealthTrends":
        return json({ text: await analyzeHealthTrends(body) });
      case "analyzeMealSwap":
        return json({ text: await analyzeMealSwap(body) });
      default:
        return json({ error: `Unsupported AI action: ${action}` }, 400);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("ai-coach error:", message);
    return json({ error: message }, message.includes("Unauthorized") ? 401 : 500);
  }
});

async function requireAuthenticatedUser(req: Request) {
  const authHeader = req.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new Error("Unauthorized: missing bearer token");
  }

  const token = authHeader.substring("Bearer ".length);
  if (!token || token === Deno.env.get("SUPABASE_ANON_KEY")) {
    throw new Error("Unauthorized: user session required");
  }

  const supabase = createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_ANON_KEY"),
    {
      global: {
        headers: { Authorization: authHeader },
      },
    },
  );

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) {
    throw new Error("Unauthorized: invalid user session");
  }
}

async function generatePlan(body: JsonMap) {
  const profile = objectValue(body.profile);
  const healthData = objectValue(body.healthData);
  const preferredLanguage = stringValue(profile.preferredLanguage, "English");
  const activeLogs = compactStringList(
    stringArrayValue(body.activeLogs),
    MAX_ACTIVE_LOGS,
    MAX_LOG_CHARS,
  );
  const additionalContext = compactText(
    optionalStringValue(body.additionalContext) ?? "",
    MAX_CONTEXT_CHARS,
  );
  const contextPart = additionalContext
    ? `\nAdditional Context from User: ${additionalContext}`
    : "";
  const memoryPart = activeLogs.length > 0
    ? `\nUSER PREFERENCES & HEALTH CONTEXT:\n${activeLogs.map((log) => `- ${log}`).join("\n")}`
    : "";

  const prompt = `
Act as an elite health coach.
Respond in: ${preferredLanguage}.
${memoryPart}
User Profile: Age ${numberValue(profile.age, 30)}, Weight ${numberValue(profile.weight, 70)}kg, Goal: ${stringValue(profile.fitnessGoal, "General Health")}.
Recent Data: Steps ${numberValue(healthData.steps, 0)}, Sleep minutes ${numberValue(healthData.sleepMinutes, 0)}, HRV ${optionalNumberValue(healthData.hrv) ?? "unknown"}.
${contextPart}

Generate a daily plan with 5 to 7 schedule items in JSON format.
Mix these categories as needed: workout, meal, hydration, mobility, recovery, sleep, focus, and optional extra tasks.
If the context mentions a user-defined task or a meal replacement, reflect it as an adjusted schedule item.
Do NOT use markdown code blocks. Just return the raw JSON object.
JSON structure:
{
  "summary": "Short summary of the day's focus",
  "advice": "Motivational advice based on data",
  "schedule": [
    {"type": "workout", "description": "Title", "details": "duration/intensity"},
    {"type": "meal", "description": "Title", "details": "brief details"},
    {"type": "hydration", "description": "Title", "details": "brief details"},
    {"type": "sleep", "description": "Title", "details": "brief details"}
  ]
}
`;

  const text = await generateText(prompt, {
    maxOutputTokens: 450,
    temperature: 0.5,
  });
  const parsed = parseJsonObject(text);

  return {
    date: new Date().toISOString().slice(0, 10),
    summary: stringValue(parsed.summary, "Daily Health Plan"),
    advice: stringValue(parsed.advice, "Keep pushing forward!"),
    schedule: Array.isArray(parsed.schedule) ? parsed.schedule : [],
  };
}

async function analyzeVoiceLog(body: JsonMap) {
  const transcript = compactText(stringValue(body.transcript), MAX_TRANSCRIPT_CHARS);
  return generateText(`
As a health coach, review this voice log:
"${transcript}"

Extract key health updates (soreness, energy, mood, diet) and give a very short confirmation.
Example: "Got it! I've noted your knee soreness and adjusted your plan for less impact today."
Return ONLY the response text.
`, { maxOutputTokens: 80, temperature: 0.4 });
}

async function chat(body: JsonMap) {
  const message = compactText(stringValue(body.message), MAX_USER_MESSAGE_CHARS);
  const preferredLanguage = stringValue(objectValue(body.profile).preferredLanguage, "English");
  const activeLogs = compactStringList(
    stringArrayValue(body.activeLogs),
    MAX_ACTIVE_LOGS,
    MAX_LOG_CHARS,
  );
  const historyPart = compactHistory(body.history, message);

  const systemPrompt = `
Act as an elite health coach guiding the user toward their health and fitness goals.
Respond in: ${preferredLanguage}.

Verified user facts to respect:
${activeLogs.length > 0 ? activeLogs.map((log) => `- ${log}`).join("\n") : "- No specific memory logs synced yet."}

Be concise, direct, and conversational.
Limit responses to 2-3 short sentences maximum.
Avoid lectures or long explanations unless explicitly asked.
`;

  return generateText(`
${systemPrompt}

Conversation history:
${historyPart || "No prior messages."}

User Message: ${message}
`, { maxOutputTokens: 140, temperature: 0.7 });
}

async function extractInsights(body: JsonMap) {
  const userMessage = compactText(
    stringValue(body.userMessage),
    MAX_USER_MESSAGE_CHARS,
  );
  if (!healthFactSignal.test(userMessage)) return [];

  const aiResponse = compactText(stringValue(body.aiResponse), 240);
  const text = await generateText(`
Extract NEW durable health facts/preferences from the User Message.

User Message: "${userMessage}"
AI Response context: "${aiResponse}"

Prefix each fact with [AUTO] if it is a high-confidence personal declaration (e.g., "I am pure veg", "I have a knee injury", "My goal is...").
Use [SUGGEST] for general observations or lower confidence facts.

RULES:
1. IGNORE temporary states (e.g., "I'm tired today").
2. FOCUS on diet, injuries, chronic conditions, metabolic traits, and hard preferences.
3. Format: "[TAG] User [fact]" (e.g., "[AUTO] User is pure veg").
4. If nothing new is found, return exactly EMPTY with no markdown, heading, bullet, or extra text.
Examples that should count: "I have high metabolism", "I have low metabolism", "I can't eat apples", "I am lactose intolerant".
`, { maxOutputTokens: 120, temperature: 0.2 });

  if (isEmptyInsightSentinel(text)) return [];

  return text
    .split("\n")
    .map((line) => line.trim().replace(/^-+\s*/, ""))
    .filter((line) => line.length > 5 && !isEmptyInsightSentinel(line));
}

async function getSmartNudge(body: JsonMap) {
  const profile = objectValue(body.profile);
  const healthData = objectValue(body.healthData);

  return generateText(`
Act as an elite health coach.
User Goal: ${stringValue(profile.fitnessGoal, "General Health")}.
Today's Steps: ${numberValue(healthData.steps, 0)}, Sleep: ${numberValue(healthData.sleepMinutes, 0)} min.

Task: Provide a very SHORT (3-8 words), DIRECT health command.
- Use a "command" tone (e.g., "Walk 15 minutes now." or "Drink 500ml water immediately.")
- MUST be specific: include a number, duration, or distance.
- NO explanations, NO fluff. Just the directive.
Return ONLY the text of the nudge.
`, { maxOutputTokens: 30, temperature: 0.6 });
}

async function generateDailyInsight(body: JsonMap) {
  const profile = objectValue(body.profile);
  const healthData = objectValue(body.healthData);
  const preferredLanguage = stringValue(profile.preferredLanguage, "English");
  const currentTime = stringValue(body.currentTime, "current time");
  const dailyStepGoal = numberValue(profile.dailyStepGoal, 10000);
  const steps = numberValue(healthData.steps, 0);
  const progress = Math.round((steps / (dailyStepGoal > 0 ? dailyStepGoal : 10000)) * 100);
  const fallback = steps >= dailyStepGoal
    ? "You hit today's step goal, so protect that momentum with strong recovery tonight."
    : `You are ${Math.max(0, dailyStepGoal - steps)} steps from your goal, so take one focused walk today.`;

  const insight = await generateText(`
Act as an elite health coach.
Respond in: ${preferredLanguage}.
Current Time: ${currentTime}
User Profile: Goal ${stringValue(profile.fitnessGoal, "General Health")}.
Today's Data: ${steps} steps (${progress}% of goal), ${numberValue(healthData.sleepMinutes, 0)}m sleep, ${optionalNumberValue(healthData.hrv) ?? "unknown"}ms HRV.

Task: Provide a single, powerful motivational "nudge" sentence (maximum 15 words).
- Make it a 1-liner that connects their current data to their goal.
- Be highly inspiring.
- Return ONLY the exact sentence text.
`, { maxOutputTokens: 45, temperature: 0.7 });

  return isUsableInsight(insight) ? insight : fallback;
}

async function analyzeHealthTrends(body: JsonMap) {
  const profile = objectValue(body.profile);
  const preferredLanguage = stringValue(profile.preferredLanguage, "English");
  const weeklySteps = numberArrayValue(body.weeklySteps);
  const avgSteps = weeklySteps.length > 0
    ? Math.round(weeklySteps.reduce((sum, steps) => sum + steps, 0) / weeklySteps.length)
    : 0;

  return generateText(`
Act as an elite health coach.
Respond in: ${preferredLanguage}.
User Profile: Age ${numberValue(profile.age, 30)}, Weight ${numberValue(profile.weight, 70)}kg, Daily Goal: ${numberValue(profile.dailyStepGoal, 10000)} steps.
Weekly Step Data (last 7 days): ${JSON.stringify(weeklySteps)}.
Average Steps this week: ${avgSteps}.

Task: Provide a 2-3 sentence personalized efficiency analysis of this trend.
- Be highly motivating and focused on consistent progress.
- If they are hitting their goal, challenge them to maintain that peak performance.
- If they are lagging, provide a "power-habit" to help them get back on track.
- Reference their specific average steps (${avgSteps}) to build awareness.
- Return ONLY the insight text. No intro, no markdown.
`, { maxOutputTokens: 120, temperature: 0.6 });
}

async function analyzeMealSwap(body: JsonMap) {
  const profile = objectValue(body.profile);
  const healthData = objectValue(body.healthData);
  const preferredLanguage = stringValue(profile.preferredLanguage, "English");
  const originalItem = compactText(stringValue(body.originalItem), 260);
  const replacementText = compactText(stringValue(body.replacementText), 260);

  return generateText(`
Act as an elite health coach.
Respond in: ${preferredLanguage}.
User Profile: Goal ${stringValue(profile.fitnessGoal, "General Health")}, dietary preference ${stringValue(profile.dietaryPreference, "None")}.
Today's Data: ${numberValue(healthData.steps, 0)} steps, ${numberValue(healthData.sleepMinutes, 0)}m sleep, ${optionalNumberValue(healthData.hrv) ?? "unknown"}ms HRV.

The user planned: "${originalItem}"
The user actually ate/did: "${replacementText}"

Task:
1. Briefly estimate the impact in 1 short sentence.
2. Suggest the next best meal for the rest of the day in 1 short sentence.
3. Keep it practical, not dramatic.
Return ONLY the text.
`, { maxOutputTokens: 120, temperature: 0.5 });
}

async function generateText(prompt: string, options: GenerateTextOptions = {}) {
  const apiKey = requiredEnv("GEMINI_API_KEY");
  let lastError = "";

  for (const model of modelNames) {
    const endpoint =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          maxOutputTokens: options.maxOutputTokens ?? 200,
          temperature: options.temperature ?? 0.6,
        },
      }),
    });

    const data = await response.json().catch(() => ({}));
    if (response.ok) {
      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (typeof text === "string" && text.trim()) return text.trim();
      lastError = "Gemini returned an empty response.";
      continue;
    }

    lastError = data?.error?.message ?? `Gemini request failed with ${response.status}`;
    if (![404, 429, 500, 502, 503, 504].includes(response.status)) break;
  }

  throw new Error(lastError || "Gemini request failed.");
}

function parseJsonObject(text: string) {
  const cleaned = text
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```$/i, "")
    .trim();

  try {
    const parsed = JSON.parse(cleaned);
    return objectValue(parsed);
  } catch (_) {
    const match = cleaned.match(/\{[\s\S]*\}/);
    if (!match) return {};
    return objectValue(JSON.parse(match[0]));
  }
}

function json(body: JsonMap, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function requiredEnv(key: string) {
  const value = Deno.env.get(key);
  if (!value) throw new Error(`Missing required secret: ${key}`);
  return value;
}

function objectValue(value: unknown): JsonMap {
  if (typeof value === "object" && value !== null && !Array.isArray(value)) {
    return value as JsonMap;
  }
  return {};
}

function stringValue(value: unknown, fallback = "") {
  return typeof value === "string" ? value : fallback;
}

function optionalStringValue(value: unknown) {
  return typeof value === "string" && value.trim() ? value : null;
}

function numberValue(value: unknown, fallback: number) {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function optionalNumberValue(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function stringArrayValue(value: unknown) {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

function numberArrayValue(value: unknown) {
  return Array.isArray(value)
    ? value.filter((item): item is number =>
      typeof item === "number" && Number.isFinite(item)
    )
    : [];
}

function compactHistory(value: unknown, currentMessage: string) {
  if (!Array.isArray(value)) return "";

  const currentNormalized = normalizeForCompare(currentMessage);
  return value
    .filter((item) => typeof item === "object" && item !== null)
    .map((item) => {
      const entry = item as JsonMap;
      return {
        role: stringValue(entry.role, "user") === "assistant"
          ? "assistant"
          : "user",
        content: compactText(stringValue(entry.content), MAX_HISTORY_CHARS),
      };
    })
    .filter((entry) =>
      entry.content && normalizeForCompare(entry.content) !== currentNormalized
    )
    .slice(-MAX_HISTORY_MESSAGES)
    .map((entry) => `${entry.role}: ${entry.content}`)
    .join("\n");
}

function compactStringList(
  values: string[],
  maxItems: number,
  maxChars: number,
) {
  return values
    .map((value) => compactText(value, maxChars))
    .filter((value) => value.length > 0)
    .slice(0, maxItems);
}

function compactText(value: string, maxChars: number) {
  const compacted = value.replace(/\s+/g, " ").trim();
  if (compacted.length <= maxChars) return compacted;
  return `${compacted.slice(0, Math.max(0, maxChars - 3)).trimEnd()}...`;
}

function isUsableInsight(value: string) {
  const trimmed = value.trim();
  if (trimmed.length < 12) return false;
  return trimmed.split(/\s+/).length >= 4;
}

function isEmptyInsightSentinel(value: string) {
  const normalized = value
    .replace(/^[#>\-*\s]+/, "")
    .replace(/\s+/g, " ")
    .trim()
    .toUpperCase();
  return !normalized || normalized === "EMPTY" || normalized === "RETURN EMPTY";
}

function normalizeForCompare(value: string) {
  return value.replace(/\s+/g, " ").trim().toLowerCase();
}
