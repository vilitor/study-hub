import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum CertificateFileType { image, pdf, other }

enum CertificateValidationStatus {
  unverified,
  metadataProvided,
  trustedProviderLink,
  formatWarning,
  manuallyVerified,
  apiVerified,
}

enum AchievementRank { bronze, silver, gold, diamond, master }

enum CertificateSortOption { newest, oldest, provider, title, category, rank }

enum CertificateSyncStatus { localOnly, pendingSync, synced, syncError }

enum CertificateSource { manual, import, provider }

class CertificateAttachment {
  final String id;
  final String originalName;
  final String localPath;
  final String mimeType;
  final CertificateFileType fileType;
  final int fileSizeBytes;
  final DateTime addedAt;

  CertificateAttachment({
    String? id,
    required this.originalName,
    required this.localPath,
    required this.mimeType,
    required this.fileType,
    required this.fileSizeBytes,
    DateTime? addedAt,
  }) : id = id ?? const Uuid().v4(),
       addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalName': originalName,
      'localPath': localPath,
      'mimeType': mimeType,
      'fileType': fileType.name,
      'fileSizeBytes': fileSizeBytes,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory CertificateAttachment.fromMap(Map<String, dynamic> map) {
    return CertificateAttachment(
      id: map['id']?.toString(),
      originalName: map['originalName']?.toString() ?? '',
      localPath: map['localPath']?.toString() ?? '',
      mimeType: map['mimeType']?.toString() ?? 'application/octet-stream',
      fileType: CertificateFileType.values.firstWhere(
        (type) => type.name == map['fileType'],
        orElse: () => CertificateFileType.other,
      ),
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      addedAt:
          DateTime.tryParse(map['addedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class CertificateValidation {
  final CertificateValidationStatus status;
  final String? providerKey;
  final String? providerName;
  final double confidence;
  final String? normalizedUrl;
  final DateTime? checkedAt;
  final List<String> messages;

  const CertificateValidation({
    required this.status,
    this.providerKey,
    this.providerName,
    this.confidence = 0,
    this.normalizedUrl,
    this.checkedAt,
    this.messages = const [],
  });

  bool get isTrusted =>
      status == CertificateValidationStatus.trustedProviderLink ||
      status == CertificateValidationStatus.manuallyVerified ||
      status == CertificateValidationStatus.apiVerified;

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'providerKey': providerKey,
      'providerName': providerName,
      'confidence': confidence,
      'normalizedUrl': normalizedUrl,
      'checkedAt': checkedAt?.toIso8601String(),
      'messages': messages,
    };
  }

  factory CertificateValidation.fromMap(Map<String, dynamic> map) {
    return CertificateValidation(
      status: CertificateValidationStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => CertificateValidationStatus.unverified,
      ),
      providerKey: map['providerKey']?.toString(),
      providerName: map['providerName']?.toString(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      normalizedUrl: map['normalizedUrl']?.toString(),
      checkedAt: DateTime.tryParse(map['checkedAt']?.toString() ?? ''),
      messages: List<String>.from(map['messages'] as List? ?? const []),
    );
  }
}

class Certificate {
  final String id;
  final String title;
  final String provider;
  final DateTime? issueDate;
  final String credentialId;
  final String validationUrl;
  final List<String> tags;
  final String notes;
  final List<CertificateAttachment> attachments;
  final CertificateValidation validation;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CertificateSyncStatus syncStatus;
  final String? remoteId;
  final DateTime? lastSyncedAt;
  final CertificateSource source;

  Certificate({
    String? id,
    required this.title,
    required this.provider,
    this.issueDate,
    this.credentialId = '',
    this.validationUrl = '',
    this.tags = const [],
    this.notes = '',
    this.attachments = const [],
    CertificateValidation? validation,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = CertificateSyncStatus.localOnly,
    this.remoteId,
    this.lastSyncedAt,
    this.source = CertificateSource.manual,
  }) : id = id ?? const Uuid().v4(),
       validation =
           validation ??
           const CertificateValidation(
             status: CertificateValidationStatus.unverified,
           ),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Certificate copyWith({
    String? title,
    String? provider,
    DateTime? issueDate,
    bool clearIssueDate = false,
    String? credentialId,
    String? validationUrl,
    List<String>? tags,
    String? notes,
    List<CertificateAttachment>? attachments,
    CertificateValidation? validation,
    DateTime? updatedAt,
    CertificateSyncStatus? syncStatus,
    String? remoteId,
    bool clearRemoteId = false,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    CertificateSource? source,
  }) {
    return Certificate(
      id: id,
      title: title ?? this.title,
      provider: provider ?? this.provider,
      issueDate: clearIssueDate ? null : issueDate ?? this.issueDate,
      credentialId: credentialId ?? this.credentialId,
      validationUrl: validationUrl ?? this.validationUrl,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
      validation: validation ?? this.validation,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      syncStatus: syncStatus ?? this.syncStatus,
      remoteId: clearRemoteId ? null : remoteId ?? this.remoteId,
      lastSyncedAt: clearLastSyncedAt
          ? null
          : lastSyncedAt ?? this.lastSyncedAt,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'provider': provider,
      'issueDate': issueDate?.toIso8601String(),
      'credentialId': credentialId,
      'validationUrl': validationUrl,
      'tags': tags,
      'notes': notes,
      'attachments': attachments
          .map((attachment) => attachment.toMap())
          .toList(),
      'validation': validation.toMap(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus.name,
      'remoteId': remoteId,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'source': source.name,
    };
  }

  factory Certificate.fromMap(Map<String, dynamic> map) {
    return Certificate(
      id: map['id']?.toString(),
      title: map['title']?.toString() ?? '',
      provider: map['provider']?.toString() ?? '',
      issueDate: DateTime.tryParse(map['issueDate']?.toString() ?? ''),
      credentialId: map['credentialId']?.toString() ?? '',
      validationUrl: map['validationUrl']?.toString() ?? '',
      tags: List<String>.from(map['tags'] as List? ?? const []),
      notes: map['notes']?.toString() ?? '',
      attachments: (map['attachments'] as List? ?? const [])
          .map(
            (attachment) => CertificateAttachment.fromMap(
              Map<String, dynamic>.from(attachment as Map),
            ),
          )
          .toList(),
      validation: map['validation'] is Map
          ? CertificateValidation.fromMap(
              Map<String, dynamic>.from(map['validation'] as Map),
            )
          : null,
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      syncStatus: CertificateSyncStatus.values.firstWhere(
        (status) => status.name == map['syncStatus'],
        orElse: () => CertificateSyncStatus.localOnly,
      ),
      remoteId: map['remoteId']?.toString(),
      lastSyncedAt: DateTime.tryParse(map['lastSyncedAt']?.toString() ?? ''),
      source: CertificateSource.values.firstWhere(
        (source) => source.name == map['source'],
        orElse: () => CertificateSource.manual,
      ),
    );
  }
}

extension CertificateValidationStatusUi on CertificateValidationStatus {
  String get label {
    return switch (this) {
      CertificateValidationStatus.unverified => 'Sem verificação',
      CertificateValidationStatus.metadataProvided => 'Dados informados',
      CertificateValidationStatus.trustedProviderLink => 'Link confiável',
      CertificateValidationStatus.formatWarning => 'Revisar dados',
      CertificateValidationStatus.manuallyVerified => 'Verificado manualmente',
      CertificateValidationStatus.apiVerified => 'Verificado',
    };
  }

  IconData get icon {
    return switch (this) {
      CertificateValidationStatus.unverified => Icons.shield_outlined,
      CertificateValidationStatus.metadataProvided => Icons.fact_check_outlined,
      CertificateValidationStatus.trustedProviderLink => Icons.verified_rounded,
      CertificateValidationStatus.formatWarning => Icons.warning_amber_rounded,
      CertificateValidationStatus.manuallyVerified => Icons.task_alt_rounded,
      CertificateValidationStatus.apiVerified => Icons.verified_user_rounded,
    };
  }
}

extension AchievementRankUi on AchievementRank {
  String get label {
    return switch (this) {
      AchievementRank.bronze => 'Bronze',
      AchievementRank.silver => 'Silver',
      AchievementRank.gold => 'Gold',
      AchievementRank.diamond => 'Diamond',
      AchievementRank.master => 'Master',
    };
  }

  IconData get icon {
    return switch (this) {
      AchievementRank.bronze => Icons.military_tech_rounded,
      AchievementRank.silver => Icons.emoji_events_outlined,
      AchievementRank.gold => Icons.emoji_events_rounded,
      AchievementRank.diamond => Icons.diamond_rounded,
      AchievementRank.master => Icons.workspace_premium_rounded,
    };
  }

  Color get accentColor {
    return switch (this) {
      AchievementRank.bronze => const Color(0xFFB87333),
      AchievementRank.silver => const Color(0xFF9AA4B2),
      AchievementRank.gold => const Color(0xFFFFB946),
      AchievementRank.diamond => const Color(0xFF4E9AF1),
      AchievementRank.master => const Color(0xFF7C6CF0),
    };
  }
}
