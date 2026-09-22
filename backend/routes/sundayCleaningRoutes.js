const express = require("express");

const {
  createSundayCleaning,
  getSundayCleaning,
  completeHouseCleaning,
  completeBathroomCleaning,
  completeSundayTrash,
} = require("../services/sundayCleaningService");

const router = express.Router();

// Create a Sunday cleaning schedule
router.post("/create", async (req, res) => {
  try {
    if (!req.body.sundayDate) {
      return res.status(400).json({
        success: false,
        message: "sundayDate is required",
      });
    }

    const schedule = await createSundayCleaning(
      req.body.sundayDate
    );

    res.status(201).json({
      success: true,
      message: "Sunday cleaning schedule created successfully",
      schedule,
    });
  } catch (error) {
    console.error(
      "Create Sunday cleaning error:",
      error
    );

    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

// Get Sunday cleaning schedule
router.get("/:sundayDate", async (req, res) => {
  try {
    const schedule = await getSundayCleaning(
      req.params.sundayDate
    );

    if (!schedule) {
      return res.status(404).json({
        success: false,
        message: "Sunday cleaning schedule not found",
      });
    }

    res.json({
      success: true,
      schedule,
    });
  } catch (error) {
    console.error(
      "Get Sunday cleaning error:",
      error
    );

    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

// Complete house cleaning
router.post("/:sundayDate/house/complete", async (req, res) => {
  try {
    const schedule = await completeHouseCleaning(
      req.params.sundayDate,
      req.body.proofImage || ""
    );

    res.json({
      success: true,
      message: "House cleaning completed successfully",
      schedule,
    });
  } catch (error) {
    console.error(
      "Complete house cleaning error:",
      error
    );

    res.status(400).json({
      success: false,
      message: error.message,
    });
  }
});

// Complete bathroom cleaning
router.post(
  "/:sundayDate/bathroom/complete",
  async (req, res) => {
    try {
      const schedule = await completeBathroomCleaning(
        req.params.sundayDate,
        req.body.proofImage || ""
      );

      res.json({
        success: true,
        message:
          "Bathroom cleaning completed successfully",
        schedule,
      });
    } catch (error) {
      console.error(
        "Complete bathroom cleaning error:",
        error
      );

      res.status(400).json({
        success: false,
        message: error.message,
      });
    }
  }
);

// Complete Sunday trash
router.post(
  "/:sundayDate/trash/complete",
  async (req, res) => {
    try {
      const schedule = await completeSundayTrash(
        req.params.sundayDate,
        req.body.proofImage || ""
      );

      res.json({
        success: true,
        message:
          "Sunday trash completed successfully",
        schedule,
      });
    } catch (error) {
      console.error(
        "Complete Sunday trash error:",
        error
      );

      res.status(400).json({
        success: false,
        message: error.message,
      });
    }
  }
);

module.exports = router;