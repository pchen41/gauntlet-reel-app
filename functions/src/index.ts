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
import admin from 'firebase-admin';
import { firebaseAuth } from "@genkit-ai/firebase/auth";
import { onFlow } from "@genkit-ai/firebase/functions";
import { openAI, gpt4oMini } from "genkitx-openai";
import { genkit, z } from "genkit";
import { HumanMessage, AIMessage } from "@langchain/core/messages";
import { getFirestore } from "firebase-admin/firestore";

const openAIKey = defineString("OPENAI_API_KEY");

// Initialize Firebase Admin
const app = admin.initializeApp();
const db = getFirestore(app);
const ai = genkit({
  plugins: [openAI({ apiKey: openAIKey.value() })],
  // specify a default model if not provided in generate params:
  model: gpt4oMini,
});

const getLessons = ai.defineTool(
  {
    name: "getLessons",
    description: "Fetchs a list of lessons that the climber can watch. Each lesson is a collection of videos about a topic.",
    inputSchema: z.object({}),
    outputSchema: z.array(z.object({ title: z.string(), description: z.string(), id: z.string() }))
  },
  async () => {
    return await db.collection("lessons").get().then((snapshot) => {
      return snapshot.docs.map((doc) => ({
        title: doc.data().title,
        description: doc.data().description,
        id: doc.id,
      }));
    });
  }
)

const getGoals = ai.defineTool(
  {
    name: "getGoals",
    description: "Fetchs a list of goals that the climber is trying to achieve.",
    inputSchema: z.object({
      userId: z.string().min(1)
    }),
    outputSchema: z.array(z.object({ 
      name: z.string(),
      tasks: z.array(z.object({
        name: z.string(),
        completed: z.boolean().describe("Whether the task has been completed. If the task type is 'lesson', the user needs to watch the lesson to complete it."),
        comments: z.string(),
        type: z.string().describe("The type of task this is. Can be 'text' or 'lesson'"),
        value: z.string().describe("The id of the lesson if the type is 'lesson', otherwise it is a description of the task"),
      }).describe("A list of tasks that are needed to accomplish the goal")) 
    }))
  },
  async ({ userId }) => {
    return await db.collection("goals").where("uid", "==", userId).get().then((snapshot) => {
      return snapshot.docs.map((doc) => ({
        name: doc.data().name,
        tasks: doc.data().tasks.map((task: any) => ({
          name: task.name,
          completed: task.completed,
          comments: task.comments,
          type: task.type,
          value: task.value,
        })),
      }));
    })
  }
)


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
      You are chatting to a climber that is using an app called "ClimbCoach".
      This app allows the climber improve their climbing skills by setting goals for themselves and watching lessons.
      Each goal consists of a list of tasks that the climber needs to accomplish to reach their goal. Please refer to these tasks as objectives when possible.
      Please do not fetch lessons or goals unless very relevant to the climber's question.

      Current conversation:
      ${history.join("")}

      Climber's question: ${input.message}
      The climber's userId is ${input.uid}
      
      When asked, provide specific, actionable advice that is encouraging but realistic.
      Keep your response concise. Try to stay under 3 sentences.
    `
    const response = await ai.generate({prompt, tools: [getLessons, getGoals]})

    await firestoreHistory.addMessages([
      new HumanMessage(input.message),
      new AIMessage(response.text),
    ])
    return {response: response.text}
  }
)