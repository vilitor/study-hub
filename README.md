# StudyHub 📓

StudyHub is a professional personal study management application built with Flutter. It helps you track your study sessions, sync logs with Notion, and schedule study events on Google Calendar.

## ✨ Features

- ⏱️ **Advanced Timer**: Track study sessions with precision.
- 📓 **Notion Integration**: Automatically sync your study logs to a Notion database.
- 🗓️ **Google Calendar Sync**: Schedule study sessions directly to your calendar with custom reminders.
- 📂 **Dynamic Categories**: Manage subjects locally or link them to a Notion `Select` property.
- 🎨 **Modern UI**: Clean, responsive design with dark/light mode support.
- 🔒 **Secure**: All API tokens and sensitive data are stored using encrypted storage.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev)
- **Language**: Dart
- **State Management**: Provider
- **Local Persistence**: Shared Preferences & Flutter Secure Storage (AES encrypted)
- **Integrations**: Notion API, Google Calendar API (OAuth 2.0)

## 🚀 Setup Instructions

### Prerequisites
- Flutter SDK (latest stable version)
- Notion Internal Integration Token
- Google Cloud Console Project (for Google Calendar)

### Configuration
1. Clone the repository.
2. Copy `.env.example` to `.env`.
3. Fill in your Notion API details and database ID.
4. For Google Calendar:
   - Configure OAuth 2.0 in Google Cloud Console.
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective platform folders.

### Running Locally
```bash
flutter pub get
flutter run
```

## 🔒 Security & LGPD Compliance

- **No Secrets in Repo**: All sensitive keys are managed via environment variables and local encrypted storage.
- **Data Protection**: Local storage uses AES encryption on Android (EncryptedSharedPreferences) and Keychain on iOS.
- **Privacy**: The app only accesses specific Notion databases and Google Calendar events authorized by the user.

## 🚀 AI TERMINAL SETUP PROMPT (COPY & PASTE)

> [!TIP]
> Copy and paste the prompt below into an AI-powered terminal agent (like Antigravity) to automatically set up the project.

```text
Act as a senior DevOps engineer. Setup this Flutter project locally. 
1. Check Flutter environment. 
2. Install all dependencies using 'flutter pub get'. 
3. Create a .env file based on .env.example. 
4. Verify the folder structure and ensure assets are linked. 
5. Run 'flutter pub run flutter_launcher_icons' to ensure icons are generated.
6. Provide a summary of the project state.
```

---

## 👨‍💻 Author
Victor - [GitHub Portfolio](https://github.com/your-username)
