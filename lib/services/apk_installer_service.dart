import 'package:flutter/services.dart';

abstract class ApkInstallerService {
  Future<bool> canRequestPackageInstalls();
  Future<void> openUnknownSourcesSettings();
  Future<void> installApk(String apkPath);
}

class MethodChannelApkInstallerService implements ApkInstallerService {
  static const MethodChannel _channel = MethodChannel(
    'study_hub/update_installer',
  );

  @override
  Future<bool> canRequestPackageInstalls() async {
    final allowed = await _channel.invokeMethod<bool>(
      'canRequestPackageInstalls',
    );
    return allowed ?? false;
  }

  @override
  Future<void> openUnknownSourcesSettings() {
    return _channel.invokeMethod<void>('openUnknownSourcesSettings');
  }

  @override
  Future<void> installApk(String apkPath) {
    return _channel.invokeMethod<void>('installApk', {'apkPath': apkPath});
  }
}
