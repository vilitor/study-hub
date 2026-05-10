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

`google-services.json` is Android Firebase client configuration and is tracked
so another development PC can clone and build the app without recreating that
file. Do not put signing passwords or private API tokens in this file.

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
