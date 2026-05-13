import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:study_hub/models/certificate.dart';
import 'package:uuid/uuid.dart';

class CertificateFileService {
  Future<CertificateAttachment?> pickAndStoreAttachment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final sourcePath = picked.path;
    if (sourcePath == null) return null;

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return null;

    final directory = await _certificateDirectory();
    final extension = p.extension(picked.name);
    final storedName = '${const Uuid().v4()}$extension';
    final destination = File(p.join(directory.path, storedName));
    final copied = await sourceFile.copy(destination.path);
    final fileSize = await copied.length();

    return CertificateAttachment(
      originalName: picked.name,
      localPath: copied.path,
      mimeType: _mimeTypeFor(extension),
      fileType: _fileTypeFor(extension),
      fileSizeBytes: fileSize,
    );
  }

  Future<void> deleteAttachmentFile(CertificateAttachment attachment) async {
    final file = File(attachment.localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> attachmentFileExists(CertificateAttachment attachment) async {
    if (attachment.localPath.isEmpty) return false;
    return File(attachment.localPath).exists();
  }

  Future<File> createRestoredAttachmentFile(
    CertificateAttachment attachment,
  ) async {
    final directory = await _certificateDirectory();
    final extension = p.extension(attachment.originalName).isNotEmpty
        ? p.extension(attachment.originalName)
        : _extensionForMimeType(attachment.mimeType);
    final destination = File(
      p.join(directory.path, '${attachment.id}$extension'),
    );
    if (!await destination.parent.exists()) {
      await destination.parent.create(recursive: true);
    }
    return destination;
  }

  Future<Directory> _certificateDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, 'certificates'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  CertificateFileType _fileTypeFor(String extension) {
    final lower = extension.toLowerCase();
    if (lower == '.pdf') return CertificateFileType.pdf;
    if (['.png', '.jpg', '.jpeg', '.webp'].contains(lower)) {
      return CertificateFileType.image;
    }
    return CertificateFileType.other;
  }

  String _mimeTypeFor(String extension) {
    return switch (extension.toLowerCase()) {
      '.pdf' => 'application/pdf',
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }

  String _extensionForMimeType(String mimeType) {
    return switch (mimeType.toLowerCase()) {
      'application/pdf' => '.pdf',
      'image/png' => '.png',
      'image/jpeg' => '.jpg',
      'image/webp' => '.webp',
      _ => '',
    };
  }
}
