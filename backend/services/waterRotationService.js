const Rotation = require("../models/Rotation");
const Task = require("../models/Task");

// Get water rotation
async function getWaterRotation() {
  const rotation = await Rotation.findOne({
    type: "water",
  }).populate("members.user", "name email team");

  if (!rotation) {
    throw new Error("Water rotation not found");
  }

  return rotation;
}

// Get the next person in water rotation
async function getCurrentWaterPerson() {
  const rotation = await getWaterRotation();

  const member = rotation.members.find(
    (item) => item.position === rotation.currentPosition
  );

  if (!member) {
    throw new Error("Current water rotation member not found");
  }

  return {
    user: member.user,
    position: member.position,
  };
}

// Move water rotation to next person
async function moveToNextWaterPerson() {
  const rotation = await Rotation.findOne({
    type: "water",
  });

  if (!rotation) {
    throw new Error("Water rotation not found");
  }

  rotation.currentPosition =
    (rotation.currentPosition + 1) % rotation.members.length;

  await rotation.save();

  return getCurrentWaterPerson();
}

// Report that the water is empty
async function reportWaterEmpty() {
  const existingActiveTask = await Task.findOne({
    type: "water",
    status: {
      $in: ["pending", "active"],
    },
  });

  if (existingActiveTask) {
    throw new Error(
      "There is already an active water responsibility"
    );
  }

  const current = await getCurrentWaterPerson();

  if (!current.user) {
    throw new Error("Current water user not found");
  }

  const task = await Task.create({
    type: "water",
    title: "Refill Water",
    assignedTo: current.user._id,
    status: "active",
    dueDate: new Date(),
    isPenalty: false,
    extraResponsibility: false,
  });

  return task;
}

// Complete water responsibility
async function completeWaterTask(taskId, proofImage = "") {
  const task = await Task.findById(taskId);

  if (!task) {
    throw new Error("Water task not found");
  }

  if (task.type !== "water") {
    throw new Error("This is not a water task");
  }

  if (task.status === "completed") {
    throw new Error("Water task is already completed");
  }

  if (task.status === "missed") {
    throw new Error("Missed water task cannot be completed");
  }

  if (!task.assignedTo) {
    throw new Error("Water task has no assigned user");
  }

  if (!proofImage) {
  throw new Error(
    "Proof image is required to complete the water task"
  );
 }

  task.status = "completed";
  task.completedAt = new Date();
  task.proofImage = proofImage;

  await task.save();;

  // Move to next person only after completing
  // the current water responsibility.
  await moveToNextWaterPerson();

  return task;
}

// Mark water responsibility as missed
async function markWaterMissed(taskId) {
  const task = await Task.findById(taskId);

  if (!task) {
    throw new Error("Water task not found");
  }

  if (task.type !== "water") {
    throw new Error("This is not a water task");
  }

  if (task.status === "completed") {
    throw new Error(
      "Completed water task cannot be marked as missed"
    );
  }

  if (task.status === "missed") {
    throw new Error(
      "Water task is already marked as missed"
    );
  }

  if (!task.assignedTo) {
    throw new Error(
      "Water task has no assigned user"
    );
  }

  task.status = "missed";
  await task.save();

  /*
   * Water rule:
   *
   * If someone misses their water responsibility,
   * they get an additional responsibility.
   *
   * The normal rotation does NOT move forward.
   *
   * Therefore the same person gets the next
   * water responsibility.
   */

  return task;
}

module.exports = {
  getWaterRotation,
  getCurrentWaterPerson,
  moveToNextWaterPerson,
  reportWaterEmpty,
  completeWaterTask,
  markWaterMissed,
};