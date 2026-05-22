# StudyHub GitHub Migration Guide

Use `study_hub` as the repository root. Do not initialize or push from the parent
`app` directory, because it contains unrelated local files.

## Security Rules

Never commit release signing material, passwords, local SDK paths, or private
environment files.

Ignored local-only files:

- `.env`
- `.env.*`
- `android/key.properties`
- `android/app/release-keystore.jks`
- `android/local.properties`
- Build and IDE output such as `build/`, `.dart_tool/`, `.gradle/`, `.idea/`,
  `.vscode/`, and `*.log`

Tracked portable Firebase config:

- `android/app/google-services.json`
- `firestore.rules`

`google-services.json` is Android Firebase client configuration and is tracked
so another development PC can clone and build the app without recreating that
file. Do not put signing passwords or private API tokens in this file.

## Firebase Cloud Persistence

StudyHub stores authenticated user data under `users/{uid}` in Cloud Firestore.
Firebase Storage is intentionally not implemented in the current production
build, so certificate attachment files remain local-only and are not uploaded.
Deploy the included Firestore rules before production testing:

```bash
npx.cmd firebase deploy --only firestore:rules
```

Synced Firestore paths:

- `users/{uid}/studyLogs/{logId}`
- `users/{uid}/studyEvents/{eventId}`
- `users/{uid}/goals/{goalId}`
- `users/{uid}/certificates/{certificateId}`
- `users/{uid}/settings/app`
- `users/{uid}/localConfig/studySchema`
- `users/{uid}/localConfig/categories`
- `users/{uid}/localConfig/timerStats`
- `users/{uid}/syncMeta/state`

Notion API tokens remain local-only and must not be stored in Firestore.

## Manual Files Required On Each PC

After cloning on a new trusted PC, manually copy these files from secure backup:

- `android/app/release-keystore.jks`
- `android/key.properties`

Then create the local environment file from the example:

```bash
copy .env.example .env
```

Fill `.env` with local/private values. Keep `.env` untracked.

## Setup On A New PC

```bash
git clone https://github.com/vilitor/study-hub.git
cd study-hub
copy .env.example .env
flutter pub get
flutter test
flutter build apk --release
```

The release build requires the manually copied keystore and
`android/key.properties`. If either file is missing, Gradle should fail before
producing an unsigned or incorrectly signed release artifact.

## GitHub Releases App Updates

StudyHub Android updates are distributed through public GitHub Releases. The app
checks:

```text
https://api.github.com/repos/vilitor/study-hub/releases/latest
```

Release requirements:

- Use stable semantic tags only: `v1.0.0`, `v1.0.1`, `v1.1.0`.
- Do not use prerelease tags such as `v1.1.0-beta`.
- Upload a signed release APK asset. Recommended name:
  `studyhub-vX.Y.Z-release.apk`.
- Sign every future APK with the same release keystore. Android only preserves
  app data, Firebase/Auth state, Firestore cache, and local storage when the
  package name and signing certificate remain the same.

Release process:

```bash
flutter pub get
flutter test
flutter build apk --release
```

Then in GitHub:

1. Bump `pubspec.yaml` to the new version, for example `1.0.4+5`.
2. Create tag `v1.0.4`.
3. Create a normal GitHub Release for that tag.
4. Upload `build/app/outputs/flutter-apk/app-release.apk` as
   `studyhub-v1.0.4-release.apk`.
5. Publish the release.

The app will detect the new release automatically on the next startup/session or
when the user opens Settings -> Verificar atualizacoes.

Manual validation before announcing a release:

- Install the previous signed release APK.
- Confirm local data, Firebase Auth, Firestore sync cache, settings, and stored
  study history are present.
- Publish a newer GitHub Release with a higher `vX.Y.Z` tag.
- Open the app and confirm the update dialog appears without blocking startup.
- Download the update, confirm progress/cancel behavior, and install through
  the Android package installer.
- Reopen StudyHub and confirm data/Auth persistence after the upgrade.

## Firebase CLI Commands

On this Windows environment, run Firebase CLI through `npx.cmd firebase ...`.
PowerShell blocks `npx.ps1`, and bare `firebase` should not be used for this
project.

Useful validation commands:

```bash
npx.cmd firebase use --json
npx.cmd firebase firestore:databases:list --json
npx.cmd firebase firestore:indexes --json
npx.cmd firebase apps:list android --json
```

## GitHub Commands

Fresh local setup:

```bash
git init
git add .
git commit -m "Initial production setup"
git branch -M main
git remote add origin https://github.com/vilitor/study-hub.git
git push -u origin main
```

Existing checkout where `origin` already exists:

```bash
git add .
git commit -m "Initial production setup"
git branch -M main
git remote set-url origin https://github.com/vilitor/study-hub.git
git push -u origin main
```

## Pre-Push Validation

```bash
git check-ignore -v android/key.properties android/app/release-keystore.jks android/local.properties .env
git check-ignore -v android/app/google-services.json
git status --short
git diff --cached --name-only
```

The first command must show ignore rules for the sensitive local files. The
second command should print nothing, confirming Firebase config is trackable.
Before pushing, confirm these files are not staged:

- `.env`
- `android/key.properties`
- `android/app/release-keystore.jks`
- `android/local.properties`
