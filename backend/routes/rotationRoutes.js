const express = require("express");
const Rotation = require("../models/Rotation");
const {
  processDailyTrashRotation,
} = require("../services/trashRotationService");

const router = express.Router();

// Get all rotations
router.get("/", async (req, res) => {
  try {
    const rotations = await Rotation.find()
      .populate("members.user", "name email team")
      .sort({ type: 1 });

    res.json({
      success: true,
      rotations,
    });
  } catch (error) {
    console.error("Get rotations error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to get rotations",
    });
  }
});

// Get one rotation by type
router.get("/:type", async (req, res) => {
  try {
    const rotation = await Rotation.findOne({
      type: req.params.type,
    }).populate("members.user", "name email team");

    if (!rotation) {
      return res.status(404).json({
        success: false,
        message: "Rotation not found",
      });
    }

    res.json({
      success: true,
      rotation,
    });
  } catch (error) {
    console.error("Get rotation error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to get rotation",
    });
  }
});

router.post("/trash/process", async (req, res) => {
  try {
    const { dueDate } = req.body;

    if (!dueDate) {
      return res.status(400).json({
        success: false,
        message: "dueDate is required",
      });
    }

    const task = await processDailyTrashRotation(dueDate);

    res.json({
      success: true,
      task,
    });
  } catch (error) {
    console.error("Process trash rotation error:", error);

    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

module.exports = router;