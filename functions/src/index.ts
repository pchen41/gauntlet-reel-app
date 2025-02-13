/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {isSignedIn, onCall, onCallGenkit} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import { ChatOpenAI } from "@langchain/openai";
import { ChatPromptTemplate } from "@langchain/core/prompts";
import { logger } from "firebase-functions/v2";
import { BufferMemory } from "langchain/memory";
import { FirestoreChatMessageHistory } from "@langchain/community/stores/message/firestore";
import { ConversationChain } from "langchain/chains";
import admin from 'firebase-admin';
//import { openAI, gpt4oMini } from "genkitx-openai";
import { genkit, z } from "genkit";
import { HumanMessage, AIMessage } from "@langchain/core/messages";
import { getFirestore } from "firebase-admin/firestore";
import { enableFirebaseTelemetry } from "@genkit-ai/firebase";
import { gemini20Flash, googleAI } from '@genkit-ai/googleai';
import OpenAI from "openai";

//const openAIKey = defineSecret("OPENAI_API_KEY");
const googleAPIKey = defineSecret("GOOGLE_GENAI_API_KEY");
// Initialize Firebase Admin
const app = admin.initializeApp();
enableFirebaseTelemetry(
  {
    metricExportIntervalMillis: 20000,
    metricExportTimeoutMillis: 20000
  }
);
const db = getFirestore(app);
const ai = genkit({
  /*plugins: [openAI({ apiKey: openAIKey.value() })],
  // specify a default model if not provided in generate params:
  model: gpt4oMini,*/
  plugins: [googleAI()],
  model: gemini20Flash, // set default model
});

const getLessons = ai.defineTool(
  {
    name: "getLessons",
    description: "Fetchs a list of lessons that the climber can watch.",
    inputSchema: z.object({
      userId: z.string().min(1)
    }),
    outputSchema: z.array(
      z.object({ 
        title: z.string(), 
        description: z.string(), 
        id: z.string()
      })).describe("A list of lessons, where each lesson is a series of videos about a topic.")
  },
  async ({ userId }) => {
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
      id: z.string(),
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
        id: doc.id,
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

/*
const annotateImage = ai.defineTool(
  {
    name: "annotateImage",
    description: "Annotates an image given a prompt and an image URL",
    inputSchema: z.object({
      prompt: z.string().min(1),
      imageUrl: z.string().min(1),
    }),
    outputSchema: z.object({
      annotatedImageUrl: z.string().min(1),
    })
  },
  async ({ prompt, imageUrl }) => {
    return {
      annotatedImageUrl: " ",
    }
  }
)*/

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
      //apiKey: openAIKey.value(),
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

export const coachAIChatOpenAI = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthorized - User must be authenticated");
  }

  const message = request.data.message;
  if (!message) {
    throw new Error("Message is required in request data");
  }

  const imageUrl = request.data.image;

  const userId = request.auth.uid;
  const openai = new OpenAI({
    //apiKey: openAIKey.value(),
  })

  // Fetch both lessons and goals concurrently
  const [lessonsSnapshot, goalsSnapshot] = await Promise.all([
    admin.firestore().collection('lessons')
      .select('title', 'description')
      .get(),
    admin.firestore().collection('goals')
      .where('uid', '==', userId)
      .select('name', 'tasks')
      .get()
  ]);

  const formattedLessons = lessonsSnapshot.docs.map(doc => {
    const data = doc.data();
    return `{"title": "${data.title}", "description": "${data.description}", "id": "${doc.id}"}`;
  }).join('\n');

  const formattedGoals = goalsSnapshot.docs.map(doc => {
    const data = doc.data();
    const formattedTasks = (data.tasks || []).map((task: any) => {
      return `{"name": "${task.name}", "completed": ${task.completed}, "comments": "${task.comments || ''}", "type": "${task.type}", "value": "${task.value}"}`;
    }).join(',\n          ');
    return `{
      "id": "${doc.id}",
      "name": "${data.name}",
      "tasks": [
      ${formattedTasks}
      ]
    }`;
  }).join('\n');

  const system = `
    You are an expert climbing coach with years of experience in both indoor and outdoor climbing.
    You are chatting to a climber that is using an app called "ClimbCoach".
    This app allows the climber improve their climbing skills by setting goals for themselves and watching lessons.
    Each lesson contains a series of videos that correspond to the lesson topic.
    Each goal consists of a list of tasks that need to be completed to accomplish the goal.
    If the task is of type "text", then the value is just the description of the task.
    If the task is of type "lesson", then the value is just the lesson ID.

    Here are the lessons (in JSON format):
    ${formattedLessons}

    Here are the user's current goals (in JSON format):
    ${formattedGoals}

    When asked, provide specific, actionable advice that is encouraging but realistic.
    Keep your response concise. Try to stay under 3 sentences.

    The climber's userId is ${userId}

    Output should be in JSON format and conform to the following schema:
    {"type":"object","properties":{"message":{"type":"string","description":"The response from the coach"},"lessons":{"type":"array","items":{"type":"object","properties":{"title":{"type":"string"},"description":{"type":"string"},"id":{"type":"string"}},"required":["title","description","id"],"additionalProperties":true},"description":"Any lessons that the coach recommends to the climber. Do not add lessons unless they are mentioned in the message."},"goals":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"name":{"type":"string"}},"required":["id","name"],"additionalProperties":true},"description":"Any goals that the coach referenced in their message"},"proposedGoals":{"type":"array","items":{"type":"object","properties":{"name":{"type":"string"},"tasks":{"type":"array","items":{"type":"object","properties":{"name":{"type":"string"},"completed":{"type":"boolean"},"comments":{"type":"string"},"type":{"type":"string"},"value":{"type":"string"}},"required":["name","completed","comments","type","value"],"additionalProperties":true}},"required":["name","tasks"],"additionalProperties":true},"description":"Any goals that the coach proposes to the climber."}},"required":["message"],"additionalProperties":true,"$schema":"http://json-schema.org/draft-07/schema#"}

    Please always provide something in the "message" field to give the climber additional context. If there is any question about a picture or image, please refer to the attached image if any.
  `

  const content: any[] = [
    {type: "text", text: message},
  ]

  if (imageUrl) {
    content.push({type: "image_url", image_url: {url: imageUrl}})
  }

  const result = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    temperature: 0.5,
    messages: [
      {
        role: "developer",
        content: system
      },
      {
        role: "user",
        content: content
      }
    ],
  })

  return {response: result.choices[0].message.content}
})

const coachAIChatGenkitInternal = ai.defineFlow(
  {
    name: "coachAIChatGenkit",
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

export const coachAiGenkit = onCallGenkit(
  {
    authPolicy: isSignedIn(),
    secrets: [googleAPIKey],
  },
  coachAIChatGenkitInternal,
)

const coachAIChatGenkitStructuredInternal = ai.defineFlow(
  {
    name: "coachAIChatGenkitStructured",
  },
  async (input: {uid: string, message: string, image?: string}) => {
    const userId = input.uid

    const userDoc = await db.collection('users').doc(userId).get();
    const userName = userDoc.exists ? userDoc.data()?.name : '';

    // Fetch existing messages
    const existingChatRef = db.collection('genkit_chats').doc(userId);
    const existingMessagesRef = existingChatRef.collection('messages');
    const messagesSnapshot = await existingMessagesRef
      .orderBy('timestamp', 'asc')
      .get();
    const messages = messagesSnapshot.docs
      .map(doc => doc.data())
      .sort((a, b) => {
        // First sort by timestamp
        const timestampA = a.timestamp?.seconds || 0;
        const timestampB = b.timestamp?.seconds || 0;
        if (timestampA !== timestampB) {
          return timestampA - timestampB;
        }
        // If timestamps are equal, user messages come first
        if (a.role === 'user' && b.role !== 'user') return -1;
        if (a.role !== 'user' && b.role === 'user') return 1;
        return 0;
      });

      // Fetch lessons from Firebase
      const lessonsSnapshot = await admin.firestore().collection('lessons')
        .select('title', 'description')
        .get();
      
      const formattedLessons = lessonsSnapshot.docs.map(doc => {
        const data = doc.data();
        return `{"title": "${data.title}", "description": "${data.description}", "id": "${doc.id}"}`;
      }).join('\n');

      // Fetch user's goals from Firebase
      const goalsSnapshot = await admin.firestore().collection('goals')
        .where('uid', '==', userId)
        .select('name', 'tasks')
        .get();

      const formattedGoals = goalsSnapshot.docs.map(doc => {
        const data = doc.data();
        const formattedTasks = (data.tasks || []).map((task: any) => {
          return `{"name": "${task.name}", "completed": ${task.completed}, "comments": "${task.comments || ''}", "type": "${task.type}", "value": "${task.value}"}`;
        }).join(',\n          ');
        return `{
          "id": "${doc.id}",
          "name": "${data.name}",
          "tasks": [
          ${formattedTasks}
          ]
        }`;
      }).join('\n');

    // genkit doesn't support tool calling with output schema, so I have to manually include the schema :()
    const system = `
      You are an expert climbing coach with years of experience in both indoor and outdoor climbing.
      You are chatting to a climber that is using an app called "ClimbCoach".
      This app allows the climber improve their climbing skills by setting goals for themselves and watching lessons.
      Each lesson contains a series of videos that correspond to the lesson topic.
      Each goal consists of a list of tasks that need to be completed to accomplish the goal.
      If the task is of type "text", then the value is just the description of the task.
      If the task is of type "lesson", then the value is just the lesson ID.

      Here are the lessons (in JSON format):
      ${formattedLessons}

      Here are the user's current goals (in JSON format):
      ${formattedGoals}

      When asked, provide specific, actionable advice that is encouraging but realistic.
      Keep your response concise. Try to stay under 3 sentences.

      The climber's userId is ${userId}
      The climber's name is ${userName}

      Output should be in JSON format and conform to the following schema:
      {"type":"object","properties":{"message":{"type":"string","description":"The response from the coach"},"lessons":{"type":"array","items":{"type":"object","properties":{"title":{"type":"string"},"description":{"type":"string"},"id":{"type":"string"}},"required":["title","description","id"],"additionalProperties":true},"description":"Any lessons that the coach recommends to the climber. Do not add lessons unless they are mentioned in the message."},"goals":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"name":{"type":"string"}},"required":["id","name"],"additionalProperties":true},"description":"Any goals that the coach referenced in their message"},"proposedGoals":{"type":"array","items":{"type":"object","properties":{"name":{"type":"string"},"tasks":{"type":"array","items":{"type":"object","properties":{"name":{"type":"string"},"completed":{"type":"boolean"},"comments":{"type":"string"},"type":{"type":"string"},"value":{"type":"string"}},"required":["name","completed","comments","type","value"],"additionalProperties":true}},"required":["name","tasks"],"additionalProperties":true},"description":"Any goals that the coach proposes to the climber."}},"required":["message"],"additionalProperties":true,"$schema":"http://json-schema.org/draft-07/schema#"}
    
      Please always provide something in the "message" field to give the climber additional context. If there is any question about a picture or image, please refer to the attached image if any. Do not use any ids the message field.
    `

    const prompt = input.message

    const formattedPrompt = input.image ? 
    [
      { media: {url: input.image}},
      { text: input.message},
    ] : prompt

    const response = await ai.generate(
      {
        system: system,
        prompt: formattedPrompt,
        messages: messages ? messages as any : undefined,
        /*output: {
          format: 'json',
          schema: z.object({
            message: z.string().describe("The response from the coach"),
            lessons: z.array(z.object({
              title: z.string(),
              description: z.string(),
              id: z.string(),
            })).optional().describe("Any lessons that the coach recommends to the climber. Do not add lessons unless they are mentioned in the message."),
            goals: z.array(z.object({
              id: z.string(),
              name: z.string(),
            })).optional().describe("Any goals that the coach referenced in their message"),
            proposedGoals: z.array(z.object({
              id: z.string().optional().describe("The id of the goal if the goal already exists. The proposed goal will overwrite the existing goal. this is used to update existing goals."),
              name: z.string(),
              tasks: z.array(z.object({
                name: z.string(),
                completed: z.boolean(),
                comments: z.string(),
                type: z.string(),
                value: z.string(),
              }))
            })).optional().describe("Any goals or goal updates that the coach proposes to the climber."),
          })
        }*/
      }
    )

    // Store messages in Firestore
    const chatRef = db.collection('genkit_chats').doc(userId);
    const messagesRef = chatRef.collection('messages');
    const responseJson = response.toJSON()
    const responseMessage = responseJson.message

    // Use batch write for multiple messages
    const batch = db.batch();
    
    // Add user message
    const userMessageRef = messagesRef.doc();
    batch.set(userMessageRef, {
      role: "user",
      content: input.image ? [
        {
          media: {
            url: input.image
          }
        },
        {
          text: input.message
        }
      ] : [
        {
          text: input.message
        }
      ],
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Add AI response message
    const aiMessageRef = messagesRef.doc();
    batch.set(aiMessageRef, {
      role: responseMessage?.role,
      content: JSON.parse(JSON.stringify(responseMessage?.content)),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Commit the batch
    await batch.commit();
    
    return {response: response.output?.message, lessons: response.output?.lessons, goals: response.output?.goals, proposedGoals: response.output?.proposedGoals}
  }
)

export const coachAiGenkitStructured = onCallGenkit(
  {
    authPolicy: isSignedIn(),
    secrets: [googleAPIKey],
  },
  coachAIChatGenkitStructuredInternal,
)

const summarizeLessonInternal = ai.defineFlow(
  {
    name: "summarizeLesson",
  },
  async (input: { lessonId: string }) => {
    // Fetch the lesson document
    const lessonDoc = await db.collection('lessons').doc(input.lessonId).get();
    if (!lessonDoc.exists) {
      throw new Error('Lesson not found');
    }
    const lesson = lessonDoc.data();
    if (!lesson || !lesson.videos) {
      throw new Error('Lesson is empty')
    }

    // Batch get all videos in a single request
    const videosSnapshot = await db.getAll(
      ...lesson.videos.map((videoId: string) => db.collection('videos').doc(videoId))
    );
    const videos = videosSnapshot.map(doc => doc.data());

    // Get all comments for these videos in a single query
    const commentsSnapshot = await db.collection('comments')
      .where('video_id', 'in', lesson.videos)
      .orderBy('created_at', 'desc')
      .get();

    // Group comments by video ID
    const commentsByVideo = lesson.videos.map((videoId: string) => ({
      videoId,
      comments: commentsSnapshot.docs
        .filter((doc: any) => doc.data().video_id === videoId)
        .map((doc: any) => doc.data())
    }));

    const prompt = `
      This is data from a lessons screen for an app called "ClimbCoach" which helps climbers improve their climbing skills.

      Here is a lesson name and description:
      Title: ${lesson.title}
      Description: ${lesson.description}

      Here are the videos in the lesson (in JSON format):
      ${JSON.stringify(videos, null, 2)}

      Here are the comments on the videos (in JSON format):
      ${JSON.stringify(commentsByVideo, null, 2)}

      The user can already the the lesson name and description, video count, and a list of the videos including the video names and descriptions.
      Please give a summary of the provided data. Try to provide insightful information. Do not include IDs in your response. Keep your answer short and concise.
    `

    const response = await ai.generate(
      {
        prompt: prompt,
      }
    )

    return {response: response.message}
  }
)

export const summarizeLesson = onCallGenkit(
  {
    authPolicy: isSignedIn(),
    secrets: [googleAPIKey],
  },
  summarizeLessonInternal,
)
