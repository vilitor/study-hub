import 'package:flutter/material.dart';
import 'package:study_hub/models/achievement_progress.dart';
import 'package:study_hub/models/certificate.dart';
import 'package:study_hub/repositories/certificate_repository.dart';
import 'package:study_hub/services/certificate_file_service.dart';
import 'package:study_hub/services/certificate_validation_service.dart';

class CertificateProvider extends ChangeNotifier {
  final CertificateRepository _repository = CertificateRepository();
  final CertificateValidationService _validationService =
      CertificateValidationService();
  final CertificateFileService _fileService = CertificateFileService();

  final List<Certificate> _certificates = [];
  bool _isLoading = false;
  bool _isPickingAttachment = false;
  String? _lastError;
  String _query = '';
  CertificateValidationStatus? _statusFilter;
  String? _tagFilter;
  CertificateSortOption _sortOption = CertificateSortOption.newest;

  CertificateProvider() {
    loadCertificates();
  }

  List<Certificate> get certificates => List.unmodifiable(_certificates);
  bool get isLoading => _isLoading;
  bool get isPickingAttachment => _isPickingAttachment;
  String? get lastError => _lastError;
  String get query => _query;
  CertificateValidationStatus? get statusFilter => _statusFilter;
  String? get tagFilter => _tagFilter;
  CertificateSortOption get sortOption => _sortOption;

  int get totalCertificates => _certificates.length;
  int get trustedCertificates => _certificates
      .where((certificate) => certificate.validation.isTrusted)
      .length;

  List<String> get allTags {
    final tags = _certificates.expand((certificate) => certificate.tags).toSet()
      ..removeWhere((tag) => tag.trim().isEmpty);
    return tags.toList()..sort();
  }

  List<String> get allProviders {
    final providers =
        _certificates.map((certificate) => certificate.provider).toSet()
          ..removeWhere((provider) => provider.trim().isEmpty);
    return providers.toList()..sort();
  }

  List<Certificate> get visibleCertificates {
    final normalizedQuery = _query.trim().toLowerCase();
    final visible = _certificates.where((certificate) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          certificate.title.toLowerCase().contains(normalizedQuery) ||
          certificate.provider.toLowerCase().contains(normalizedQuery) ||
          certificate.tags.any(
            (tag) => tag.toLowerCase().contains(normalizedQuery),
          );
      final matchesStatus =
          _statusFilter == null ||
          certificate.validation.status == _statusFilter ||
          (_statusFilter == CertificateValidationStatus.trustedProviderLink &&
              certificate.validation.isTrusted);
      final matchesTag =
          _tagFilter == null || certificate.tags.contains(_tagFilter);
      return matchesQuery && matchesStatus && matchesTag;
    }).toList();

    visible.sort((a, b) {
      return switch (_sortOption) {
        CertificateSortOption.newest => b.issueDateOrCreatedAt.compareTo(
          a.issueDateOrCreatedAt,
        ),
        CertificateSortOption.oldest => a.issueDateOrCreatedAt.compareTo(
          b.issueDateOrCreatedAt,
        ),
        CertificateSortOption.provider => a.provider.toLowerCase().compareTo(
          b.provider.toLowerCase(),
        ),
        CertificateSortOption.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        CertificateSortOption.category => a.primaryCategory.compareTo(
          b.primaryCategory,
        ),
        CertificateSortOption.rank => b.relevanceScore.compareTo(
          a.relevanceScore,
        ),
      };
    });

    return visible;
  }

  AchievementProgress progressFor({
    required int totalStudyMinutes,
    required int currentStreak,
    required int completedGoals,
  }) {
    return AchievementRankCalculator.calculate(
      certificateCount: totalCertificates,
      totalStudyMinutes: totalStudyMinutes,
      completedGoals: completedGoals,
      currentStreak: currentStreak,
    );
  }

  CertificateValidation previewValidation({
    required String provider,
    required String validationUrl,
    required String credentialId,
  }) {
    return _validationService.validate(
      provider: provider,
      validationUrl: validationUrl,
      credentialId: credentialId,
    );
  }

  Future<void> loadCertificates() async {
    _setLoading(true);
    try {
      _lastError = null;
      _certificates
        ..clear()
        ..addAll(await _repository.getCertificates());
      notifyListeners();
    } catch (e) {
      _lastError = 'Não foi possível carregar certificados.';
      debugPrint('[CertificateProvider] Error loading certificates: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveCertificate(Certificate certificate) async {
    try {
      _lastError = null;
      final validation = _validationService.validate(
        provider: certificate.provider,
        validationUrl: certificate.validationUrl,
        credentialId: certificate.credentialId,
      );
      final updated = certificate.copyWith(validation: validation);
      final index = _certificates.indexWhere((item) => item.id == updated.id);
      final previous = index == -1 ? null : _certificates[index];
      if (index == -1) {
        _certificates.add(updated);
      } else {
        _certificates[index] = updated;
      }
      await _repository.upsertCertificate(updated);
      await _deleteRemovedAttachments(previous, updated);
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Não foi possível salvar o certificado.';
      debugPrint('[CertificateProvider] Error saving certificate: $e');
      return false;
    }
  }

  Future<bool> deleteCertificate(Certificate certificate) async {
    try {
      _lastError = null;
      _certificates.removeWhere((item) => item.id == certificate.id);
      await _repository.deleteCertificate(certificate);
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Não foi possível excluir o certificado.';
      debugPrint('[CertificateProvider] Error deleting certificate: $e');
      return false;
    }
  }

  Future<CertificateAttachment?> pickAttachment() async {
    _isPickingAttachment = true;
    _lastError = null;
    notifyListeners();
    try {
      return await _fileService.pickAndStoreAttachment();
    } catch (e) {
      _lastError = 'Não foi possível importar o arquivo.';
      debugPrint('[CertificateProvider] Error picking attachment: $e');
      return null;
    } finally {
      _isPickingAttachment = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setStatusFilter(CertificateValidationStatus? value) {
    if (_statusFilter == value) return;
    _statusFilter = value;
    notifyListeners();
  }

  void setTagFilter(String? value) {
    if (_tagFilter == value) return;
    _tagFilter = value;
    notifyListeners();
  }

  void setSortOption(CertificateSortOption value) {
    if (_sortOption == value) return;
    _sortOption = value;
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _statusFilter = null;
    _tagFilter = null;
    _sortOption = CertificateSortOption.newest;
    notifyListeners();
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  Future<void> _deleteRemovedAttachments(
    Certificate? previous,
    Certificate updated,
  ) async {
    if (previous == null) return;
    final currentIds = updated.attachments
        .map((attachment) => attachment.id)
        .toSet();
    final removed = previous.attachments.where(
      (attachment) => !currentIds.contains(attachment.id),
    );
    for (final attachment in removed) {
      await _fileService.deleteAttachmentFile(attachment);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

extension on Certificate {
  DateTime get issueDateOrCreatedAt => issueDate ?? createdAt;

  String get primaryCategory {
    if (tags.isEmpty) return provider.toLowerCase();
    return tags.first.toLowerCase();
  }

  int get relevanceScore {
    final validationScore = validation.isTrusted
        ? 1000
        : validation.status == CertificateValidationStatus.metadataProvided
        ? 520
        : validation.status == CertificateValidationStatus.formatWarning
        ? 120
        : 240;
    final attachmentScore = attachments.isNotEmpty ? 120 : 0;
    final metadataScore =
        (credentialId.isNotEmpty ? 80 : 0) +
        (validationUrl.isNotEmpty ? 80 : 0);
    return validationScore + attachmentScore + metadataScore;
  }
}
