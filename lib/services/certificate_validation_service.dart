import 'package:study_hub/models/certificate.dart';

class CertificateValidationService {
  static final List<TrustedCertificateProvider> _providers = [
    TrustedCertificateProvider(
      key: 'alura',
      name: 'Alura',
      hostPatterns: const ['alura.com.br'],
      credentialPattern: RegExp(r'^[A-Za-z0-9-]{6,}$'),
    ),
    TrustedCertificateProvider(
      key: 'coursera',
      name: 'Coursera',
      hostPatterns: const ['coursera.org'],
      credentialPattern: RegExp(r'^[A-Za-z0-9]{8,}$'),
    ),
    TrustedCertificateProvider(
      key: 'udemy',
      name: 'Udemy',
      hostPatterns: const ['udemy.com'],
      credentialPattern: RegExp(r'^[A-Za-z0-9_-]{6,}$'),
    ),
    TrustedCertificateProvider(
      key: 'edx',
      name: 'edX',
      hostPatterns: const ['edx.org'],
    ),
    TrustedCertificateProvider(
      key: 'linkedin',
      name: 'LinkedIn Learning',
      hostPatterns: const ['linkedin.com', 'licdn.com'],
    ),
    TrustedCertificateProvider(
      key: 'google',
      name: 'Google',
      hostPatterns: const ['google.com', 'grow.google', 'cloud.google.com'],
    ),
    TrustedCertificateProvider(
      key: 'microsoft',
      name: 'Microsoft',
      hostPatterns: const ['microsoft.com', 'learn.microsoft.com'],
    ),
    TrustedCertificateProvider(
      key: 'aws',
      name: 'AWS',
      hostPatterns: const ['aws.amazon.com', 'credly.com'],
    ),
  ];

  CertificateValidation validate({
    required String provider,
    required String validationUrl,
    required String credentialId,
  }) {
    final messages = <String>[];
    final normalizedUrl = _normalizeUrl(validationUrl.trim());
    final normalizedProvider = provider.trim().toLowerCase();
    final normalizedCredential = credentialId.trim();

    if (normalizedUrl == null && normalizedCredential.isEmpty) {
      return const CertificateValidation(
        status: CertificateValidationStatus.unverified,
        messages: ['Adicione um link ou código para validar.'],
      );
    }

    Uri? uri;
    if (normalizedUrl != null) {
      uri = Uri.tryParse(normalizedUrl);
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          uri.host.isEmpty) {
        return CertificateValidation(
          status: CertificateValidationStatus.formatWarning,
          checkedAt: DateTime.now(),
          messages: const ['Link de validação inválido.'],
        );
      }
      if (uri.scheme != 'https') {
        messages.add('Prefira links HTTPS para validação.');
      }
    }

    final matchedProvider = _matchProvider(
      providerName: normalizedProvider,
      host: uri?.host.toLowerCase(),
    );

    if (matchedProvider != null) {
      final codeLooksValid =
          normalizedCredential.isEmpty ||
          matchedProvider.credentialPattern == null ||
          matchedProvider.credentialPattern!.hasMatch(normalizedCredential);

      if (!codeLooksValid) {
        return CertificateValidation(
          status: CertificateValidationStatus.formatWarning,
          providerKey: matchedProvider.key,
          providerName: matchedProvider.name,
          confidence: 0.44,
          normalizedUrl: normalizedUrl,
          checkedAt: DateTime.now(),
          messages: const ['O código informado não segue o padrão esperado.'],
        );
      }

      return CertificateValidation(
        status: uri != null
            ? CertificateValidationStatus.trustedProviderLink
            : CertificateValidationStatus.metadataProvided,
        providerKey: matchedProvider.key,
        providerName: matchedProvider.name,
        confidence: uri != null ? 0.86 : 0.62,
        normalizedUrl: normalizedUrl,
        checkedAt: DateTime.now(),
        messages: [
          if (uri != null) 'Link reconhecido como provedor confiável.',
          if (normalizedCredential.isNotEmpty) 'Código de credencial salvo.',
          ...messages,
        ],
      );
    }

    return CertificateValidation(
      status: CertificateValidationStatus.metadataProvided,
      confidence: normalizedUrl != null ? 0.38 : 0.24,
      normalizedUrl: normalizedUrl,
      checkedAt: DateTime.now(),
      messages: [
        if (normalizedUrl != null) 'Link salvo para conferência manual.',
        if (normalizedCredential.isNotEmpty) 'Código de credencial salvo.',
        'Provedor ainda não faz parte da lista confiável.',
        ...messages,
      ],
    );
  }

  TrustedCertificateProvider? _matchProvider({
    required String providerName,
    required String? host,
  }) {
    for (final provider in _providers) {
      final nameMatches =
          providerName.isNotEmpty &&
          (provider.name.toLowerCase().contains(providerName) ||
              providerName.contains(provider.key));
      final hostMatches =
          host != null &&
          provider.hostPatterns.any(
            (pattern) => host == pattern || host.endsWith('.$pattern'),
          );
      if (nameMatches || hostMatches) return provider;
    }
    return null;
  }

  String? _normalizeUrl(String raw) {
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.contains('.') && !raw.contains(' ')) return 'https://$raw';
    return raw;
  }
}

class TrustedCertificateProvider {
  final String key;
  final String name;
  final List<String> hostPatterns;
  final RegExp? credentialPattern;

  const TrustedCertificateProvider({
    required this.key,
    required this.name,
    required this.hostPatterns,
    this.credentialPattern,
  });
}
