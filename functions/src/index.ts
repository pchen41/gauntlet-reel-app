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
import { StateGraph, Annotation } from "@langchain/langgraph";
import { ChatPromptTemplate } from "@langchain/core/prompts";
import { logger } from "firebase-functions/v2";

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
const firebasePrivateKey=defineString("FIREBASE_PRIVATE_KEY");
const firebaseClientEmail=defineString("FIREBASE_CLIENT_EMAIL");
const firebaseProjectId=defineString("FIREBASE_PROJECT_ID");

// Define the state annotation for our climbing coach workflow
// call from firebase cli: coachAIChat({"data":{"message": "test"}})
const CoachStateAnnotation = Annotation.Root({
  message: Annotation<string>,
  response: Annotation<string>,
});

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

    const model = new ChatOpenAI({
      modelName: "gpt-4",
      temperature: 0.1,
      apiKey: openAIKey.value(),
    });

    async function generateResponse(state: typeof CoachStateAnnotation.State) {
      const prompt = ChatPromptTemplate.fromTemplate(`
        You are an expert climbing coach with years of experience in both indoor and outdoor climbing.
        
        Climber's question: {message}
        
        Provide specific, actionable advice that is encouraging but realistic.
        Always prioritize safety in your response. Respond concisely.
      `);
      
      const result = await prompt.pipe(model).invoke({
        message: state.message,
      });
      
      return { response: result.content };
    }

    // Build the workflow
    const workflow = new StateGraph(CoachStateAnnotation)
      .addNode("respond", generateResponse)
      .addEdge("__start__", "respond")
      .addEdge("respond", "__end__")
      .compile();

    // Run the workflow
    const finalState = await workflow.invoke({
      message: message,
    });

    return { response: finalState.response };

  } catch (error) {
    logger.error("Error in coachAIChat:", error);
    throw new Error("Internal server error");
  }
})