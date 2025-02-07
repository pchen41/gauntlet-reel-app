/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {onCall} from "firebase-functions/v2/https";
import {defineString} from "firebase-functions/params";
import { ChatOpenAI } from "@langchain/openai";
import { ChatPromptTemplate } from "@langchain/core/prompts";
import { logger } from "firebase-functions/v2";
import { BufferMemory } from "langchain/memory";
import { FirestoreChatMessageHistory } from "@langchain/community/stores/message/firestore";
import { ConversationChain } from "langchain/chains";
import { initializeApp } from 'firebase-admin/app';
import { firebaseAuth } from "@genkit-ai/firebase/auth";
import { onFlow } from "@genkit-ai/firebase/functions";
import { openAI, gpt4oMini } from "genkitx-openai";
import { genkit } from "genkit";
import { HumanMessage, AIMessage } from "@langchain/core/messages";

// Initialize Firebase Admin
initializeApp();

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

/*import {seedLessons} from "./lessons";

// run with google cloud cli e.g. 'gcloud functions call seedLessons2 --region=us-central1 --gen2'
export const seedLessons2 = onRequest((request, response) => {
  seedLessons(request, response);
});*/

const openAIKey = defineString("OPENAI_API_KEY");
/*const firebasePrivateKey=defineString("FIREBASE_PRIVATE_KEY");
const firebaseClientEmail=defineString("FIREBASE_CLIENT_EMAIL");
const firebaseProjectId=defineString("FIREBASE_PROJECT_ID");*/

// call from firebase cli: coachAIChat({"data":{"message": "test"}})
export const coachAIChat = onCall(async (request) => {
  try {
    // Check if the user is authenticated
    if (!request.auth) {
      throw new Error("Unauthorized - User must be authenticated");
    }

    const message = request.data.message;
    if (!message) {
      throw new Error("Message is required in request data");
    }

    const userId = request.auth.uid;

    // Set up chat history with Firestore
    const memory = new BufferMemory({
      chatHistory: new FirestoreChatMessageHistory({
        collections: ["ai_chats"],
        docs: [userId],
        sessionId: userId,
        userId: userId,
      }),
      aiPrefix: "Coach",
      humanPrefix: "Climber",
      memoryKey: "history",
    });

    const model = new ChatOpenAI({
      modelName: "gpt-4o-mini",
      temperature: 0.1,
      apiKey: openAIKey.value(),
    });

    const prompt = ChatPromptTemplate.fromTemplate(`
      You are an expert climbing coach with years of experience in both indoor and outdoor climbing.

      Current conversation:
      {history}

      Climber's question: {input}
      
      When asked, provide specific, actionable advice that is encouraging but realistic.
      Keep your response concise. Try to stay under 3 sentences.
    `);

    const chain = new ConversationChain({ 
      llm: model,
      memory: memory,
      prompt: prompt
    });

    const result = await chain.call({
      input: message,
    });

    return { response: result.response };

  } catch (error) {
    logger.error("Error in coachAIChat:", error);
    throw new Error("Internal server error");
  }
})


const ai = genkit({
  plugins: [openAI({ apiKey: openAIKey.value() })],
  // specify a default model if not provided in generate params:
  model: gpt4oMini,
});

export const coachAIChatGenkit = onFlow(
  ai,
  {
    name: "coachAIChatGenkit",
    authPolicy: firebaseAuth((auth, input) => {
      if (!auth || auth.uid !== input.uid) {
        throw new Error("Not authorized")
      }
    })
  },
  async (input: {uid: string, message: string}) => {
    const userId = input.uid
    const firestoreHistory = new FirestoreChatMessageHistory({
      collections: ["ai_chats"],
      docs: [userId],
      sessionId: userId,
      userId: userId,
    });

    const history = (await firestoreHistory.getMessages()).map((message) => (
      `${message.getType() == "human" ? "Climber" : "Coach"}: ${message.content.toString()}\n`
    ))

    const prompt = `
      You are an expert climbing coach with years of experience in both indoor and outdoor climbing.

      Current conversation:
      ${history.join("")}

      Climber's question: ${input.message}
      
      When asked, provide specific, actionable advice that is encouraging but realistic.
      Keep your response concise. Try to stay under 3 sentences.
    `

    const response = await ai.generate(prompt)

    firestoreHistory.addMessages([
      new HumanMessage(input.message),
      new AIMessage(response.text),
    ])
    return response.text
  }
)