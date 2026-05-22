import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:study_hub/models/app_update.dart';
import 'package:study_hub/services/app_update_service.dart';

enum UpdateStatus {
  idle,
  checking,
  available,
  upToDate,
  downloading,
  readyToInstall,
  canceled,
  failed,
}

class UpdateProvider extends ChangeNotifier {
  final AppUpdateService _service;

  UpdateStatus _status = UpdateStatus.idle;
  String _installedVersionLabel = '...';
  AppUpdateRelease? _availableRelease;
  DateTime? _lastCheckedAt;
  String? _errorMessage;
  String? _downloadedApkPath;
  double _downloadProgress = 0;
  CancelToken? _cancelToken;
  bool _checkedThisSession = false;
  bool _dismissedThisSession = false;

  UpdateProvider({AppUpdateService? service})
    : _service = service ?? GitHubAppUpdateService() {
    unawaited(loadInstalledVersion());
  }

  UpdateStatus get status => _status;
  String get installedVersionLabel => _installedVersionLabel;
  AppUpdateRelease? get availableRelease => _availableRelease;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  String? get errorMessage => _errorMessage;
  String? get downloadedApkPath => _downloadedApkPath;
  double get downloadProgress => _downloadProgress.clamp(0, 1);
  bool get isChecking => _status == UpdateStatus.checking;
  bool get isDownloading => _status == UpdateStatus.downloading;
  bool get hasUpdate => _availableRelease != null;
  bool get shouldPromptForAvailableUpdate =>
      _availableRelease != null && !_dismissedThisSession;

  String get latestVersionLabel => _availableRelease?.version.toString() ?? '-';

  String get statusLabel {
    return switch (_status) {
      UpdateStatus.checking => 'Verificando atualizações...',
      UpdateStatus.available => 'Versao $latestVersionLabel disponivel',
      UpdateStatus.upToDate => 'Você está na versão mais recente',
      UpdateStatus.downloading =>
        'Baixando ${(downloadProgress * 100).round()}%',
      UpdateStatus.readyToInstall => 'Download concluido',
      UpdateStatus.canceled => 'Download cancelado',
      UpdateStatus.failed => _errorMessage ?? 'Não foi possível atualizar',
      UpdateStatus.idle => 'Toque para verificar atualizações',
    };
  }

  Future<void> loadInstalledVersion() async {
    try {
      final installed = await _service.getInstalledVersion();
      _installedVersionLabel = installed.label;
      notifyListeners();
    } catch (error) {
      debugPrint('Unable to load app version: $error');
    }
  }

  Future<bool> checkForUpdate({required bool manual}) async {
    if (!manual && _checkedThisSession) return hasUpdate;
    if (_status == UpdateStatus.checking ||
        _status == UpdateStatus.downloading) {
      return hasUpdate;
    }

    _setState(
      status: UpdateStatus.checking,
      errorMessage: null,
      downloadProgress: 0,
    );

    try {
      final result = await _service.checkForUpdate();
      _checkedThisSession = true;
      _lastCheckedAt = DateTime.now();
      _installedVersionLabel = result.currentVersion.toString();
      _availableRelease = result.release;
      _downloadedApkPath = null;
      _downloadProgress = 0;
      _errorMessage = null;
      _status = result.hasUpdate
          ? UpdateStatus.available
          : UpdateStatus.upToDate;
      notifyListeners();
      return result.hasUpdate;
    } catch (error) {
      _checkedThisSession = true;
      _lastCheckedAt = DateTime.now();
      if (manual) {
        _setState(
          status: UpdateStatus.failed,
          errorMessage: 'Não foi possível verificar atualizações.',
        );
      } else {
        debugPrint('Silent update check failed: $error');
        _setState(status: UpdateStatus.idle, errorMessage: null);
      }
      return false;
    }
  }

  Future<bool> downloadUpdate() async {
    final release = _availableRelease;
    if (release == null) {
      _setState(
        status: UpdateStatus.failed,
        errorMessage: 'Nenhuma atualização disponível.',
      );
      return false;
    }

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    _setState(
      status: UpdateStatus.downloading,
      errorMessage: null,
      downloadProgress: 0,
    );

    try {
      final path = await _service.downloadUpdate(
        release,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (total <= 0) return;
          _downloadProgress = received / total;
          notifyListeners();
        },
      );
      _downloadedApkPath = path;
      _cancelToken = null;
      _setState(status: UpdateStatus.readyToInstall, downloadProgress: 1);
      return true;
    } on DioException catch (error) {
      _cancelToken = null;
      if (error.type == DioExceptionType.cancel) {
        _setState(
          status: UpdateStatus.canceled,
          errorMessage: 'Download cancelado.',
        );
      } else {
        _setState(
          status: UpdateStatus.failed,
          errorMessage: 'Falha ao baixar a atualização.',
        );
      }
      return false;
    } catch (_) {
      _cancelToken = null;
      _setState(
        status: UpdateStatus.failed,
        errorMessage: 'Falha ao baixar a atualização.',
      );
      return false;
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel('user_cancelled');
    _cancelToken = null;
  }

  Future<bool> installDownloadedUpdate() async {
    final apkPath = _downloadedApkPath;
    if (apkPath == null) {
      _setState(
        status: UpdateStatus.failed,
        errorMessage: 'APK da atualização não encontrado.',
      );
      return false;
    }

    try {
      final canInstall = await _service.canRequestPackageInstalls();
      if (!canInstall) {
        await _service.openUnknownSourcesSettings();
        _setState(
          status: UpdateStatus.readyToInstall,
          errorMessage:
              'Permita instalacoes do StudyHub e toque em Atualizar novamente.',
        );
        return false;
      }
      await _service.installApk(apkPath);
      return true;
    } catch (_) {
      _setState(
        status: UpdateStatus.failed,
        errorMessage: 'Não foi possível abrir o instalador Android.',
      );
      return false;
    }
  }

  void dismissAvailableUpdateForSession() {
    _dismissedThisSession = true;
    notifyListeners();
  }

  void _setState({
    required UpdateStatus status,
    String? errorMessage,
    double? downloadProgress,
  }) {
    _status = status;
    _errorMessage = errorMessage;
    if (downloadProgress != null) {
      _downloadProgress = downloadProgress;
    }
    notifyListeners();
  }
}
