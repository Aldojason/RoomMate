const Rotation = require("../models/Rotation");
const Task = require("../models/Task");

// Get the trash rotation
async function getTrashRotation() {
  const rotation = await Rotation.findOne({
    type: "trash",
  }).populate("members.user", "name email team");

  if (!rotation) {
    throw new Error("Trash rotation not found");
  }

  return rotation;
}

// Get the current normal rotation person
async function getCurrentTrashPerson() {
  const rotation = await getTrashRotation();

  const member = rotation.members.find(
    (item) => item.position === rotation.currentPosition
  );

  if (!member) {
    throw new Error("Current trash rotation member not found");
  }

  return {
    user: member.user,
    position: member.position,
  };
}

// Move normal rotation to next person
async function moveToNextTrashPerson() {
  const rotation = await Rotation.findOne({
    type: "trash",
  });

  if (!rotation) {
    throw new Error("Trash rotation not found");
  }

  rotation.currentPosition =
    (rotation.currentPosition + 1) % rotation.members.length;

  await rotation.save();

  return getCurrentTrashPerson();
}

// Get outstanding penalty days
function getPenaltyDays(rotation, userId) {
  if (!rotation.penaltyDays) {
    return 0;
  }

  const penalty = rotation.penaltyDays.find(
    (item) => item.user.toString() === userId.toString()
  );

  return penalty ? penalty.days : 0;
}

// Set outstanding penalty days
async function setPenaltyDays(rotation, userId, days) {
  if (!rotation.penaltyDays) {
    rotation.penaltyDays = [];
  }

  const existing = rotation.penaltyDays.find(
    (item) => item.user.toString() === userId.toString()
  );

  if (days <= 0) {
    rotation.penaltyDays = rotation.penaltyDays.filter(
      (item) => item.user.toString() !== userId.toString()
    );
  } else if (existing) {
    existing.days = days;
  } else {
    rotation.penaltyDays.push({
      user: userId,
      days,
    });
  }

  await rotation.save();
}

// Create normal trash task
async function createTrashTask(dueDate) {
  const current = await getCurrentTrashPerson();

  if (!current.user) {
    throw new Error("Current trash user not found");
  }

  const task = await Task.create({
    type: "trash",
    title: "Take Out Trash",
    assignedTo: current.user._id,
    status: "pending",
    dueDate,
    isPenalty: false,
    isSundayTeamTask: false,
  });

  return task;
}

// Create penalty trash task
async function createPenaltyTask(userId, dueDate, originalTaskId = null) {
  const task = await Task.create({
    type: "trash",
    title: "Take Out Trash - Penalty",
    assignedTo: userId,
    status: "pending",
    dueDate,
    isPenalty: true,
    penaltyForTask: originalTaskId,
    isSundayTeamTask: false,
  });

  return task;
}

// Process today's trash responsibility
// Process today's trash responsibility
async function processDailyTrashRotation(dueDate) {
  const rotation = await Rotation.findOne({
    type: "trash",
  });

  if (!rotation) {
    throw new Error("Trash rotation not found");
  }

  const currentMember = rotation.members.find(
    (item) => item.position === rotation.currentPosition
  );

  if (!currentMember) {
    throw new Error("Current trash rotation member not found");
  }

  const userId = currentMember.user;

  if (!userId) {
    throw new Error("Current trash user not found");
  }

  const date = new Date(dueDate);
  console.log("PROCESSING TRASH DATE:", date.toISOString());

  if (Number.isNaN(date.getTime())) {
    throw new Error("Invalid due date");
  }

  // Treat the supplied date as an IST calendar date.
  const istDateString = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);

  // Convert IST day boundaries to UTC.
  const startOfDay = new Date(`${istDateString}T00:00:00+05:30`);
  const endOfDay = new Date(`${istDateString}T23:59:59.999+05:30`);

  console.log("START OF DAY:", startOfDay.toISOString());
  console.log("END OF DAY:", endOfDay.toISOString());

  // Sunday Trash is handled separately by Sunday cleaning.
  const dayOfWeek = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Kolkata",
    weekday: "short",
  }).format(date);

  if (dayOfWeek === "Sun") {
    return null;
  }

  // Only ONE individual Trash task can exist for an IST calendar day.
  const existingTask = await Task.findOne({
    type: "trash",
    isSundayTeamTask: false,
    dueDate: {
      $gte: startOfDay,
      $lte: endOfDay,
    },
  });

  if (existingTask) {
    return existingTask;
  }

  const outstandingPenalty = getPenaltyDays(
    rotation,
    userId
  );

  // Penalty takes priority over normal rotation.
  if (outstandingPenalty > 0) {
    return await createPenaltyTask(
      userId,
      date
    );
  }

  // Normal responsibility.
  return await Task.create({
    type: "trash",
    title: "Take Out Trash",
    assignedTo: userId,
    status: "pending",
    dueDate: date,
    isPenalty: false,
    isSundayTeamTask: false,
  });
}
// Mark trash task as missed
async function markTrashMissed(taskId) {
  const task = await Task.findById(taskId);

  if (!task) {
    throw new Error("Trash task not found");
  }

  if (task.type !== "trash") {
    throw new Error("This is not a trash task");
  }

  if (task.status === "completed") {
    throw new Error(
      "Completed task cannot be marked as missed"
    );
  }

  if (task.status === "missed") {
    throw new Error(
      "Task is already marked as missed"
    );
  }

  if (!task.assignedTo) {
    throw new Error(
      "Trash task has no assigned user"
    );
  }

  task.status = "missed";
  await task.save();

  const rotation = await Rotation.findOne({
    type: "trash",
  });

  if (!rotation) {
    throw new Error("Trash rotation not found");
  }

  const userId = task.assignedTo;

  const currentPenalty = getPenaltyDays(
    rotation,
    userId
  );

  /*
   * RULE:
   *
   * Normal task missed:
   *   +2 penalty days
   *
   * Penalty task missed:
   *   +1 additional penalty day
   *
   * Example:
   *
   * Monday: Jason misses normal task
   * Tuesday: Jason penalty
   * Wednesday: Jason penalty
   * Thursday: Harish
   *
   * If Jason misses Tuesday:
   * Tuesday missed
   * Wednesday + Thursday + Friday = Jason
   */

  if (task.isPenalty) {
    await setPenaltyDays(
      rotation,
      userId,
      currentPenalty + 1
    );
  } else {
    await setPenaltyDays(
      rotation,
      userId,
      currentPenalty + 2
    );
  }

  return task;
}

// Complete trash task
async function completeTrashTask(taskId, proofImage = "") {
  const task = await Task.findById(taskId);

  if (!task) {
    throw new Error("Trash task not found");
  }

  if (task.type !== "trash") {
    throw new Error("This is not a trash task");
  }

  if (task.status === "completed") {
    throw new Error(
      "Task is already completed"
    );
  }

  if (task.status === "missed") {
    throw new Error(
      "Missed task cannot be completed"
    );
  }

  if (!task.assignedTo) {
    throw new Error(
      "Trash task has no assigned user"
    );
  }

  if (!proofImage) {
    throw new Error(
      "Proof image is required to complete the trash task"
    );
  }

  task.status = "completed";
  task.completedAt = new Date();
  task.proofImage = proofImage;

  await task.save();
  const rotation = await Rotation.findOne({
    type: "trash",
  });

  if (!rotation) {
    throw new Error("Trash rotation not found");
  }

  const userId = task.assignedTo;

  const currentPenalty = getPenaltyDays(
    rotation,
    userId
  );

  if (currentPenalty > 0) {
    // Complete one penalty day
    const remainingPenalty =
      currentPenalty - 1;

    await setPenaltyDays(
      rotation,
      userId,
      remainingPenalty
    );

    // Only after ALL penalty days are completed
    // does normal rotation move forward.
    if (remainingPenalty === 0) {
      await moveToNextTrashPerson();
    }
  } else {
    // Normal task completed
    await moveToNextTrashPerson();
  }

  return task;
}

// Automatically mark unfinished Trash tasks from previous days as missed
async function processOverdueTrashTasks() {
  const now = new Date();

  const overdueTasks = await Task.find({
    type: "trash",
    isSundayTeamTask: false,
    status: {
      $in: ["pending", "active"],
    },
    dueDate: {
      $lt: new Date(
        now.getFullYear(),
        now.getMonth(),
        now.getDate()
      ),
    },
  });

  for (const task of overdueTasks) {
    await markTrashMissed(task._id);
  }

  return overdueTasks.length;
}

module.exports = {
  getTrashRotation,
  getCurrentTrashPerson,
  moveToNextTrashPerson,
  createTrashTask,
  createPenaltyTask,
  markTrashMissed,
  completeTrashTask,
  processDailyTrashRotation,
  processOverdueTrashTasks,
};