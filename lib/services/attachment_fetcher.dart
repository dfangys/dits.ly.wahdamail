import 'dart:typed_data';
import 'dart:convert';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:wahda_bank/services/mail_service.dart';

/// Enterprise-grade attachment fetcher with proper enough_mail decoding.
///
/// Implements comprehensive decoding strategy:
/// 1) Try local MIME part with proper content-transfer-encoding handling
/// 2) Fallback to server fetch with automatic mailbox selection
/// 3) Validate data integrity and handle edge cases
/// 4) Support all standard encodings (base64, quoted-printable, etc.)
class AttachmentFetcher {
  static const int _maxRetries = 3;
  static const Duration _defaultTimeout = Duration(seconds: 15);
  
  /// Fetch bytes for a ContentInfo using its fetchId with comprehensive validation.
  static Future<Uint8List?> fetchBytes({
    required MimeMessage message,
    required ContentInfo content,
    Mailbox? mailbox,
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      if (kDebugMode) {
        print('AttachmentFetcher: fetching ${content.fetchId} (${content.fileName ?? "unnamed"}) size: ${content.size ?? "unknown"} mime: ${content.contentType?.mediaType}');
      }
      
      // 1) Try local part with enhanced decoding
      final localData = await _fetchFromLocalPart(message, content);
      if (localData != null && localData.isNotEmpty) {
        if (_validateAttachmentData(localData, content)) {
          if (kDebugMode) {
            print('AttachmentFetcher: local fetch successful (${localData.length} bytes)');
          }
          return localData;
        }
      }

      // 2) Fallback: fetch from server with retry logic
      final serverData = await _fetchFromServer(message, content, mailbox, timeout);
      if (serverData != null && serverData.isNotEmpty) {
        if (_validateAttachmentData(serverData, content)) {
          if (kDebugMode) {
            print('AttachmentFetcher: server fetch successful (${serverData.length} bytes)');
          }
          return serverData;
        }
      }

      if (kDebugMode) {
        print('AttachmentFetcher: failed to fetch valid data for ${content.fetchId}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('AttachmentFetcher error for ${content.fetchId}: $e');
      }
      return null;
    }
  }
  
  /// Enhanced local part fetching with proper encoding handling
  static Future<Uint8List?> _fetchFromLocalPart(MimeMessage message, ContentInfo content) async {
    try {
      final part = message.getPart(content.fetchId);
      if (part == null) return null;
      
      // Get encoding and handle properly
      final encoding = part.getHeaderValue('content-transfer-encoding')?.toLowerCase().trim();
      
      if (kDebugMode) {
        print('AttachmentFetcher: local part encoding: $encoding');
      }
      
      // Try modern approach first
      if (part.mimeData != null) {
        final data = part.mimeData!.decodeBinary(encoding);
        if (data != null && data.isNotEmpty) {
          return data;
        }
      }
      
      // Fallback to legacy method
      final legacyData = part.decodeContentBinary();
      if (legacyData != null && legacyData.isNotEmpty) {
        return legacyData;
      }
      
      // Handle text data that might need encoding conversion
      final textData = part.decodeContentText();
      if (textData != null && textData.isNotEmpty) {
        // Check if it's base64 encoded text
        if (_looksLikeBase64(textData)) {
          try {
            return Uint8List.fromList(base64.decode(textData.replaceAll(RegExp(r'\s'), '')));
          } catch (_) {
            // If base64 decode fails, return as UTF-8 bytes
            return Uint8List.fromList(utf8.encode(textData));
          }
        }
        return Uint8List.fromList(utf8.encode(textData));
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('AttachmentFetcher: local part error: $e');
      }
      return null;
    }
  }
  
  /// Server fetching with enhanced error handling and retry logic
  static Future<Uint8List?> _fetchFromServer(
    MimeMessage message, 
    ContentInfo content, 
    Mailbox? mailbox, 
    Duration timeout
  ) async {
    final mail = MailService.instance;
    int retryCount = 0;
    
    while (retryCount < _maxRetries) {
      try {
        // Ensure connection
        if (!mail.client.isConnected) {
          await mail.connect().timeout(const Duration(seconds: 10));
        }
        
        // Ensure correct mailbox selection
        if (mailbox != null) {
          final selected = mail.client.selectedMailbox;
          if (selected?.encodedPath != mailbox.encodedPath && selected?.path != mailbox.path) {
            await mail.client.selectMailbox(mailbox).timeout(const Duration(seconds: 8));
          }
        }
        
        // Fetch the part
        final fetched = await mail.client
            .fetchMessagePart(message, content.fetchId)
            .timeout(timeout);
            
        if (fetched.mimeData != null) {
          final encoding = fetched.getHeaderValue('content-transfer-encoding')?.toLowerCase().trim();
          final data = fetched.mimeData!.decodeBinary(encoding);
          if (data != null && data.isNotEmpty) {
            return data;
          }
        }
        
        // Try text decoding as fallback
        final textData = fetched.decodeContentText();
        if (textData != null && textData.isNotEmpty) {
          if (_looksLikeBase64(textData)) {
            try {
              return Uint8List.fromList(base64.decode(textData.replaceAll(RegExp(r'\s'), '')));
            } catch (_) {}
          }
          return Uint8List.fromList(utf8.encode(textData));
        }
        
        return null;
      } catch (e) {
        retryCount++;
        if (kDebugMode) {
          print('AttachmentFetcher: server fetch attempt $retryCount failed: $e');
        }
        
        if (retryCount >= _maxRetries) {
          if (kDebugMode) {
            print('AttachmentFetcher: server fetch failed after $retryCount attempts');
          }
          return null;
        }
        
        // Wait before retry with exponential backoff
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    
    return null;
  }
  
  /// Validate attachment data integrity
  static bool _validateAttachmentData(Uint8List data, ContentInfo content) {
    if (data.isEmpty) return false;
    
    // Check if declared size matches (if available)
    final declaredSize = content.size;
    if (declaredSize != null && declaredSize > 0) {
      final sizeDiff = (data.length - declaredSize).abs();
      // Allow some tolerance for encoding differences
      if (sizeDiff > declaredSize * 0.1 && sizeDiff > 1024) {
        if (kDebugMode) {
          print('AttachmentFetcher: size mismatch - expected: $declaredSize, actual: ${data.length}');
        }
        // Don't reject, just warn - some encodings can cause size differences
      }
    }
    
    // Basic content validation based on MIME type
    final mimeType = content.contentType?.mediaType.toString().toLowerCase();
    if (mimeType != null) {
      if (!_validateContentByMimeType(data, mimeType)) {
        if (kDebugMode) {
          print('AttachmentFetcher: content validation failed for MIME type: $mimeType');
        }
        return false;
      }
    }
    
    return true;
  }
  
  /// Validate content based on MIME type signatures
  static bool _validateContentByMimeType(Uint8List data, String mimeType) {
    if (data.length < 4) return true; // Too small to validate, assume valid
    
    switch (mimeType) {
      case 'application/pdf':
        return data[0] == 0x25 && data[1] == 0x50 && data[2] == 0x44 && data[3] == 0x46; // %PDF
      case 'image/jpeg':
        return data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF;
      case 'image/png':
        return data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47;
      case 'image/gif':
        return (data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46) &&
               (data[3] == 0x38 && (data[4] == 0x37 || data[4] == 0x39));
      case 'application/zip':
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return data[0] == 0x50 && data[1] == 0x4B; // PK (ZIP signature)
      default:
        return true; // Don't validate unknown types
    }
  }
  
  /// Check if string looks like base64
  static bool _looksLikeBase64(String s) {
    if (s.length < 4) return false;
    final cleaned = s.replaceAll(RegExp(r'\s'), '');
    if (cleaned.length % 4 != 0) return false;
    return RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(cleaned);
  }

  /// Fetch bytes when only a fetchId is available.
  static Future<Uint8List?> fetchByFetchId({
    required MimeMessage message,
    required String fetchId,
    Mailbox? mailbox,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      // 1) Try local part on the current message
      final part = message.getPart(fetchId);
      if (part != null) {
        final enc = part.getHeaderValue('content-transfer-encoding');
        final data = part.mimeData?.decodeBinary(enc) ?? part.decodeContentBinary();
        if (data != null && data.isNotEmpty) return data;
      }

      // 2) Fallback: fetch the part from the server
      final mail = MailService.instance;
      try {
        if (!mail.client.isConnected) {
          await mail.connect().timeout(const Duration(seconds: 8));
        }
        if (mailbox != null) {
          final selected = mail.client.selectedMailbox;
          if (selected?.encodedPath != mailbox.encodedPath && selected?.path != mailbox.path) {
            try { await mail.client.selectMailbox(mailbox).timeout(const Duration(seconds: 8)); } catch (_) {}
          }
        }
        final fetched = await mail.client
            .fetchMessagePart(message, fetchId)
            .timeout(timeout);
        final enc = fetched.getHeaderValue('content-transfer-encoding');
        final data = fetched.mimeData?.decodeBinary(enc);
        if (data != null && data.isNotEmpty) return data;
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('AttachmentFetcher: network fetch failed for $fetchId: $e');
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AttachmentFetcher error (by id): $e');
      }
      return null;
    }
  }
}

