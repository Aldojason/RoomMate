const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
require("dotenv").config();

const authRoutes = require("./routes/authRoutes");
const taskRoutes = require("./routes/taskRoutes");
const rotationRoutes = require("./routes/rotationRoutes");
const sundayCleaningRoutes = require("./routes/sundayCleaningRoutes");
const { processOverdueTrashTasks } = require("./services/trashRotationService");
const cron = require("node-cron");
const app = express();

// Middleware
app.use(cors());
app.use(express.json());

app.use("/api/auth", authRoutes);
app.use("/api/tasks", taskRoutes);
app.use("/api/rotations", rotationRoutes);
app.use("/api/sunday-cleaning", sundayCleaningRoutes);

// Health check
app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "RoomMate backend is running 🚀",
  });
});

// Test API
app.get("/api/test", (req, res) => {
  res.json({
    success: true,
    message: "RoomMate API is working ✅",
  });
});

// MongoDB connection
const MONGO_URI = process.env.MONGO_URI;

if (!MONGO_URI) {
  console.error("❌ MONGO_URI is not defined in .env");
  process.exit(1);
}

mongoose
  .connect(MONGO_URI)
  .then(async () => {
    console.log("MongoDB connected successfully ✅");

    // Process unfinished Trash tasks from previous days
    try {
      const processed = await processOverdueTrashTasks();
      console.log(
        `Overdue Trash tasks processed: ${processed}`
      );
    } catch (error) {
      console.error(
        "Overdue Trash processing failed:",
        error.message
      );
    }
    // Check for overdue Trash tasks every day at 12:05 AM
    cron.schedule("5 0 * * *", async () => {
      try {
        const processed = await processOverdueTrashTasks();

        console.log(
          `Daily overdue Trash check: ${processed} task(s) processed`
        );
      } catch (error) {
        console.error(
          "Daily overdue Trash check failed:",
          error.message
        );
      }
    });

    const PORT = process.env.PORT || 5000;

    app.listen(PORT, () => {
      console.log(`RoomMate server running on http://localhost:${PORT}`);
    });
  })
  .catch((error) => {
    console.error("MongoDB connection failed ❌");
    console.error(error.message);
    process.exit(1);
  });