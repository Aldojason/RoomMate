const mongoose = require("mongoose");

const sundayCleaningSchema = new mongoose.Schema(
  {
    // Team responsible for house cleaning
    houseTeam: {
      type: String,
      enum: ["A", "B"],
      required: true,
    },

    // Sunday date
    sundayDate: {
      type: Date,
      required: true,
      unique: true,
    },

    // All 3 members of houseTeam clean the house
    houseCleaning: {
      members: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
        },
      ],

      status: {
        type: String,
        enum: ["pending", "completed"],
        default: "pending",
      },

      proofImage: {
        type: String,
        default: "",
      },

      completedAt: {
        type: Date,
        default: null,
      },
    },

    // One member from the OPPOSITE team cleans the bathroom
    bathroomCleaning: {
      assignedTo: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        default: null,
      },

      status: {
        type: String,
        enum: ["pending", "completed"],
        default: "pending",
      },

      proofImage: {
        type: String,
        default: "",
      },

      completedAt: {
        type: Date,
        default: null,
      },
    },

    // The house-cleaning team also handles Sunday trash
    sundayTrash: {
      members: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
        },
      ],

      status: {
        type: String,
        enum: ["pending", "completed"],
        default: "pending",
      },

      proofImage: {
        type: String,
        default: "",
      },

      completedAt: {
        type: Date,
        default: null,
      },
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model(
  "SundayCleaning",
  sundayCleaningSchema
);