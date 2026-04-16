# StudyHub 🎓

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Notion](https://img.shields.io/badge/Notion-%23000000.svg?style=for-the-badge&logo=notion&logoColor=white)](https://www.notion.so/)

StudyHub is a premium study management application built with **Flutter**. It empowers students to organize their learning schedule with seamless integration between **Google Calendar** and **Notion**.

## 🚀 Key Features

- **Dynamic Agenda**: Infinite scrollable weekly calendar with manual date selection.
- **Notion Integration**: Automatically sync study logs to a Notion database with dynamic schema detection.
- **Google Calendar Sync**: Schedule study sessions directly to your primary Google Calendar with customizable reminders.
- **Responsive Dashboard**: Real-time statistics (Study Time, Total Logs, Events) updated based on the selected date.
- **Local-First Architecture**: High-performance local persistence ensuring your data is always accessible offline.
- **Privacy Centric**: Hardware-backed encryption for sensitive tokens and a dedicated LGPD compliance overview.

## 🛠️ Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Design Pattern**: Repository Pattern (Clean Architecture principles)
- **Local Persistence**: 
  - `shared_preferences` (Settings & Cache)
  - `flutter_secure_storage` (Encrypted Tokens)
- **APIs & Integration**:
  - Google Calendar API (`googleapis`)
  - Notion API (`http`)
  - Google OAuth 2.0 (`google_sign_in`)

## 🔐 Security & Privacy (LGPD)

This project follows corporate-grade security standards:
- **Zero Secrets in Repo**: All sensitive keys are handled via environment variables and hardware-backed secure storage.
- **LGPD Compliance**: A dedicated "Data Privacy" section provides transparency on how user data is handled locally.
- **Encrypted Storage**: Notion tokens and user emails are encrypted on the device.

---

## ⚙️ Setup Instructions (Manual)

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and configured.
- A Google Cloud Project with **Google Calendar API** enabled.
- A Notion Integration token.

### 2. Environment Configuration
Create a `.env` file in the root directory based on the provided `.env.example`:
```bash
cp .env.example .env
```

### 3. Google OAuth Setup
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Configure your OAuth 2.0 Client ID for Android/iOS.
3. Add your **SHA-1 fingerprint** to the Android client.
4. Download the `google-services.json` (Android) and place it in `android/app/`.

### 4. Install Dependencies
```bash
flutter pub get
```

### 5. Run the Project
```bash
flutter run
```

---

## 📈 Future Improvements
- [ ] Support for multiple Notion database templates.
- [ ] Pomodoro Timer integration within study sessions.
- [ ] Advanced study analytics and monthly progress reports.
- [ ] Desktop support (Windows/macOS).

---

## 🚀 AI TERMINAL SETUP PROMPT (COPY & PASTE)

> [!TIP]
> Use the prompt below with any AI-powered terminal agent (like Antigravity) to set up and run this project automatically.

```text
Act as a senior DevOps engineer. I need to set up the "StudyHub" Flutter project locally. 
Please perform the following steps:
1. Detect if Flutter and Dart are installed, if not, provide instructions.
2. Run 'flutter pub get' to install all dependencies.
3. Check for the existence of a '.env' file. If missing, create one by copying '.env.example'.
4. Verify the Android project structure and notify me if 'google-services.json' is required for the full experience.
5. Compile the project and prepare it to run on the connected device/emulator.
6. Once ready, run 'flutter run' and monitor for any build errors.
```

---

## 📄 License
Project developed for professional portfolio purposes. All rights reserved.
