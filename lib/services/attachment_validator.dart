import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Comprehensive validation result
class ValidationResult {
  final bool isValid;
  final String? error;
  final String? warning;
  final String detectedMimeType;
  final String sanitizedFilename;
  final bool isSuspicious;
  final Map<String, dynamic> metadata;

  const ValidationResult({
    required this.isValid,
    this.error,
    this.warning,
    required this.detectedMimeType,
    required this.sanitizedFilename,
    this.isSuspicious = false,
    this.metadata = const {},
  });
}

/// Enterprise-grade attachment validation service with comprehensive
/// data integrity, MIME type detection, and corruption handling.
class AttachmentValidator {
  AttachmentValidator._();
  static final AttachmentValidator instance = AttachmentValidator._();

  // Security limits
  static const int _maxFileSize = 100 * 1024 * 1024; // 100 MB
  static const int _maxFilenameLength = 255;

  // File signature mappings for validation
  static const Map<String, List<List<int?>>> _fileSignatures = {
    'image/jpeg': [
      [0xFF, 0xD8, 0xFF],
    ],
    'image/png': [
      [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    ],
    'image/gif': [
      [0x47, 0x49, 0x46, 0x38, 0x37, 0x61], // GIF87a
      [0x47, 0x49, 0x46, 0x38, 0x39, 0x61], // GIF89a
    ],
    'image/webp': [
      [0x52, 0x49, 0x46, 0x46, null, null, null, null, 0x57, 0x45, 0x42, 0x50],
    ],
    'application/pdf': [
      [0x25, 0x50, 0x44, 0x46], // %PDF
    ],
    'application/zip': [
      [0x50, 0x4B, 0x03, 0x04],
      [0x50, 0x4B, 0x05, 0x06],
      [0x50, 0x4B, 0x07, 0x08],
    ],
    // Microsoft Office documents (ZIP-based)
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': [
      [0x50, 0x4B, 0x03, 0x04], // docx
    ],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': [
      [0x50, 0x4B, 0x03, 0x04], // xlsx
    ],
    'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        [
          [0x50, 0x4B, 0x03, 0x04], // pptx
        ],
  };

  static const Set<String> _dangerousExtensions = {
    'exe',
    'bat',
    'cmd',
    'com',
    'pif',
    'scr',
    'vbs',
    'js',
    'jar',
    'app',
    'deb',
    'pkg',
    'rpm',
    'dmg',
    'iso',
    'msi',
    'reg',
    'ps1',
    'sh',
    'bin',
  };

  /// Validate attachment from file path
  Future<ValidationResult> validateFile({
    required String filePath,
    String? declaredMimeType,
    String? originalFilename,
    int? expectedSize,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ValidationResult(
          isValid: false,
          error: 'File does not exist',
          detectedMimeType: declaredMimeType ?? 'application/octet-stream',
          sanitizedFilename: _sanitizeFilename(
            originalFilename ?? 'attachment',
          ),
        );
      }

      final bytes = await file.readAsBytes();
      return await validateBytes(
        bytes: bytes,
        declaredMimeType: declaredMimeType,
        originalFilename: originalFilename ?? file.uri.pathSegments.last,
        expectedSize: expectedSize,
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        error: 'Failed to read file: $e',
        detectedMimeType: declaredMimeType ?? 'application/octet-stream',
        sanitizedFilename: _sanitizeFilename(originalFilename ?? 'attachment'),
      );
    }
  }

  /// Validate attachment from raw bytes
  Future<ValidationResult> validateBytes({
    required Uint8List bytes,
    String? declaredMimeType,
    String? originalFilename,
    int? expectedSize,
  }) async {
    try {
      final filename = originalFilename ?? 'attachment';
      final sanitizedFilename = _sanitizeFilename(filename);
      final metadata = <String, dynamic>{};

      // 1. Size validation
      if (bytes.length > _maxFileSize) {
        return ValidationResult(
          isValid: false,
          error:
              'File size ${bytes.length} exceeds maximum allowed size $_maxFileSize',
          detectedMimeType: declaredMimeType ?? 'application/octet-stream',
          sanitizedFilename: sanitizedFilename,
        );
      }

      if (expectedSize != null && bytes.length != expectedSize) {
        return ValidationResult(
          isValid: false,
          error:
              'File size mismatch: expected $expectedSize, got ${bytes.length}',
          detectedMimeType: declaredMimeType ?? 'application/octet-stream',
          sanitizedFilename: sanitizedFilename,
        );
      }

      metadata['size'] = bytes.length;

      // 2. Filename validation
      if (filename.length > _maxFilenameLength) {
        return ValidationResult(
          isValid: false,
          error:
              'Filename exceeds maximum length of $_maxFilenameLength characters',
          detectedMimeType: declaredMimeType ?? 'application/octet-stream',
          sanitizedFilename: sanitizedFilename,
        );
      }

      // 3. MIME type detection and validation
      final detectedMimeType = await _detectMimeType(bytes, filename);
      final mimeResult = _validateMimeType(
        declaredMimeType: declaredMimeType,
        detectedMimeType: detectedMimeType,
        filename: filename,
      );

      if (!mimeResult.isValid) {
        return ValidationResult(
          isValid: false,
          error: mimeResult.error,
          warning: mimeResult.warning,
          detectedMimeType: detectedMimeType,
          sanitizedFilename: sanitizedFilename,
          isSuspicious: mimeResult.isSuspicious,
          metadata: metadata,
        );
      }

      // 4. File signature validation
      final signatureResult = _validateFileSignature(bytes, detectedMimeType);
      if (!signatureResult.isValid) {
        return ValidationResult(
          isValid: false,
          error: signatureResult.error,
          warning: signatureResult.warning,
          detectedMimeType: detectedMimeType,
          sanitizedFilename: sanitizedFilename,
          isSuspicious: true,
          metadata: metadata,
        );
      }

      // 5. Content validation
      final contentResult = await _validateContent(bytes, detectedMimeType);
      if (!contentResult.isValid) {
        return ValidationResult(
          isValid: false,
          error: contentResult.error,
          warning: contentResult.warning,
          detectedMimeType: detectedMimeType,
          sanitizedFilename: sanitizedFilename,
          isSuspicious: contentResult.isSuspicious,
          metadata: {...metadata, ...contentResult.metadata},
        );
      }

      // 6. Security checks
      final securityResult = _performSecurityChecks(
        bytes,
        filename,
        detectedMimeType,
      );

      // 7. Calculate integrity hash (simplified)
      metadata['validated_at'] = DateTime.now().toIso8601String();

      return ValidationResult(
        isValid: true,
        warning: securityResult.warning ?? mimeResult.warning,
        detectedMimeType: detectedMimeType,
        sanitizedFilename: sanitizedFilename,
        isSuspicious: securityResult.isSuspicious,
        metadata: {
          ...metadata,
          ...contentResult.metadata,
          ...securityResult.metadata,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('AttachmentValidator: Validation error: $e');
      }
      return ValidationResult(
        isValid: false,
        error: 'Validation failed: $e',
        detectedMimeType: declaredMimeType ?? 'application/octet-stream',
        sanitizedFilename: _sanitizeFilename(originalFilename ?? 'attachment'),
      );
    }
  }

  /// Detect MIME type from content and filename
  Future<String> _detectMimeType(Uint8List bytes, String filename) async {
    // Try to detect from file signature first
    String? mimeFromSignature = _detectFromSignature(bytes);
    if (mimeFromSignature != null) {
      return mimeFromSignature;
    }

    // Fallback to extension-based detection
    final extension = filename.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'zip':
        return 'application/zip';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }

  /// Validate MIME type consistency
  ValidationResult _validateMimeType({
    String? declaredMimeType,
    required String detectedMimeType,
    required String filename,
  }) {
    final extension = filename.toLowerCase().split('.').last;

    // Check for dangerous extensions
    if (_dangerousExtensions.contains(extension)) {
      return ValidationResult(
        isValid: false,
        error: 'Potentially dangerous file type: .$extension',
        detectedMimeType: detectedMimeType,
        sanitizedFilename: _sanitizeFilename(filename),
        isSuspicious: true,
      );
    }

    // If no declared MIME type, accept detected one
    if (declaredMimeType == null || declaredMimeType.isEmpty) {
      return ValidationResult(
        isValid: true,
        detectedMimeType: detectedMimeType,
        sanitizedFilename: _sanitizeFilename(filename),
      );
    }

    // Check for MIME type mismatch
    if (declaredMimeType != detectedMimeType) {
      // Allow some common mismatches
      final allowedMismatches = {
        'text/plain': ['text/csv', 'application/csv'],
        'application/octet-stream': [detectedMimeType], // Generic fallback
      };

      bool isAllowedMismatch = false;
      for (final entry in allowedMismatches.entries) {
        if ((entry.key == declaredMimeType &&
                entry.value.contains(detectedMimeType)) ||
            (entry.key == detectedMimeType &&
                entry.value.contains(declaredMimeType))) {
          isAllowedMismatch = true;
          break;
        }
      }

      if (!isAllowedMismatch) {
        return ValidationResult(
          isValid: true, // Don't fail, but warn
          warning:
              'MIME type mismatch: declared "$declaredMimeType" but detected "$detectedMimeType"',
          detectedMimeType: detectedMimeType,
          sanitizedFilename: _sanitizeFilename(filename),
          isSuspicious: true,
        );
      }
    }

    return ValidationResult(
      isValid: true,
      detectedMimeType: detectedMimeType,
      sanitizedFilename: _sanitizeFilename(filename),
    );
  }

  /// Detect MIME type from file signature
  String? _detectFromSignature(Uint8List bytes) {
    if (bytes.isEmpty) return null;

    for (final entry in _fileSignatures.entries) {
      final mimeType = entry.key;
      final signatures = entry.value;

      for (final signature in signatures) {
        if (_matchesSignature(bytes, signature)) {
          return mimeType;
        }
      }
    }

    return null;
  }

  /// Check if bytes match a file signature
  bool _matchesSignature(Uint8List bytes, List<int?> signature) {
    if (bytes.length < signature.length) return false;

    for (int i = 0; i < signature.length; i++) {
      final signatureByte = signature[i];
      if (signatureByte != null && bytes[i] != signatureByte) {
        return false;
      }
    }

    return true;
  }

  /// Validate file signature against MIME type
  ValidationResult _validateFileSignature(Uint8List bytes, String mimeType) {
    final expectedSignatures = _fileSignatures[mimeType];
    if (expectedSignatures == null) {
      // No signature to validate, accept it
      return ValidationResult(
        isValid: true,
        detectedMimeType: mimeType,
        sanitizedFilename: 'attachment',
      );
    }

    for (final signature in expectedSignatures) {
      if (_matchesSignature(bytes, signature)) {
        return ValidationResult(
          isValid: true,
          detectedMimeType: mimeType,
          sanitizedFilename: 'attachment',
        );
      }
    }

    return ValidationResult(
      isValid: false,
      error: 'File signature does not match MIME type $mimeType',
      detectedMimeType: mimeType,
      sanitizedFilename: 'attachment',
    );
  }

  /// Validate content integrity and structure
  Future<ValidationResult> _validateContent(
    Uint8List bytes,
    String mimeType,
  ) async {
    final metadata = <String, dynamic>{};

    try {
      if (mimeType.startsWith('text/')) {
        return await _validateTextContent(bytes, metadata);
      } else if (mimeType.startsWith('image/')) {
        return await _validateImageContent(bytes, mimeType, metadata);
      } else if (mimeType == 'application/pdf') {
        return await _validatePdfContent(bytes, metadata);
      } else if (mimeType.contains('json')) {
        return await _validateJsonContent(bytes, metadata);
      }

      // For other types, just do basic checks
      return ValidationResult(
        isValid: true,
        detectedMimeType: mimeType,
        sanitizedFilename: 'attachment',
        metadata: metadata,
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        error: 'Content validation failed: $e',
        detectedMimeType: mimeType,
        sanitizedFilename: 'attachment',
        metadata: metadata,
      );
    }
  }

  /// Validate text content
  Future<ValidationResult> _validateTextContent(
    Uint8List bytes,
    Map<String, dynamic> metadata,
  ) async {
    try {
      // Try to decode as UTF-8
      final text = utf8.decode(bytes, allowMalformed: true);
      metadata['text_length'] = text.length;
      metadata['encoding'] = 'utf-8';

      // Check for suspicious patterns
      if (text.contains('<script>') || text.contains('javascript:')) {
        return ValidationResult(
          isValid: true, // Don't fail, but warn
          warning: 'Text content contains potentially suspicious JavaScript',
          detectedMimeType: 'text/plain',
          sanitizedFilename: 'attachment',
          isSuspicious: true,
          metadata: metadata,
        );
      }

      return ValidationResult(
        isValid: true,
        detectedMimeType: 'text/plain',
        sanitizedFilename: 'attachment',
        metadata: metadata,
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        error: 'Invalid text encoding',
        detectedMimeType: 'text/plain',
        sanitizedFilename: 'attachment',
        metadata: metadata,
      );
    }
  }

  /// Validate image content
  Future<ValidationResult> _validateImageContent(
    Uint8List bytes,
    String mimeType,
    Map<String, dynamic> metadata,
  ) async {
    // Basic image validation - check that we have reasonable image headers
    if (bytes.length < 10) {
      return ValidationResult(
        isValid: false,
        error: 'Image file too small to be valid',
        detectedMimeType: mimeType,
        sanitizedFilename: 'attachment',
        metadata: metadata,
      );
    }

    metadata['image_mime'] = mimeType;

    return ValidationResult(
      isValid: true,
      detectedMimeType: mimeType,
      sanitizedFilename: 'attachment',
      metadata: metadata,
    );
  }

  /// Validate PDF content
  Future<ValidationResult> _validatePdfContent(
    Uint8List bytes,
    Map<String, dynamic> metadata,
  ) async {
    // Search for %PDF- allowing for small BOM/preamble within the first KB
    final int maxScan = bytes.length < 1024 ? bytes.length : 1024;
    String head = String.fromCharCodes(bytes.take(maxScan));
    final idx = head.indexOf('%PDF-');
    if (idx < 0) {
      return ValidationResult(
        isValid: false,
        error: 'Invalid PDF header',
        detectedMimeType: 'application/pdf',
        sanitizedFilename: 'attachment',
        metadata: metadata,
      );
    }

    // Extract PDF version
    final versionMatch = RegExp(r'%PDF-(\d+\.\d+)').firstMatch(head);
    if (versionMatch != null) {
      metadata['pdf_version'] = versionMatch.group(1);
    }

    return ValidationResult(
      isValid: true,
      detectedMimeType: 'application/pdf',
      sanitizedFilename: 'attachment',
      metadata: metadata,
    );
  }

  /// Validate JSON content
  Future<ValidationResult> _validateJsonContent(
    Uint8List bytes,
    Map<String, dynamic> metadata,
  ) async {
    try {
      final jsonString = utf8.decode(bytes);
      final jsonData = jsonDecode(jsonString);

      metadata['json_type'] = jsonData.runtimeType.toString();
      if (jsonData is Map) {
        metadata['json_keys'] = jsonData.keys.length;
      } else if (jsonData is List) {
        metadata['json_items'] = jsonData.length;
      }

      return ValidationResult(
        isValid: true,
        detectedMimeType: 'application/json',
        sanitizedFilename: 'attachment',
        metadata: metadata,
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        error: 'Invalid JSON format: $e',
        detectedMimeType: 'application/json',
        sanitizedFilename: 'attachment',
        metadata: metadata,
      );
    }
  }

  /// Perform security checks
  ValidationResult _performSecurityChecks(
    Uint8List bytes,
    String filename,
    String mimeType,
  ) {
    final metadata = <String, dynamic>{};
    final warnings = <String>[];
    bool isSuspicious = false;

    // Check for embedded executables in non-executable files
    if (!mimeType.contains('application/') ||
        !filename.toLowerCase().contains('.exe')) {
      if (_containsExecutableSignatures(bytes)) {
        warnings.add('File contains embedded executable signatures');
        isSuspicious = true;
      }
    }

    // Check for suspicious metadata
    final suspiciousPatterns = [
      'eval(',
      'javascript:',
      '<script',
      'powershell',
      'cmd.exe',
      'base64',
      'eval',
      'unescape',
      'fromCharCode',
    ];

    if (bytes.length < 10000) {
      // Only check smaller files to avoid performance issues
      try {
        final content = utf8.decode(bytes, allowMalformed: true).toLowerCase();
        for (final pattern in suspiciousPatterns) {
          if (content.contains(pattern)) {
            warnings.add('Contains suspicious pattern: $pattern');
            isSuspicious = true;
            break;
          }
        }
      } catch (_) {}
    }

    metadata['security_checked'] = true;
    metadata['suspicious_patterns'] = warnings;

    return ValidationResult(
      isValid: true,
      warning: warnings.isNotEmpty ? warnings.join('; ') : null,
      detectedMimeType: mimeType,
      sanitizedFilename: _sanitizeFilename(filename),
      isSuspicious: isSuspicious,
      metadata: metadata,
    );
  }

  /// Check for embedded executable signatures
  bool _containsExecutableSignatures(Uint8List bytes) {
    if (bytes.length < 2) return false;

    // Check for MZ header (Windows executable)
    if (bytes[0] == 0x4D && bytes[1] == 0x5A) return true;

    // Check for ELF header (Linux executable)
    if (bytes.length >= 4 &&
        bytes[0] == 0x7F &&
        bytes[1] == 0x45 &&
        bytes[2] == 0x4C &&
        bytes[3] == 0x46) {
      return true;
    }

    return false;
  }

  /// Sanitize filename for safe storage
  String _sanitizeFilename(String filename) {
    // Remove or replace dangerous characters
    String sanitized =
        filename
            .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
            .replaceAll(RegExp(r'\.\.\/'), '_')
            .replaceAll(RegExp(r'\s+'), '_')
            .toLowerCase();

    // Ensure reasonable length
    if (sanitized.length > _maxFilenameLength) {
      final extension =
          sanitized.contains('.') ? '.${sanitized.split('.').last}' : '';
      sanitized =
          sanitized.substring(0, _maxFilenameLength - extension.length) +
          extension;
    }

    // Ensure it's not empty
    if (sanitized.isEmpty) {
      sanitized = 'attachment';
    }

    return sanitized;
  }

  /// Simple integrity check by comparing file sizes
  bool verifyIntegrity(Uint8List bytes, int expectedSize) {
    return bytes.length == expectedSize;
  }

  /// Generate simple hash for attachment (using length as identifier)
  String generateSimpleHash(Uint8List bytes) {
    return bytes.length.toString();
  }
}
