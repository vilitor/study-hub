import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/app_update.dart';
import 'package:study_hub/models/app_version.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/update_provider.dart';
import 'package:study_hub/screens/settings/settings_screen.dart';
import 'package:study_hub/services/app_update_service.dart';
import 'package:study_hub/widgets/update_available_dialog.dart';

void main() {
  group('AppVersion', () {
    test('parses stable semantic versions and ignores build numbers', () {
      expect(
        AppVersion.tryParse('v1.0.0'),
        const AppVersion(major: 1, minor: 0, patch: 0),
      );
      expect(
        AppVersion.tryParse('1.2.3+4'),
        const AppVersion(major: 1, minor: 2, patch: 3),
      );
      expect(AppVersion.tryParse('v1.2.3-beta'), isNull);
      expect(AppVersion.tryParse('1.2'), isNull);
    });

    test('compares upgrades, equal versions, and downgrades', () {
      final current = AppVersion.tryParse('1.1.0+2')!;

      expect(AppVersion.tryParse('v1.1.1')!.isNewerThan(current), isTrue);
      expect(AppVersion.tryParse('v1.1.0')!.compareTo(current), 0);
      expect(AppVersion.tryParse('v1.0.9')!.isNewerThan(current), isFalse);
    });
  });

  group('GitHub release parsing', () {
    test('selects a valid GitHub APK asset and optional digest', () {
      final release = AppUpdateRelease.fromGitHubJson({
        'tag_name': 'v1.2.0',
        'body': '- Sync improvements',
        'assets': [
          {
            'name': 'studyhub-v1.2.0-release.apk',
            'size': 1024,
            'browser_download_url':
                'https://github.com/vilitor/study-hub/releases/download/v1.2.0/studyhub-v1.2.0-release.apk',
            'digest': 'sha256:${'a' * 64}',
          },
        ],
      });

      expect(release, isNotNull);
      expect(release!.version, const AppVersion(major: 1, minor: 2, patch: 0));
      expect(release.apkAsset.sha256, 'a' * 64);
    });

    test('rejects malformed releases and unsafe APK URLs', () {
      expect(
        AppUpdateRelease.fromGitHubJson({
          'tag_name': 'v1.2.0-beta',
          'assets': const [],
        }),
        isNull,
      );
      expect(
        AppUpdateRelease.fromGitHubJson({
          'tag_name': 'v1.2.0',
          'assets': [
            {
              'name': 'studyhub.apk',
              'browser_download_url':
                  'https://example.com/vilitor/study-hub/releases/download/v1.2.0/studyhub.apk',
            },
          ],
        }),
        isNull,
      );
      expect(
        AppUpdateRelease.fromGitHubJson({
          'tag_name': 'v1.2.0',
          'assets': [
            {
              'name': 'release-notes.txt',
              'browser_download_url':
                  'https://github.com/vilitor/study-hub/releases/download/v1.2.0/release-notes.txt',
            },
          ],
        }),
        isNull,
      );
    });
  });

  group('UpdateProvider', () {
    test('reports update available and up to date states', () async {
      final release = _release('v1.2.0');
      final service = _FakeUpdateService(
        checkResult: AppUpdateCheckResult(
          outcome: AppUpdateCheckOutcome.updateAvailable,
          currentVersion: const AppVersion(major: 1, minor: 1, patch: 0),
          release: release,
        ),
      );
      final provider = UpdateProvider(service: service);

      expect(await provider.checkForUpdate(manual: true), isTrue);
      expect(provider.status, UpdateStatus.available);
      expect(provider.latestVersionLabel, '1.2.0');

      service.checkResult = const AppUpdateCheckResult(
        outcome: AppUpdateCheckOutcome.upToDate,
        currentVersion: AppVersion(major: 1, minor: 2, patch: 0),
      );
      expect(await provider.checkForUpdate(manual: true), isFalse);
      expect(provider.status, UpdateStatus.upToDate);
    });

    test('tracks download progress and cancellation failures', () async {
      final service = _FakeUpdateService(
        checkResult: AppUpdateCheckResult(
          outcome: AppUpdateCheckOutcome.updateAvailable,
          currentVersion: const AppVersion(major: 1, minor: 1, patch: 0),
          release: _release('v1.2.0'),
        ),
      );
      final provider = UpdateProvider(service: service);

      await provider.checkForUpdate(manual: true);
      expect(await provider.downloadUpdate(), isTrue);
      expect(provider.status, UpdateStatus.readyToInstall);
      expect(provider.downloadProgress, 1);

      service.throwCancelOnDownload = true;
      expect(await provider.downloadUpdate(), isFalse);
      expect(provider.status, UpdateStatus.canceled);
    });
  });

  testWidgets('Settings update tile displays installed version and status', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final provider = UpdateProvider(service: _FakeUpdateService());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Atualizações'), findsOneWidget);
    expect(find.text('Verificar atualizações'), findsOneWidget);
    expect(find.textContaining('Instalada: 1.1.0'), findsOneWidget);
  });

  testWidgets('Update dialog renders release notes and progress states', (
    tester,
  ) async {
    final service = _FakeUpdateService(
      checkResult: AppUpdateCheckResult(
        outcome: AppUpdateCheckOutcome.updateAvailable,
        currentVersion: const AppVersion(major: 1, minor: 1, patch: 0),
        release: _release('v1.2.0'),
      ),
    );
    service.downloadGate = Completer<void>();
    final provider = UpdateProvider(service: service);
    await provider.checkForUpdate(manual: true);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => UpdateAvailableDialog.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Atualização disponível'), findsOneWidget);
    expect(find.text('Sync improvements'), findsOneWidget);
    expect(find.text('Atualizar'), findsOneWidget);

    final downloadFuture = provider.downloadUpdate();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    service.downloadGate!.complete();
    await downloadFuture;
    await tester.pumpAndSettle();
  });
}

AppUpdateRelease _release(String tagName) {
  return AppUpdateRelease.fromGitHubJson({
    'tag_name': tagName,
    'body': '- Sync improvements\n- UI refinements',
    'assets': [
      {
        'name': 'studyhub-$tagName-release.apk',
        'size': 100,
        'browser_download_url':
            'https://github.com/vilitor/study-hub/releases/download/$tagName/studyhub-$tagName-release.apk',
      },
    ],
  })!;
}

class _FakeUpdateService implements AppUpdateService {
  AppUpdateCheckResult checkResult;
  bool throwCancelOnDownload = false;
  Completer<void>? downloadGate;

  _FakeUpdateService({AppUpdateCheckResult? checkResult})
    : checkResult =
          checkResult ??
          const AppUpdateCheckResult(
            outcome: AppUpdateCheckOutcome.upToDate,
            currentVersion: AppVersion(major: 1, minor: 1, patch: 0),
          );

  @override
  Future<bool> canRequestPackageInstalls() async => true;

  @override
  Future<AppUpdateCheckResult> checkForUpdate() async => checkResult;

  @override
  Future<String> downloadUpdate(
    AppUpdateRelease release, {
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    onProgress(40, 100);
    final gate = downloadGate;
    if (gate == null) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    } else {
      await gate.future;
    }
    if (throwCancelOnDownload) {
      throw DioException(
        requestOptions: RequestOptions(
          path: release.apkAsset.downloadUri.toString(),
        ),
        type: DioExceptionType.cancel,
      );
    }
    onProgress(100, 100);
    return '/tmp/studyhub.apk';
  }

  @override
  Future<InstalledAppVersion> getInstalledVersion() async {
    return const InstalledAppVersion(
      label: '1.1.0',
      semanticVersion: AppVersion(major: 1, minor: 1, patch: 0),
    );
  }

  @override
  Future<void> installApk(String apkPath) async {}

  @override
  Future<void> openUnknownSourcesSettings() async {}
}
