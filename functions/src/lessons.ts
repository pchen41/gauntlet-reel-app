// this is intended to be only run once to seed the lessons

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export const seedLessons = functions.https.onRequest(async (req, res) => {
  const authorId = "qtRP3vPrRZeWLkg2RwxsvNafFD43";
  const videoIds = [
    "3555c5e5-8045-47f6-aeac-c4fa5d49a100",
    "c4c9823f-d90b-488c-8825-8d058cb4f8b9",
    "1abfd4af-7d4c-4f3b-afa7-e3b1e36d1e68",
    "2a3427f8-312c-4cfe-bf5c-b167885b38b4",
    "d6c9861d-ab36-4ed6-9cbe-489c88b18f86",
    "a03794c2-b8c6-4faa-b6e4-9f7fb4259ee9",
  ];

  const lessons = [
    {
      title: "Grip and Rip",
      description: "Explore the essentials of building finger strength. This lesson covers hangboard techniques, grip variations, and exercises to enhance endurance.",
      videos: getRandomVideoIds(videoIds, 3),
    },
    {
      title: "Top-Rope Techniques",
      description: "Learn the fundamentals of top-rope climbing with a focus on proper foot placement, body alignment, and efficient rope management.",
      videos: getRandomVideoIds(videoIds, 2),
    },
    {
      title: "Bouldering Basics",
      description: "An introduction to bouldering that covers solving problems on shorter routes, dynamic movements, and spotting essentials.",
      videos: getRandomVideoIds(videoIds, 4),
    },
    {
      title: "Crux Conqueror",
      description: "Strategies for tackling the most challenging sections of a climb. This lesson emphasizes mental preparation and technique to overcome crux moves.",
      videos: getRandomVideoIds(videoIds, 3),
    },
    {
      title: "Dyno Mastery",
      description: "Develop explosive power and timing with techniques focused on dynamic moves that help you reach distant holds.",
      videos: getRandomVideoIds(videoIds, 2),
    },
    {
      title: "Route Reading & Strategy",
      description: "Master the art of analyzing a route before you climb. Topics include visualizing moves, planning sequences, and optimizing A-to-B efficiency.",
      videos: getRandomVideoIds(videoIds, 3),
    },
    {
      title: "Rock Anatomy",
      description: "Understand the different types of rock and how their formations affect climbing. This lesson includes tips on identifying holds based on rock type.",
      videos: getRandomVideoIds(videoIds, 2),
    },
    {
      title: "Fall Safety Fundamentals",
      description: "Focus on minimizing risk with lessons on proper use of protection gear, fall review techniques, and safe landing practices.",
      videos: getRandomVideoIds(videoIds, 4),
    },
    {
      title: "Yoga for Climbers",
      description: "Enhance flexibility and balance with a climbing-focused yoga routine. Learn poses that support core strength and injury prevention.",
      videos: getRandomVideoIds(videoIds, 3),
    },
    {
      title: "Balance & Core Strength",
      description: "Target your midsection and balance with specific exercises that improve stability on the wall, making trickier routes more manageable.",
      videos: getRandomVideoIds(videoIds, 3),
    },
    {
      title: "Energy Management on the Wall",
      description: "Understand how to pace yourself during long climbs. This lesson discusses techniques for energy conservation and efficient movement.",
      videos: getRandomVideoIds(videoIds, 2),
    },
    {
      title: "Mental Focus & Fear Management",
      description: "Develop psychological tools to conquer fear and anxiety. Techniques include breathing exercises and mindfulness to keep you focused.",
      videos: getRandomVideoIds(videoIds, 3),
    },
    {
      title: "Footwork Fundamentals",
      description: "Discover why precise foot placement is crucial. This lesson delves into techniques to maximize foothold effectiveness and reduce strain on upper body muscles.",
      videos: getRandomVideoIds(videoIds, 4),
    },
    {
      title: "Advanced Climbing Techniques",
      description: "Take your skills beyond the basics with advanced maneuvers, including heel hooks, drop knees, and high-step strategies.",
      videos: getRandomVideoIds(videoIds, 3),
    },
    {
      title: "Training Injury Prevention",
      description: "Learn best practices for warming up, stretching, and recovery techniques to avoid common climbing injuries.",
      videos: getRandomVideoIds(videoIds, 2),
    },
    {
      title: "Climbing Nutrition & Hydration",
      description: "Get insights into the best foods and hydration strategies to fuel your climbs and maintain energy over long sessions.",
      videos: getRandomVideoIds(videoIds, 3),
    },
    {
      title: "Balance in Transition Moves",
      description: "Focus on techniques that smooth out the transitions between holds and moves. Learn to maintain balance and fluidity even on challenging routes.",
      videos: getRandomVideoIds(videoIds, 3),
    },
    {
      title: "Solo Climbing Safety",
      description: "Understand the precautions and techniques for safe solo climbs. This lesson covers risk assessment and self-rescue techniques.",
      videos: getRandomVideoIds(videoIds, 4),
    },
    {
      title: "Bouldering Problem Solving",
      description: "Improve your problem-solving skills on the boulder. Lessons include analyzing beta, sequencing moves, and trial-and-error strategies.",
      videos: getRandomVideoIds(videoIds, 3),
    },
    {
      title: "Improving Endurance for Climbing",
      description: "Build sustainable strength and stamina with a routine that combines cardio, strength training, and recovery sessions for long days on the wall.",
      videos: getRandomVideoIds(videoIds, 3),
    },
  ];

  try {
    const batch = db.batch();
    const lessonsRef = db.collection("lessons");

    lessons.forEach((lesson) => {
      const docRef = lessonsRef.doc();
      batch.set(docRef, {
        ...lesson,
        author_uid: authorId,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
    res.status(200).json({message: "Successfully seeded lessons", count: lessons.length});
  } catch (error) {
    console.error("Error seeding lessons:", error);
    res.status(500).json({error: "Failed to seed lessons"});
  }
});

function getRandomVideoIds(videoIds: string[], count: number): string[] {
  const shuffled = [...videoIds].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count);
}