const express = require("express");
const Task = require("../models/Task");
const upload = require("../middleware/upload");
const { uploadImage } = require("../services/imageUploadService");
const { protect } = require("../middleware/authMiddleware");

const {
  getCurrentTrashPerson,
  processDailyTrashRotation,
  markTrashMissed,
  completeTrashTask,
} = require("../services/trashRotationService");

const {
  getCurrentWaterPerson,
  reportWaterEmpty,
  completeWaterTask,
  markWaterMissed,
} = require("../services/waterRotationService");

const router = express.Router();


// ============================================================
// IST HELPERS
// ALL BACKEND DATE/TIME LOGIC USES ASIA/KOLKATA
// ============================================================

function getISTNow() {
  return new Date(
    new Date().toLocaleString("en-US", {
      timeZone: "Asia/Kolkata",
    })
  );
}

function getISTDateParts(date = new Date()) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });

  const parts = formatter.formatToParts(date);

  const year = Number(
    parts.find((part) => part.type === "year").value
  );

  const month = Number(
    parts.find((part) => part.type === "month").value
  );

  const day = Number(
    parts.find((part) => part.type === "day").value
  );

  return {
    year,
    month,
    day,
  };
}

function getISTDayRange(date = new Date()) {
  const { year, month, day } = getISTDateParts(date);

  // Create UTC instants corresponding to
  // 00:00:00 and 23:59:59.999 in India.
  const startOfDay = new Date(
    Date.UTC(year, month - 1, day, 0, 0, 0, 0) -
      5.5 * 60 * 60 * 1000
  );

  const endOfDay = new Date(
    Date.UTC(year, month - 1, day, 23, 59, 59, 999) -
      5.5 * 60 * 60 * 1000
  );

  return {
    startOfDay,
    endOfDay,
  };
}

function getISTWeekday(date = new Date()) {
  const { year, month, day } = getISTDateParts(date);

  // Use UTC only after the IST calendar date has been determined.
  return new Date(
    Date.UTC(year, month - 1, day)
  ).getUTCDay();
}


// ============================================================
// HELPER — ONLY ASSIGNED USER CAN MODIFY A TASK
// ============================================================

async function requireTaskOwner(req, res, taskId) {
  const task = await Task.findById(taskId);

  if (!task) {
    res.status(404).json({
      success: false,
      message: "Task not found",
    });

    return null;
  }

  if (
    !task.assignedTo ||
    task.assignedTo.toString() !== req.user._id.toString()
  ) {
    res.status(403).json({
      success: false,
      message: "You can only modify your own assigned task",
    });

    return null;
  }

  return task;
}


// ============================================================
// GET ALL TASKS
// ============================================================

router.get("/", async (req, res) => {
  try {
    const tasks = await Task.find()
      .populate("assignedTo", "name email team")
      .sort({ dueDate: 1 });

    res.json({
      success: true,
      tasks,
    });
  } catch (error) {
    console.error("Get tasks error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to get tasks",
    });
  }
});


// ============================================================
// GET SINGLE TASK
// ============================================================

router.get("/:id", async (req, res) => {
  try {
    const task = await Task.findById(req.params.id).populate(
      "assignedTo",
      "name email team"
    );

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Task not found",
      });
    }

    res.json({
      success: true,
      task,
    });
  } catch (error) {
    console.error("Get task error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to get task",
    });
  }
});


// ============================================================
// CREATE TASK
// ============================================================

router.post("/", async (req, res) => {
  try {
    const {
      type,
      title,
      assignedTo,
      assignedTeam,
      status,
      dueDate,
    } = req.body;

    if (!type || !title || !dueDate) {
      return res.status(400).json({
        success: false,
        message: "Type, title and dueDate are required",
      });
    }

    const task = await Task.create({
      type,
      title,
      assignedTo: assignedTo || null,
      assignedTeam: assignedTeam || null,
      status: status || "pending",
      dueDate,
    });

    const populatedTask = await Task.findById(task._id).populate(
      "assignedTo",
      "name email team"
    );

    res.status(201).json({
      success: true,
      message: "Task created successfully",
      task: populatedTask,
    });
  } catch (error) {
    console.error("Create task error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to create task",
    });
  }
});


// ============================================================
// UPDATE TASK
// ============================================================

router.put("/:id", async (req, res) => {
  try {
    const task = await Task.findByIdAndUpdate(
      req.params.id,
      req.body,
      {
        new: true,
        runValidators: true,
      }
    ).populate("assignedTo", "name email team");

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Task not found",
      });
    }

    res.json({
      success: true,
      message: "Task updated successfully",
      task,
    });
  } catch (error) {
    console.error("Update task error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to update task",
    });
  }
});


// ============================================================
// DELETE TASK
// ============================================================

router.delete("/:id", async (req, res) => {
  try {
    const task = await Task.findByIdAndDelete(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Task not found",
      });
    }

    res.json({
      success: true,
      message: "Task deleted successfully",
    });
  } catch (error) {
    console.error("Delete task error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to delete task",
    });
  }
});


// ============================================================
// CURRENT TRASH ROTATION PERSON + TODAY'S TASK
// ============================================================

router.get("/rotation/trash/current", async (req, res) => {
  try {
    const current = await getCurrentTrashPerson();

    // ----------------------------------------------------------
    // IMPORTANT:
    // Calculate today's boundaries using INDIA TIME.
    // Never use server-local setHours() here.
    // ----------------------------------------------------------

    const now = new Date();

    const {
      startOfDay,
      endOfDay,
    } = getISTDayRange(now);

    const istWeekday = getISTWeekday(now);

    // Sunday = 0
    const isSunday = istWeekday === 0;

    let currentTask = await Task.findOne({
      type: "trash",
      isSundayTeamTask: false,
      dueDate: {
        $gte: startOfDay,
        $lte: endOfDay,
      },
    })
      .sort({ createdAt: -1 })
      .populate("assignedTo", "name email team");

    // ----------------------------------------------------------
    // Only create an individual Trash task Monday-Saturday.
    // Sunday Trash is handled separately.
    // ----------------------------------------------------------

    if (!currentTask && !isSunday) {
      currentTask = await processDailyTrashRotation(now);

      if (currentTask) {
        currentTask = await Task.findById(currentTask._id)
          .populate("assignedTo", "name email team");
      }
    }

    // ----------------------------------------------------------
    // Only expose an active task if it belongs to the
    // current rotation person.
    // ----------------------------------------------------------

    if (
      currentTask &&
      (
        !currentTask.assignedTo ||
        currentTask.assignedTo._id.toString() !==
          current.user._id.toString() ||
        !["pending", "active"].includes(currentTask.status)
      )
    ) {
      currentTask = null;
    }

    res.json({
      success: true,
      currentPerson: current.user,
      position: current.position,
      currentTask: currentTask,

      // Helpful for frontend debugging/date handling.
      date: {
        timezone: "Asia/Kolkata",
        startOfDay: startOfDay.toISOString(),
        endOfDay: endOfDay.toISOString(),
        isSunday,
      },
    });
  } catch (error) {
    console.error("Get current trash person error:", error);

    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});


// ============================================================
// PROCESS DAILY TRASH ROTATION
// ============================================================

router.post("/rotation/trash/process", async (req, res) => {
  try {
    const dueDate = req.body.dueDate
      ? new Date(req.body.dueDate)
      : new Date();

    if (Number.isNaN(dueDate.getTime())) {
      return res.status(400).json({
        success: false,
        message: "Invalid dueDate",
      });
    }

    const task = await processDailyTrashRotation(dueDate);

    if (!task) {
      return res.json({
        success: true,
        message: "No individual Trash task is created on Sunday",
        task: null,
      });
    }

    const populatedTask = await Task.findById(task._id).populate(
      "assignedTo",
      "name email team"
    );

    res.json({
      success: true,
      message: "Daily trash rotation processed successfully",
      task: populatedTask,
    });
  } catch (error) {
    console.error("Process trash rotation error:", error);

    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});


// ============================================================
// MARK TRASH TASK AS MISSED
// ONLY ASSIGNED USER
// ============================================================

router.post("/:id/miss", protect, async (req, res) => {
  try {
    const task = await requireTaskOwner(
      req,
      res,
      req.params.id
    );

    if (!task) {
      return;
    }

    const updatedTask = await markTrashMissed(
      req.params.id
    );

    const populatedTask = await Task.findById(
      updatedTask._id
    ).populate(
      "assignedTo",
      "name email team"
    );

    res.json({
      success: true,
      message: "Trash task marked as missed successfully",
      task: populatedTask,
    });
  } catch (error) {
    console.error("Mark task missed error:", error);

    res.status(400).json({
      success: false,
      message: error.message,
    });
  }
});


// ============================================================
// COMPLETE TRASH TASK
// ONLY ASSIGNED USER
// ============================================================

router.post("/:id/complete", protect, async (req, res) => {
  try {
    const task = await requireTaskOwner(
      req,
      res,
      req.params.id
    );

    if (!task) {
      return;
    }

    const updatedTask = await completeTrashTask(
      req.params.id,
      req.body?.proofImage || ""
    );

    const populatedTask = await Task.findById(
      updatedTask._id
    ).populate(
      "assignedTo",
      "name email team"
    );

    res.json({
      success: true,
      message: "Trash task completed successfully",
      task: populatedTask,
    });
  } catch (error) {
    console.error("Complete trash task error:", error);

    res.status(400).json({
      success: false,
      message: error.message,
    });
  }
});


// ============================================================
// CURRENT WATER ROTATION PERSON + CURRENT TASK
// ============================================================

router.get("/rotation/water/current", async (req, res) => {
  try {
    const current = await getCurrentWaterPerson();

    const currentTask = await Task.findOne({
      type: "water",
      assignedTo: current.user._id,
      status: {
        $in: ["pending", "active"],
      },
    })
      .sort({ createdAt: -1 })
      .populate("assignedTo", "name email team");

    res.json({
      success: true,
      currentPerson: current.user,
      position: current.position,
      currentTask: currentTask,
    });
  } catch (error) {
    console.error("Get current water person error:", error);

    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});


// ============================================================
// REPORT WATER EMPTY
// ============================================================

router.post("/rotation/water/report", async (req, res) => {
  try {
    const task = await reportWaterEmpty();

    const populatedTask = await Task.findById(task._id).populate(
      "assignedTo",
      "name email team"
    );

    res.status(201).json({
      success: true,
      message: "Water responsibility assigned successfully",
      task: populatedTask,
    });
  } catch (error) {
    console.error("Report water empty error:", error);

    res.status(400).json({
      success: false,
      message: error.message,
    });
  }
});


// ============================================================
// COMPLETE WATER TASK
// ONLY ASSIGNED USER
// ============================================================

router.post("/water/:id/complete", protect, async (req, res) => {
  try {
    const task = await requireTaskOwner(
      req,
      res,
      req.params.id
    );

    if (!task) {
      return;
    }

    const updatedTask = await completeWaterTask(
      req.params.id,
      req.body?.proofImage || ""
    );

    const populatedTask = await Task.findById(
      updatedTask._id
    ).populate(
      "assignedTo",
      "name email team"
    );

    res.json({
      success: true,
      message: "Water task completed successfully",
      task: populatedTask,
    });
  } catch (error) {
    console.error("Complete water task error:", error);

    res.status(400).json({
      success: false,
      message: error.message,
    });
  }
});


// ============================================================
// MARK WATER TASK AS MISSED
// ONLY ASSIGNED USER
// ============================================================

router.post("/water/:id/miss", protect, async (req, res) => {
  try {
    const task = await requireTaskOwner(
      req,
      res,
      req.params.id
    );

    if (!task) {
      return;
    }

    const updatedTask = await markWaterMissed(
      req.params.id
    );

    const populatedTask = await Task.findById(
      updatedTask._id
    ).populate(
      "assignedTo",
      "name email team"
    );

    res.json({
      success: true,
      message: "Water task marked as missed successfully",
      task: populatedTask,
    });
  } catch (error) {
    console.error("Mark water task missed error:", error);

    res.status(400).json({
      success: false,
      message: error.message,
    });
  }
});


module.exports = router;