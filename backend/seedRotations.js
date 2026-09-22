const mongoose = require("mongoose");
require("dotenv").config();

const User = require("./models/User");
const Rotation = require("./models/Rotation");

const users = {
  Jason: "jason@roommate.com",
  Harish: "harish@gmail.com",
  Chandru: "chandru@gmail.com",
  Mohan: "mohan@gmail.com",
  Deepan: "deepan@gmail.com",
  Tamil: "tamil@gmail.com",
};

const trashOrder = [
  "Jason",
  "Harish",
  "Chandru",
  "Mohan",
  "Deepan",
  "Tamil",
];

const waterOrder = [
  "Mohan",
  "Chandru",
  "Tamil",
  "Jason",
  "Harish",
  "Deepan",
];

async function createRotation(name, type, order) {
  const members = [];

  for (let i = 0; i < order.length; i++) {
    const user = await User.findOne({
      email: users[order[i]],
    });

    if (!user) {
      throw new Error(
        `User not found: ${order[i]} (${users[order[i]]})`
      );
    }

    members.push({
      user: user._id,
      position: i,
    });
  }

  await Rotation.findOneAndUpdate(
    { type },
    {
      name,
      type,
      members,
      currentPosition: 0,
      penaltyDays: [],
      extraResponsibility: false,
    },
    {
      upsert: true,
      new: true,
      setDefaultsOnInsert: true,
    }
  );

  console.log(`${name} rotation created/updated ✅`);
}

async function seedRotations() {
  try {
    await mongoose.connect(process.env.MONGO_URI);

    console.log("MongoDB connected ✅");

    await createRotation(
      "Trash Rotation",
      "trash",
      trashOrder
    );

    await createRotation(
      "Water Rotation",
      "water",
      waterOrder
    );

    console.log("All rotations created successfully 🎉");

    await mongoose.disconnect();

    console.log("MongoDB disconnected.");
  } catch (error) {
    console.error("Failed to create rotations ❌");
    console.error(error.message);

    await mongoose.disconnect();
    process.exit(1);
  }
}

seedRotations();