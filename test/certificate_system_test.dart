import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_hub/models/achievement_progress.dart';
import 'package:study_hub/models/certificate.dart';
import 'package:study_hub/providers/certificate_provider.dart';
import 'package:study_hub/services/certificate_validation_service.dart';

void main() {
  test('Certificate serializes and deserializes all core fields', () {
    final certificate = Certificate(
      title: 'Flutter Avançado',
      provider: 'Alura',
      issueDate: DateTime(2026, 5, 6),
      credentialId: 'ABC-123456',
      validationUrl: 'https://www.alura.com.br/certificate/ABC-123456',
      tags: const ['Flutter', 'Mobile'],
      notes: 'Curso concluído com projeto final.',
      attachments: [
        CertificateAttachment(
          originalName: 'certificado.pdf',
          localPath: '/tmp/certificado.pdf',
          mimeType: 'application/pdf',
          fileType: CertificateFileType.pdf,
          fileSizeBytes: 2048,
        ),
      ],
      validation: const CertificateValidation(
        status: CertificateValidationStatus.trustedProviderLink,
        providerKey: 'alura',
        providerName: 'Alura',
        confidence: 0.86,
      ),
      syncStatus: CertificateSyncStatus.pendingSync,
      remoteId: 'remote-42',
      lastSyncedAt: DateTime(2026, 5, 7),
      source: CertificateSource.import,
    );

    final restored = Certificate.fromMap(certificate.toMap());

    expect(restored.title, certificate.title);
    expect(restored.provider, certificate.provider);
    expect(restored.issueDate, certificate.issueDate);
    expect(restored.tags, certificate.tags);
    expect(restored.attachments.single.fileType, CertificateFileType.pdf);
    expect(
      restored.validation.status,
      CertificateValidationStatus.trustedProviderLink,
    );
    expect(restored.syncStatus, CertificateSyncStatus.pendingSync);
    expect(restored.remoteId, 'remote-42');
    expect(restored.lastSyncedAt, DateTime(2026, 5, 7));
    expect(restored.source, CertificateSource.import);
  });

  test(
    'Certificate deserialization defaults sync metadata for old payloads',
    () {
      final restored = Certificate.fromMap({
        'id': 'legacy-cert',
        'title': 'Legacy Certificate',
        'provider': 'Udemy',
        'tags': const ['Course'],
        'attachments': const [],
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 2).toIso8601String(),
      });

      expect(restored.syncStatus, CertificateSyncStatus.localOnly);
      expect(restored.remoteId, isNull);
      expect(restored.lastSyncedAt, isNull);
      expect(restored.source, CertificateSource.manual);
    },
  );

  test('Validation service detects trusted provider URLs', () {
    final service = CertificateValidationService();

    final validation = service.validate(
      provider: 'Coursera',
      validationUrl: 'coursera.org/verify/ABCDEFGH',
      credentialId: 'ABCDEFGH',
    );

    expect(validation.status, CertificateValidationStatus.trustedProviderLink);
    expect(validation.providerKey, 'coursera');
    expect(validation.normalizedUrl, startsWith('https://'));
  });

  test('Validation service flags malformed URLs', () {
    final service = CertificateValidationService();

    final validation = service.validate(
      provider: 'Unknown',
      validationUrl: 'not a url',
      credentialId: '',
    );

    expect(validation.status, CertificateValidationStatus.formatWarning);
  });

  test('Rank calculator applies certificate and study thresholds', () {
    final silver = AchievementRankCalculator.calculate(
      certificateCount: 3,
      totalStudyMinutes: 15 * 60,
      completedGoals: 0,
      currentStreak: 0,
    );
    final master = AchievementRankCalculator.calculate(
      certificateCount: 30,
      totalStudyMinutes: 200 * 60,
      completedGoals: 2,
      currentStreak: 14,
    );

    expect(silver.currentRank, AchievementRank.silver);
    expect(master.currentRank, AchievementRank.master);
    expect(master.nextRank, isNull);
  });

  test('Certificate provider filters and sorts certificates', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = CertificateProvider();
    await provider.loadCertificates();

    await provider.saveCertificate(
      Certificate(
        title: 'Android Basics',
        provider: 'Google',
        issueDate: DateTime(2026, 1, 1),
        tags: const ['Android'],
      ),
    );
    await provider.saveCertificate(
      Certificate(
        title: 'Flutter UI',
        provider: 'Alura',
        issueDate: DateTime(2026, 2, 1),
        tags: const ['Flutter'],
      ),
    );
    await provider.saveCertificate(
      Certificate(
        title: 'Verified Cloud',
        provider: 'Coursera',
        issueDate: DateTime(2026, 3, 1),
        credentialId: 'ABCDEFGH',
        validationUrl: 'https://coursera.org/verify/ABCDEFGH',
        tags: const ['Cloud'],
      ),
    );

    provider.setQuery('flutter');
    expect(provider.visibleCertificates, hasLength(1));
    expect(provider.visibleCertificates.single.provider, 'Alura');

    provider.setQuery('');
    provider.setSortOption(CertificateSortOption.provider);
    expect(provider.visibleCertificates.first.provider, 'Alura');

    provider.setSortOption(CertificateSortOption.category);
    expect(provider.visibleCertificates.first.tags.single, 'Android');

    provider.setSortOption(CertificateSortOption.rank);
    expect(provider.visibleCertificates.first.title, 'Verified Cloud');
  });
}
