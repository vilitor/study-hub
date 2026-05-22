import 'package:study_hub/models/app_version.dart';

class AppUpdateRelease {
  final String tagName;
  final AppVersion version;
  final String releaseNotes;
  final AppUpdateAsset apkAsset;

  const AppUpdateRelease({
    required this.tagName,
    required this.version,
    required this.releaseNotes,
    required this.apkAsset,
  });

  static AppUpdateRelease? fromGitHubJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String?;
    if (tagName == null) return null;

    final version = AppVersion.tryParse(tagName);
    if (version == null) return null;

    final assetsJson = json['assets'];
    if (assetsJson is! List) return null;

    final asset = assetsJson
        .whereType<Map<String, dynamic>>()
        .map((item) => AppUpdateAsset.tryParse(item, tagName: tagName))
        .whereType<AppUpdateAsset>()
        .firstOrNull;
    if (asset == null) return null;

    return AppUpdateRelease(
      tagName: tagName,
      version: version,
      releaseNotes: (json['body'] as String?)?.trim() ?? '',
      apkAsset: asset,
    );
  }
}

class AppUpdateAsset {
  final String name;
  final int size;
  final Uri downloadUri;
  final String? sha256;

  const AppUpdateAsset({
    required this.name,
    required this.size,
    required this.downloadUri,
    this.sha256,
  });

  static AppUpdateAsset? tryParse(
    Map<String, dynamic> json, {
    required String tagName,
  }) {
    final name = json['name'] as String?;
    final rawUrl = json['browser_download_url'] as String?;
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (name == null || uri == null) return null;
    if (!name.toLowerCase().endsWith('.apk')) return null;
    if (!_isAllowedGitHubApkUrl(uri, tagName)) return null;

    return AppUpdateAsset(
      name: name,
      size: json['size'] is int ? json['size'] as int : 0,
      downloadUri: uri,
      sha256: _parseSha256(json['digest'] as String?),
    );
  }

  static bool _isAllowedGitHubApkUrl(Uri uri, String tagName) {
    if (uri.scheme != 'https') return false;
    if (uri.host.toLowerCase() != 'github.com') return false;

    final segments = uri.pathSegments;
    if (segments.length < 6) return false;
    return segments[0] == 'vilitor' &&
        segments[1] == 'study-hub' &&
        segments[2] == 'releases' &&
        segments[3] == 'download' &&
        segments[4] == tagName &&
        segments.last.toLowerCase().endsWith('.apk');
  }

  static String? _parseSha256(String? digest) {
    if (digest == null || digest.isEmpty) return null;
    final normalized = digest.trim().toLowerCase();
    final value = normalized.startsWith('sha256:')
        ? normalized.substring('sha256:'.length)
        : normalized;
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(value) ? value : null;
  }
}

enum AppUpdateCheckOutcome { updateAvailable, upToDate, unavailable }

class AppUpdateCheckResult {
  final AppUpdateCheckOutcome outcome;
  final AppVersion currentVersion;
  final AppUpdateRelease? release;

  const AppUpdateCheckResult({
    required this.outcome,
    required this.currentVersion,
    this.release,
  });

  bool get hasUpdate => outcome == AppUpdateCheckOutcome.updateAvailable;
}
