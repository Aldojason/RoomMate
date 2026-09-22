const mongoose = require("mongoose");

const rotationSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      unique: true,
    },

    type: {
      type: String,
      enum: ["trash", "water"],
      required: true,
    },

    members: [
      {
        user: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
          required: true,
        },

        position: {
          type: Number,
          required: true,
        },
      },
    ],

    // Position of the next person in the NORMAL rotation.
    // Penalties never change this position.
    currentPosition: {
      type: Number,
      default: 0,
    },

    // Number of outstanding penalty days for each roommate.
    // Example:
    // Jason misses Monday → Jason gets 2 penalty days.
    penaltyDays: [
      {
        user: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
          required: true,
        },

        days: {
          type: Number,
          default: 0,
          min: 0,
        },
      },
    ],

    extraResponsibility: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Rotation", rotationSchema);