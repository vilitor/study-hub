import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:study_hub/models/app_update.dart';
import 'package:study_hub/models/app_version.dart';
import 'package:study_hub/services/apk_installer_service.dart';

class InstalledAppVersion {
  final String label;
  final AppVersion? semanticVersion;

  const InstalledAppVersion({
    required this.label,
    required this.semanticVersion,
  });
}

abstract class AppUpdateService {
  Future<InstalledAppVersion> getInstalledVersion();

  Future<AppUpdateCheckResult> checkForUpdate();

  Future<String> downloadUpdate(
    AppUpdateRelease release, {
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
  });

  Future<bool> canRequestPackageInstalls();

  Future<void> openUnknownSourcesSettings();

  Future<void> installApk(String apkPath);
}

class GitHubAppUpdateService implements AppUpdateService {
  static final Uri latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/vilitor/study-hub/releases/latest',
  );

  final Dio _dio;
  final ApkInstallerService _installer;

  GitHubAppUpdateService({Dio? dio, ApkInstallerService? installer})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              sendTimeout: const Duration(seconds: 8),
              headers: const {
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
                'User-Agent': 'StudyHub-Android-Updater',
              },
            ),
          ),
      _installer = installer ?? MethodChannelApkInstallerService();

  @override
  Future<InstalledAppVersion> getInstalledVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return InstalledAppVersion(
      label: packageInfo.version,
      semanticVersion: AppVersion.tryParse(packageInfo.version),
    );
  }

  @override
  Future<AppUpdateCheckResult> checkForUpdate() async {
    final installed = await getInstalledVersion();
    final currentVersion = installed.semanticVersion;
    if (currentVersion == null) {
      return AppUpdateCheckResult(
        outcome: AppUpdateCheckOutcome.unavailable,
        currentVersion: const AppVersion(major: 0, minor: 0, patch: 0),
      );
    }

    final response = await _dio.get<Map<String, dynamic>>(
      latestReleaseUri.toString(),
    );
    final json = response.data;
    if (json == null) {
      return AppUpdateCheckResult(
        outcome: AppUpdateCheckOutcome.unavailable,
        currentVersion: currentVersion,
      );
    }

    final release = AppUpdateRelease.fromGitHubJson(json);
    if (release == null) {
      return AppUpdateCheckResult(
        outcome: AppUpdateCheckOutcome.unavailable,
        currentVersion: currentVersion,
      );
    }

    return AppUpdateCheckResult(
      outcome: release.version.isNewerThan(currentVersion)
          ? AppUpdateCheckOutcome.updateAvailable
          : AppUpdateCheckOutcome.upToDate,
      currentVersion: currentVersion,
      release: release.version.isNewerThan(currentVersion) ? release : null,
    );
  }

  @override
  Future<String> downloadUpdate(
    AppUpdateRelease release, {
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    final updateDir = await _updateDirectory();
    await _deleteOldApks(updateDir);

    final fileName = _safeApkName(release.apkAsset.name, release.tagName);
    final file = File(p.join(updateDir.path, fileName));
    if (await file.exists()) {
      await file.delete();
    }

    await _dio.download(
      release.apkAsset.downloadUri.toString(),
      file.path,
      cancelToken: cancelToken,
      deleteOnError: true,
      options: Options(
        followRedirects: true,
        responseType: ResponseType.bytes,
        headers: const {'User-Agent': 'StudyHub-Android-Updater'},
      ),
      onReceiveProgress: onProgress,
    );

    if (release.apkAsset.size > 0 &&
        await file.length() != release.apkAsset.size) {
      await _deleteIfExists(file);
      throw const AppUpdateException('download_incomplete');
    }

    final expectedSha256 = release.apkAsset.sha256;
    if (expectedSha256 != null) {
      final actualSha256 = await _sha256(file);
      if (actualSha256 != expectedSha256) {
        await _deleteIfExists(file);
        throw const AppUpdateException('checksum_mismatch');
      }
    }

    return file.path;
  }

  @override
  Future<bool> canRequestPackageInstalls() {
    return _installer.canRequestPackageInstalls();
  }

  @override
  Future<void> openUnknownSourcesSettings() {
    return _installer.openUnknownSourcesSettings();
  }

  @override
  Future<void> installApk(String apkPath) {
    return _installer.installApk(apkPath);
  }

  Future<Directory> _updateDirectory() async {
    final cacheDir = await getTemporaryDirectory();
    final updateDir = Directory(p.join(cacheDir.path, 'updates'));
    if (!await updateDir.exists()) {
      await updateDir.create(recursive: true);
    }
    return updateDir;
  }

  Future<void> _deleteOldApks(Directory updateDir) async {
    if (!await updateDir.exists()) return;
    await for (final entity in updateDir.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
        await _deleteIfExists(entity);
      }
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _safeApkName(String assetName, String tagName) {
    final cleaned = assetName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (cleaned.toLowerCase().endsWith('.apk')) return cleaned;
    return 'studyhub-$tagName-release.apk';
  }

  Future<String> _sha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}

class AppUpdateException implements Exception {
  final String code;

  const AppUpdateException(this.code);

  @override
  String toString() => 'AppUpdateException($code)';
}
