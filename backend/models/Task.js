const mongoose = require("mongoose");

const taskSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ["trash", "water", "house", "bathroom"],
      required: true,
    },

    title: {
      type: String,
      required: true,
      trim: true,
    },

    // The person responsible for the normal task
    assignedTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    // Used for Sunday team cleaning
    assignedTeam: {
      type: String,
      enum: ["A", "B", null],
      default: null,
    },

    status: {
      type: String,
      enum: ["pending", "active", "completed", "missed"],
      default: "pending",
    },

    dueDate: {
      type: Date,
      required: true,
    },

    completedAt: {
      type: Date,
      default: null,
    },

    // Photo proof URL
    proofImage: {
      type: String,
      default: "",
    },

    // True when this task is an extra responsibility
    // created because the person missed a previous duty
    isPenalty: {
      type: Boolean,
      default: false,
    },

    // The original task that caused this penalty
    penaltyForTask: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Task",
      default: null,
    },

    // Whether this is the Sunday team trash responsibility
    isSundayTeamTask: {
      type: Boolean,
      default: false,
    },

    // Used for water tasks when someone has an additional responsibility
    extraResponsibility: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Task", taskSchema);