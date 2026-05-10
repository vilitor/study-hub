import 'dart:async';

import 'package:study_hub/models/certificate.dart';
import 'package:study_hub/services/certificate_file_service.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/services/storage_service.dart';

class CertificateRepository {
  final StorageService _storageService = StorageService();
  final CertificateFileService _fileService = CertificateFileService();
  final CloudSyncService _cloudSyncService = CloudSyncService.instance;

  Future<List<Certificate>> getCertificates() {
    return _storageService.getCertificates();
  }

  Future<void> saveCertificates(List<Certificate> certificates) {
    return _storageService.saveCertificates(certificates);
  }

  Future<void> upsertCertificate(Certificate certificate) async {
    final certificates = await getCertificates();
    final index = certificates.indexWhere((item) => item.id == certificate.id);
    if (index == -1) {
      certificates.add(certificate);
    } else {
      certificates[index] = certificate;
    }
    await saveCertificates(certificates);
    await _cloudSyncService.enqueueAchievement(certificate);
    unawaited(_cloudSyncService.flushQueue());
  }

  Future<void> deleteCertificate(Certificate certificate) async {
    final certificates = await getCertificates();
    certificates.removeWhere((item) => item.id == certificate.id);
    await saveCertificates(certificates);
    await _cloudSyncService.enqueueAchievementDelete(certificate);
    unawaited(_cloudSyncService.flushQueue());

    for (final attachment in certificate.attachments) {
      await _fileService.deleteAttachmentFile(attachment);
    }
  }
}
