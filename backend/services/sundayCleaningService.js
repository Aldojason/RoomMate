const SundayCleaning = require("../models/SundayCleaning");
const User = require("../models/User");
const Task = require("../models/Task");

// Team definitions
const TEAM_A = ["Chandru", "Deepan", "Jason"];
const TEAM_B = ["Mohan", "Tamil", "Harish"];

// Get users belonging to a team
async function getTeamMembers(team) {
    const names = team === "A" ? TEAM_A : TEAM_B;

    const users = await User.find({
        name: { $in: names },
        team,
    });

    if (users.length !== 3) {
        throw new Error(
            `Expected 3 members in Team ${team}, found ${users.length}`
        );
    }

    // Keep the exact rotation order defined above.
    const userMap = new Map(
        users.map((user) => [user.name, user])
    );

    return names.map((name) => userMap.get(name));
}

// Get the opposite team
function getOppositeTeam(team) {
    return team === "A" ? "B" : "A";
}

// Get which team should clean the house
async function getHouseTeamForSunday(sundayDate) {
    const date = new Date(sundayDate);

    // Check the most recent Sunday before this date.
    const previous = await SundayCleaning.findOne({
        sundayDate: { $lt: date },
    }).sort({ sundayDate: -1 });

    if (previous) {
        return previous.houseTeam === "A" ? "B" : "A";
    }

    // If there is no previous record, check the next
    // scheduled Sunday and work backwards from it.
    const next = await SundayCleaning.findOne({
        sundayDate: { $gt: date },
    }).sort({ sundayDate: 1 });

    if (next) {
        return next.houseTeam === "A" ? "B" : "A";
    }

    // Only use Team A when there are no Sunday records at all.
    return "A";
}

// Get the bathroom member from the opposite team
async function getBathroomMember(houseTeam, sundayDate) {
    const bathroomTeam = getOppositeTeam(houseTeam);

    const members = await getTeamMembers(bathroomTeam);

    // Find previous Sunday records where this same team
    // was responsible for the bathroom.
    const previousRecords = await SundayCleaning.find({
        sundayDate: { $lt: new Date(sundayDate) },
        houseTeam: houseTeam,
    })
        .sort({ sundayDate: -1 })
        .populate("bathroomCleaning.assignedTo");

    // Rotate through the opposite team's 3 members.
    const rotationIndex = previousRecords.length % members.length;

    return members[rotationIndex];
}

// Create this Sunday's cleaning schedule
async function createSundayCleaning(sundayDate) {
    const date = new Date(sundayDate);

    // Check if this Sunday already has a schedule
    const existing = await SundayCleaning.findOne({
        sundayDate: date,
    });

    if (existing) {
        return existing;
    }

    const houseTeam = await getHouseTeamForSunday(date);

    const bathroomMember = await getBathroomMember(
        houseTeam,
        date
    );

    const houseMembers = await getTeamMembers(houseTeam);

    const schedule = await SundayCleaning.create({
        houseTeam,

        sundayDate: date,

        houseCleaning: {
            members: houseMembers.map((user) => user._id),
            status: "pending",
            proofImage: "",
            completedAt: null,
        },

        bathroomCleaning: {
            assignedTo: bathroomMember._id,
            status: "pending",
            proofImage: "",
            completedAt: null,
        },

        sundayTrash: {
            members: houseMembers.map((user) => user._id),
            status: "pending",
            proofImage: "",
            completedAt: null,
        },
    });

    await Task.create({
        type: "trash",
        title: "Sunday Team Trash",
        assignedTeam: houseTeam,
        status: "pending",
        dueDate: date,
        isPenalty: false,
        isSundayTeamTask: true,
        extraResponsibility: false,
    });

    return schedule;
}

// Get a Sunday cleaning schedule
async function getSundayCleaning(sundayDate) {
    const schedule = await SundayCleaning.findOne({
        sundayDate: new Date(sundayDate),
    })
        .populate("houseCleaning.members", "name email team")
        .populate(
            "bathroomCleaning.assignedTo",
            "name email team"
        )
        .populate("sundayTrash.members", "name email team");

    return schedule;
}

// Complete house cleaning
async function completeHouseCleaning(
    sundayDate,
    proofImage = ""
) {
    const schedule = await SundayCleaning.findOne({
        sundayDate: new Date(sundayDate),
    });

    if (!schedule) {
        throw new Error(
            "Sunday cleaning schedule not found"
        );
    }

    if (
        schedule.houseCleaning.status === "completed"
    ) {
        throw new Error(
            "House cleaning is already completed"
        );
    }

    if (!proofImage) {
        throw new Error(
            "Proof image is required to complete house cleaning"
        );
    }

    schedule.houseCleaning.status = "completed";
    schedule.houseCleaning.proofImage = proofImage;
    schedule.houseCleaning.completedAt = new Date();

    await schedule.save();

    return schedule;
}

// Complete bathroom cleaning
async function completeBathroomCleaning(
    sundayDate,
    proofImage = ""
) {
    const schedule = await SundayCleaning.findOne({
        sundayDate: new Date(sundayDate),
    });

    if (!schedule) {
        throw new Error(
            "Sunday cleaning schedule not found"
        );
    }

    if (
        schedule.bathroomCleaning.status === "completed"
    ) {
        throw new Error(
            "Bathroom cleaning is already completed"
        );
    }

    if (!proofImage) {
        throw new Error(
            "Proof image is required to complete bathroom cleaning"
        );
    }
    schedule.bathroomCleaning.status = "completed";
    schedule.bathroomCleaning.proofImage = proofImage;
    schedule.bathroomCleaning.completedAt =
        new Date();

    await schedule.save();

    return schedule;
}

// Complete Sunday trash
async function completeSundayTrash(
    sundayDate,
    proofImage = ""
) {
    const schedule = await SundayCleaning.findOne({
        sundayDate: new Date(sundayDate),
    });

    if (!schedule) {
        throw new Error(
            "Sunday cleaning schedule not found"
        );
    }

    if (
        schedule.sundayTrash.status === "completed"
    ) {
        throw new Error(
            "Sunday trash is already completed"
        );
    }

    if (!proofImage) {
        throw new Error(
            "Proof image is required to complete Sunday trash"
        );
    }

    schedule.sundayTrash.status = "completed";
    schedule.sundayTrash.proofImage = proofImage;
    schedule.sundayTrash.completedAt = new Date();

    await schedule.save();

    await Task.findOneAndUpdate(
        {
            type: "trash",
            isSundayTeamTask: true,
            dueDate: new Date(sundayDate),
        },
        {
            status: "completed",
            proofImage: proofImage,
            completedAt: schedule.sundayTrash.completedAt,
        }
    );

    return schedule;
}

module.exports = {
    getTeamMembers,
    getOppositeTeam,
    getHouseTeamForSunday,
    getBathroomMember,
    createSundayCleaning,
    getSundayCleaning,
    completeHouseCleaning,
    completeBathroomCleaning,
    completeSundayTrash,
};