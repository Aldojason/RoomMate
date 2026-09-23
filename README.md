# 🏠 RoomMate

> **Household responsibilities, made simple.**

RoomMate is a mobile application designed to help roommates manage and track shared household responsibilities such as trash disposal, water filling, house cleaning, and bathroom cleaning.

The app provides rotating responsibilities, penalty tracking, proof-based task completion, Sunday cleaning schedules, task history, and a shared household dashboard.

---

## ✨ Features

### 🔐 Authentication

- Secure login using email/username and password
- JWT-based authentication
- Persistent login session
- Role-based users: Admin and Member

### 🗑️ Trash Rotation

Trash responsibility follows a fixed household rotation:

**Jason → Harish → Chandru → Mohan → Deepan → Tamil → Repeat**

- One person is responsible for normal trash duty each day
- Completing a normal task moves the rotation to the next person
- Photo proof is required when completing a task
- Missed responsibilities automatically create penalty days

#### Penalty System

- Missing a normal trash day adds **2 penalty days**
- Missing a penalty day adds **1 additional penalty day**
- The same person continues handling trash until all penalty days are completed
- Normal rotation continues only after the penalty is cleared

Example:

```text
Monday     → Missed
Tuesday    → Penalty Day 1
Wednesday  → Penalty Day 2
Thursday   → Next person's normal turn
````

---

## 💧 Water Filling

Water filling uses an event-based rotation:

**Mohan → Chandru → Tamil → Jason → Harish → Deepan → Repeat**

* A roommate can report that the water is empty
* The current person receives the responsibility
* Photo proof is required for completion
* Completing the task moves the rotation forward
* If the responsibility is missed, the same person remains responsible for the next water task
* Duplicate active water reports are prevented

---

## 🧹 Sunday Cleaning

Sunday responsibilities alternate between the two household teams.

### Team A

* Jason
* Chandru
* Deepan

### Team B

* Harish
* Mohan
* Tamil

The Sunday system includes:

* House cleaning
* Bathroom cleaning
* Sunday trash

The house-cleaning team changes every Sunday.

Bathroom responsibility rotates between members of the opposite team.

Photo proof is required for cleaning completion.

---

## 📸 Photo Proof

Tasks can require photographic proof before completion.

Supported features include:

* Camera
* Gallery
* Image preview
* Image validation
* Image compression
* Upload progress
* Cloud storage

Proof images are stored using **Cloudinary**.

---

## 📜 Task History

RoomMate maintains a shared history of completed and missed responsibilities.

History includes:

* Trash tasks
* Water tasks
* Cleaning tasks
* Completion status
* Missed responsibilities
* Verification records
* Category filters

Pending and future tasks are not displayed in the completed/missed history.

---

## 📱 Screens

The application includes:

* Login
* Home Dashboard
* Tasks
* History

### Home

The home dashboard shows:

* Current household responsibility
* Current trash person
* Water responsibility
* Sunday cleaning information
* Bathroom responsibility
* Household status

### Tasks

The Tasks screen allows users to:

* View their responsibilities
* Complete tasks
* Upload proof
* Report water as empty
* View task status

### History

The History screen provides a shared record of completed and missed responsibilities.

---

## 🛠️ Tech Stack

### Mobile App

* Flutter
* Dart
* Material UI
* SharedPreferences
* HTTP
* Image Picker

### Backend

* Node.js
* Express.js
* MongoDB
* Mongoose
* JWT
* bcryptjs
* Cloudinary
* Multer
* node-cron

### Database

**MongoDB**

Used for:

* Users
* Tasks
* Rotations
* Penalties
* Sunday cleaning schedules
* Task history

### Image Storage

**Cloudinary**

Used for task proof images.

---

## 🏗️ Project Structure

```text
RoomMate/
│
├── android/
├── ios/
├── assets/
│   └── app_icon.png
│
├── lib/
│   ├── services/
│   │   └── api_service.dart
│   │
│   ├── main.dart
│   ├── home_screen.dart
│   ├── tasks_screen.dart
│   └── history_screen.dart
│
├── backend/
│   ├── models/
│   ├── routes/
│   ├── services/
│   ├── server.js
│   └── package.json
│
├── pubspec.yaml
├── README.md
└── .gitignore
```

---

## 🔄 Application Flow

```text
                 ┌─────────────┐
                 │    Login    │
                 └──────┬──────┘
                        │
                        ▼
              ┌──────────────────┐
              │  Home Dashboard  │
              └────────┬─────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Trash         Water       Cleaning
          │            │            │
          ▼            ▼            ▼
      Rotation      Rotation     Sunday
          │            │         Schedule
          ▼            ▼            ▼
       Complete      Complete    Complete
          │            │            │
          └────────────┼────────────┘
                       ▼
                   History
```

---

## 🔑 Authentication Flow

```text
User
 │
 ▼
Login
 │
 ▼
Backend Authentication
 │
 ▼
JWT Token
 │
 ▼
Stored Locally
 │
 ▼
Authenticated Requests
```

The mobile application stores the authentication token locally so users remain logged in when reopening the app.

---

## 🌐 Backend API

Production backend:

```text
https://roommate-bw1x.onrender.com
```

### Authentication

```text
POST /api/auth/login
```

### Tasks

```text
GET  /api/tasks

POST /api/tasks/:taskId/complete

POST /api/tasks/:taskId/miss
```

### Trash Rotation

```text
GET  /api/tasks/rotation/trash/current

POST /api/rotations/trash/process
```

### Water Rotation

```text
GET  /api/tasks/rotation/water/current

POST /api/tasks/rotation/water/report

POST /api/tasks/water/:taskId/complete

POST /api/tasks/water/:taskId/miss
```

### Sunday Cleaning

```text
GET  /api/sunday-cleaning/:sundayDate

POST /api/sunday-cleaning/create
```

---


## 🚀 Production

### Mobile

Build a release APK:

```bash
flutter build apk --release
```

Generated APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Backend

The backend is deployed using Render.

Production backend:

```text
https://roommate-bw1x.onrender.com
```

### Database

MongoDB Atlas is used for production database storage.

### Image Storage

Cloudinary is used for production image storage.

---

## 🔒 Security

RoomMate uses:

* JWT authentication
* Password hashing with bcrypt
* Protected API requests
* Environment variables for secrets
* MongoDB authentication
* Cloudinary credentials stored outside source code

Sensitive credentials should never be committed to the repository.

---

## 👥 Household Teams

### Team A

| Member  |
| ------- |
| Jason   |
| Chandru |
| Deepan  |

### Team B

| Member |
| ------ |
| Harish |
| Mohan  |
| Tamil  |

---

## 🔁 Rotation Systems

### Trash Rotation

```text
Jason
  ↓
Harish
  ↓
Chandru
  ↓
Mohan
  ↓
Deepan
  ↓
Tamil
  ↓
Jason
```

### Water Rotation

```text
Mohan
  ↓
Chandru
  ↓
Tamil
  ↓
Jason
  ↓
Harish
  ↓
Deepan
  ↓
Mohan
```

### Bathroom Rotation

Team A bathroom rotation:

```text
Chandru → Deepan → Jason → Repeat
```

Team B bathroom rotation:

```text
Mohan → Tamil → Harish → Repeat
```

---

## 🎯 Project Goal

RoomMate aims to make shared household responsibilities simple, transparent, and organized by replacing manual reminders and verbal coordination with a centralized mobile application.

---

## 📌 Current Status

RoomMate is currently functional with:

* ✅ Authentication
* ✅ Persistent login
* ✅ Trash rotation
* ✅ Trash penalty system
* ✅ Water rotation
* ✅ Sunday cleaning
* ✅ Bathroom rotation
* ✅ Sunday trash
* ✅ Photo proof
* ✅ Camera and gallery support
* ✅ Task history
* ✅ MongoDB database
* ✅ Cloudinary image storage
* ✅ Production backend
* ✅ Android release APK
* ✅ Custom application icon

---

## 👨‍💻 Author

**Aldo Jason**

Computer Science & Engineering

GitHub: [Aldojason](https://github.com/Aldojason)


