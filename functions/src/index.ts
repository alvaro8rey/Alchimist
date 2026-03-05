import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

admin.initializeApp();

// The API key is stored securely in Firebase Functions config, never in the client app.
// Set it once with: firebase functions:secrets:set OPENAI_API_KEY
const openaiApiKey = process.env.OPENAI_API_KEY ?? functions.config().openai?.key ?? "";

const openai = new OpenAI({ apiKey: openaiApiKey });

// Rate limit constants
const MAX_CALLS_PER_MINUTE = 10;
const callTimestamps: Record<string, number[]> = {};

function isRateLimited(userId: string): boolean {
  const now = Date.now();
  const windowStart = now - 60_000;
  if (!callTimestamps[userId]) callTimestamps[userId] = [];
  callTimestamps[userId] = callTimestamps[userId].filter((t) => t > windowStart);
  if (callTimestamps[userId].length >= MAX_CALLS_PER_MINUTE) return true;
  callTimestamps[userId].push(now);
  return false;
}

/**
 * generateRecipe — callable function used by the iOS app instead of calling OpenAI directly.
 *
 * Request payload: { ingredient1: string, ingredient2: string, userId: string }
 * Response:        { name: string, emoji: string, colorHex: string }
 */
export const generateRecipe = functions
  .runWith({ secrets: ["OPENAI_API_KEY"] })
  .https.onCall(async (data, context) => {
    // Optional: require authenticated users only
    // if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Login required");

    const { ingredient1, ingredient2, userId, username } = data as {
      ingredient1: string;
      ingredient2: string;
      userId: string;
      username: string;
    };

    if (!ingredient1 || !ingredient2) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "ingredient1 and ingredient2 are required"
      );
    }

    const callerId = context.auth?.uid ?? userId ?? "anonymous";
    if (isRateLimited(callerId)) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Too many requests. Please wait a moment."
      );
    }

    const prompt = `Eres un motor de juego de alquimia. El jugador combina dos elementos y obtienes un nuevo elemento.

Elementos:
- ${ingredient1}
- ${ingredient2}

Responde ÚNICAMENTE con un JSON válido con este formato exacto (sin markdown, sin explicaciones):
{"name":"NombreDelElemento","emoji":"🔮","colorHex":"#RRGGBB"}

Reglas:
- El nombre debe ser en español, conciso (1-3 palabras máximo), creativo y relacionado con la combinación.
- El emoji debe representar visualmente el resultado.
- El colorHex debe reflejar el color más representativo del elemento resultado.
- Si la combinación no tiene sentido, inventa algo poético o simbólico.
- Nunca repitas los ingredientes como resultado.`;

    try {
      const completion = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 80,
        temperature: 0.8,
      });

      const content = completion.choices[0]?.message?.content?.trim() ?? "";
      const parsed = JSON.parse(content) as {
        name: string;
        emoji: string;
        colorHex: string;
      };

      if (!parsed.name || !parsed.emoji || !parsed.colorHex) {
        throw new Error("Invalid response shape from OpenAI");
      }

      // Save to Firestore (admin SDK bypasses security rules)
      const db = admin.firestore();
      const key = [ingredient1, ingredient2]
        .map((s) => s.toLowerCase().trim())
        .sort()
        .join("_");
      const recipeRef = db.collection("recipes").doc(key);
      const existing = await recipeRef.get();

      if (existing.exists) {
        // Already saved by a concurrent request — return existing data
        const d = existing.data()!;
        return {
          name: d.name as string,
          emoji: d.emoji as string,
          colorHex: d.color as string,
          isFirstDiscovery: false,
          creatorName: (d.creatorName as string) ?? "",
        };
      }

      const creatorName = username ?? "";
      await recipeRef.set({
        name: parsed.name,
        emoji: parsed.emoji,
        color: parsed.colorHex,
        createdBy: userId ?? "anonymous",
        creatorName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (userId) {
        await db
          .collection("users")
          .doc(userId)
          .set(
            { discoveryCount: admin.firestore.FieldValue.increment(1), username: creatorName },
            { merge: true }
          );
      }

      return { ...parsed, isFirstDiscovery: true, creatorName };
    } catch (err) {
      throw new functions.https.HttpsError(
        "internal",
        "Failed to generate recipe"
      );
    }
  });
