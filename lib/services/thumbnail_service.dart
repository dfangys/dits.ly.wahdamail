import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart' as z;

/// Enterprise-grade thumbnail service with comprehensive file type support,
/// intelligent caching, and performance optimization.
class ThumbnailService {
  ThumbnailService._();
  static final ThumbnailService instance = ThumbnailService._();
  
  // Cache management
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB cache limit
  static const int _maxCacheEntries = 1000;
  static const Duration _cacheValidityDuration = Duration(days: 7);
  
  // Thumbnail generation settings
  static const int _defaultMaxWidth = 200;
  static const int _defaultMaxHeight = 200;
  static const int _defaultJpegQuality = 85;
  
  final Map<String, String> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  Future<Directory> _thumbDir() async {
    final base = await getTemporaryDirectory();
    final d = Directory(p.join(base.path, 'thumbnails_v2'));
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }
  
  /// Generate content-based cache key for reliable thumbnail identification
  Future<String> _generateCacheKey({
    required String filePath,
    required String mimeType,
    required int maxWidth,
    required int maxHeight,
  }) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      
      // Create key from file path, size, modification time, and thumbnail params
      final keyData = '${filePath}_${stat.size}_${stat.modified.millisecondsSinceEpoch}_${mimeType}_${maxWidth}x$maxHeight';
      // Simple hash without crypto dependency
      return keyData.hashCode.abs().toString().padLeft(16, '0').substring(0, 16);
    } catch (_) {
      // Fallback to simple hash
      final keyData = '${filePath}_${mimeType}_${maxWidth}x$maxHeight';
      return keyData.hashCode.abs().toString().padLeft(16, '0').substring(0, 16);
    }
  }
  
  /// Main thumbnail generation method with comprehensive file type support
  Future<String?> getOrCreateThumbnail({
    required String filePath,
    required String mimeType,
    int maxWidth = _defaultMaxWidth,
    int maxHeight = _defaultMaxHeight,
    int jpegQuality = _defaultJpegQuality,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (kDebugMode) print('ThumbnailService: File not found: $filePath');
        return null;
      }
      
      // Generate cache key
      final cacheKey = await _generateCacheKey(
        filePath: filePath,
        mimeType: mimeType,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
      
      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey)) {
        final thumbPath = _memoryCache[cacheKey]!;
        if (await File(thumbPath).exists()) {
          _updateCacheAccess(cacheKey);
          return thumbPath;
        } else {
          _memoryCache.remove(cacheKey);
          _cacheTimestamps.remove(cacheKey);
        }
      }
      
      // Check disk cache
      final dir = await _thumbDir();
      final thumbPath = p.join(dir.path, 'thumb_$cacheKey.jpg');
      final thumbFile = File(thumbPath);
      
      if (await thumbFile.exists()) {
        final thumbStat = await thumbFile.stat();
        final age = DateTime.now().difference(thumbStat.modified);
        
        if (age < _cacheValidityDuration) {
          _memoryCache[cacheKey] = thumbPath;
          _updateCacheAccess(cacheKey);
          return thumbPath;
        } else {
          // Thumbnail is expired, delete it
          await thumbFile.delete();
        }
      }
      
      // Generate new thumbnail
      final generatedPath = await _generateThumbnail(
        filePath: filePath,
        mimeType: mimeType,
        outputPath: thumbPath,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        jpegQuality: jpegQuality,
      );
      
      if (generatedPath != null) {
        _memoryCache[cacheKey] = generatedPath;
        _updateCacheAccess(cacheKey);
        await _performCacheMaintenance();
        
        if (kDebugMode) {
          print('ThumbnailService: Generated thumbnail for $filePath -> $generatedPath');
        }
      }
      
      return generatedPath;
    } catch (e) {
      if (kDebugMode) {
        print('ThumbnailService error for $filePath: $e');
      }
      return null;
    }
  }
  
  /// Create or return a placeholder thumbnail for a MIME type without requiring a source file.
  Future<String?> getOrCreateMimePlaceholderThumbnail({
    required String mimeType,
    int maxWidth = _defaultMaxWidth,
    int maxHeight = _defaultMaxHeight,
  }) async {
    try {
      final key = 'ph|${mimeType.toLowerCase()}|${maxWidth}x$maxHeight';
      final cacheKey = key.hashCode.abs().toString().padLeft(16, '0').substring(0, 16);
      final dir = await _thumbDir();
      final thumbPath = p.join(dir.path, 'ph_$cacheKey.jpg');
      final file = File(thumbPath);
      if (await file.exists()) {
        final age = DateTime.now().difference((await file.stat()).modified);
        if (age < _cacheValidityDuration) return thumbPath;
        try { await file.delete(); } catch (_) {}
      }
      // Generate based on MIME
      final m = mimeType.toLowerCase();
      String? out;
      if (m == 'application/pdf') {
        out = await _generatePdfThumbnail(
          filePath: '', outputPath: thumbPath, maxWidth: maxWidth, maxHeight: maxHeight, jpegQuality: _defaultJpegQuality,
        );
      } else if (_isOfficeDocument(m)) {
        out = await _generateOfficeThumbnail(
          filePath: '', mimeType: m, outputPath: thumbPath, maxWidth: maxWidth, maxHeight: maxHeight,
        );
      } else if (m.startsWith('text/') || m.contains('json') || m.contains('xml')) {
        out = await _generateTextThumbnail(
          filePath: '', outputPath: thumbPath, maxWidth: maxWidth, maxHeight: maxHeight,
        );
      } else {
        // generic file placeholder
        out = await _generateIconThumbnail(
          iconType: 'file', outputPath: thumbPath, maxWidth: maxWidth, maxHeight: maxHeight, color: const Color(0xFF666666),
        );
      }
      if (out != null) {
        return out;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('ThumbnailService: placeholder error: $e');
      }
      return null;
    }
  }
  
  /// Use native PDF renderer to generate a thumbnail from raw bytes (page 1)
  /// Not available in current build; reserved for future use.
  Future<String?> getOrCreatePdfThumbnailFromBytes({
    required String idKey,
    required Uint8List bytes,
    int maxWidth = _defaultMaxWidth,
    int maxHeight = _defaultMaxHeight,
  }) async {
    try {
      final key = 'pdfb|$idKey|${bytes.length}|${maxWidth}x$maxHeight';
      final cacheKey = key.hashCode.abs().toString().padLeft(16, '0').substring(0, 16);
      final dir = await _thumbDir();
      final outPath = p.join(dir.path, 'thumb_$cacheKey.jpg');
      final f = File(outPath);
      if (await f.exists()) {
        final age = DateTime.now().difference((await f.stat()).modified);
        if (age < _cacheValidityDuration) return outPath;
        try { await f.delete(); } catch (_) {}
      }
      // PDF rasterization plugin not available: fall back to placeholder generation
      final ph = await _generatePdfThumbnail(
        filePath: '',
        outputPath: outPath,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        jpegQuality: _defaultJpegQuality,
      );
      return ph;
    } catch (e) {
      if (kDebugMode) {
        print('ThumbnailService: PDF bytes render failed: $e');
      }
      return null;
    }
  }


  /// Generate thumbnail for different file types
  Future<String?> _generateThumbnail({
    required String filePath,
    required String mimeType,
    required String outputPath,
    required int maxWidth,
    required int maxHeight,
    required int jpegQuality,
  }) async {
    final mime = mimeType.toLowerCase();
    
    try {
      if (mime.startsWith('image/')) {
        return await _generateImageThumbnail(
          filePath: filePath,
          outputPath: outputPath,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          jpegQuality: jpegQuality,
        );
      } else if (mime == 'application/pdf') {
        return await _generatePdfThumbnail(
          filePath: filePath,
          outputPath: outputPath,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          jpegQuality: jpegQuality,
        );
      } else if (_isOfficeDocument(mime)) {
        return await _generateOfficeThumbnail(
          filePath: filePath,
          mimeType: mime,
          outputPath: outputPath,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
      } else if (mime.startsWith('text/') || mime.contains('json') || mime.contains('xml')) {
        return await _generateTextThumbnail(
          filePath: filePath,
          outputPath: outputPath,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('ThumbnailService: Generation failed for $filePath: $e');
      }
      return null;
    }
  }
  
  /// Generate thumbnail for image files
  Future<String?> _generateImageThumbnail({
    required String filePath,
    required String outputPath,
    required int maxWidth,
    required int maxHeight,
    required int jpegQuality,
  }) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      
      // Try to decode the image - handle base64 if needed
      img.Image? decoded;
      
      try {
        decoded = await compute(_decodeImageIsolate, bytes);
      } catch (_) {
        // Maybe it's base64 encoded text
        try {
          final asText = utf8.decode(bytes, allowMalformed: true);
          if (_looksLikeBase64(asText)) {
            final decodedBytes = base64.decode(asText.replaceAll(RegExp(r'\s'), ''));
            decoded = await compute(_decodeImageIsolate, decodedBytes);
          }
        } catch (_) {}
      }
      
      if (decoded == null) return null;
      
      // Calculate optimal dimensions maintaining aspect ratio
      final dimensions = _calculateThumbnailDimensions(
        originalWidth: decoded.width,
        originalHeight: decoded.height,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
      
      // Resize with high-quality interpolation
      final resized = img.copyResize(
        decoded,
        width: dimensions.width,
        height: dimensions.height,
        interpolation: img.Interpolation.cubic, // Better quality than average
      );
      
      // Apply subtle sharpening for better thumbnail appearance
      final sharpened = img.convolution(resized, filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0
      ], div: 1);
      
      final outputBytes = img.encodeJpg(sharpened, quality: jpegQuality);
      await File(outputPath).writeAsBytes(outputBytes, flush: true);
      
      return outputPath;
    } catch (e) {
      if (kDebugMode) {
        print('ThumbnailService: Image thumbnail generation failed: $e');
      }
      return null;
    }
  }
  
  /// Generate thumbnail for PDF files (placeholder when renderer not available)
  Future<String?> _generatePdfThumbnail({
    required String filePath,
    required String outputPath,
    required int maxWidth,
    required int maxHeight,
    required int jpegQuality,
  }) async {
    try {
      // Create a PDF icon thumbnail with label
      final path = await _generateIconThumbnail(
        iconType: 'pdf',
        outputPath: outputPath,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        color: const Color(0xFFD32F2F),
      );
      if (path != null) {
        // Optionally, we could enhance by attempting page render in future
        return path;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('ThumbnailService: PDF thumbnail generation failed: $e');
      }
      return null;
    }
  }
  
  /// Generate thumbnail for Office documents
  Future<String?> _generateOfficeThumbnail({
    required String filePath,
    required String mimeType,
    required String outputPath,
    required int maxWidth,
    required int maxHeight,
  }) async {
    try {
      Color iconColor;
      
      final m = mimeType.toLowerCase();
      if (m.contains('word') || m.contains('document')) {
        iconColor = const Color(0xFF2B579A); // Word blue
      } else if (m.contains('excel') || m.contains('spreadsheet')) {
        iconColor = const Color(0xFF217346); // Excel green
      } else if (m.contains('powerpoint') || m.contains('presentation')) {
        iconColor = const Color(0xFFD24726); // PowerPoint orange
      } else {
        iconColor = const Color(0xFF666666);
      }
      
      // Try embedded Office thumbnail first if file exists and is reasonably small
      if (filePath.isNotEmpty) {
        try {
          final f = File(filePath);
          if (await f.exists()) {
            final st = await f.stat();
            if (st.size <= 25 * 1024 * 1024) { // 25MB guard
              final bytes = await f.readAsBytes();
              final embedded = await _extractOpenXmlEmbeddedThumbBytes(bytes);
              if (embedded != null) {
                // Scale and save as JPG
                final decoded = img.decodeImage(embedded);
                if (decoded != null) {
                  final dims = _calculateThumbnailDimensions(
                    originalWidth: decoded.width,
                    originalHeight: decoded.height,
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  );
                  final resized = img.copyResize(decoded, width: dims.width, height: dims.height, interpolation: img.Interpolation.cubic);
                  final jpg = img.encodeJpg(resized, quality: 85);
                  await File(outputPath).writeAsBytes(jpg, flush: true);
                  return outputPath;
                }
              }
            }
          }
        } catch (_) {}
      }

      // Generate base icon then overlay label using the image library
      final basePath = await _generateIconThumbnail(
        iconType: 'doc',
        outputPath: outputPath,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        color: iconColor,
      );
      if (basePath == null) return null;
      return basePath;
    } catch (e) {
      if (kDebugMode) {
        print('ThumbnailService: Office thumbnail generation failed: $e');
      }
      return null;
    }
  }
  
  /// Generate thumbnail for text files (fallback generic icon)
  Future<String?> _generateTextThumbnail({
    required String filePath,
    required String outputPath,
    required int maxWidth,
    required int maxHeight,
  }) async {
    try {
      return await _generateIconThumbnail(
        iconType: 'text',
        outputPath: outputPath,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        color: const Color(0xFF424242),
      );
    } catch (e) {
      if (kDebugMode) {
        print('ThumbnailService: Text thumbnail generation failed: $e');
      }
      return null;
    }
  }
  
  /// Generate text preview thumbnail from raw bytes (CSV/JSON/TXT)
  Future<String?> getOrCreateTextPreviewFromBytes({
    required String idKey,
    required Uint8List data,
    required String mimeType,
    int maxWidth = _defaultMaxWidth,
    int maxHeight = _defaultMaxHeight,
    int maxLines = 6,
    int maxCharsPerLine = 32,
  }) async {
    try {
      final key = 'txtb|$idKey|${data.length}|${maxWidth}x$maxHeight|${mimeType.toLowerCase()}';
      final cacheKey = key.hashCode.abs().toString().padLeft(16, '0').substring(0, 16);
      final dir = await _thumbDir();
      final outPath = p.join(dir.path, 'thumb_$cacheKey.jpg');
      final f = File(outPath);
      if (await f.exists()) {
        final age = DateTime.now().difference((await f.stat()).modified);
        if (age < _cacheValidityDuration) return outPath;
        try { await f.delete(); } catch (_) {}
      }

      final text = utf8.decode(data, allowMalformed: true);
      final lines = text.split('\n').take(maxLines).map((l) {
        final s = l.trimRight();
        return s.length > maxCharsPerLine ? '${s.substring(0, maxCharsPerLine)}…' : s;
      }).toList();

      final canvas = img.Image(width: maxWidth, height: maxHeight);
      img.fill(canvas, color: img.ColorRgb8(250, 250, 250));
      img.fillRect(canvas, x1: 0, y1: 0, x2: maxWidth, y2: 26, color: img.ColorRgb8(230, 230, 230));
      // Header accent (label text omitted to avoid font dependency)
      var y = 36;
      for (final line in lines) {
        final ratio = (line.length / maxCharsPerLine).clamp(0.2, 1.0);
        final barWidth = (ratio * (maxWidth - 16)).round();
        img.fillRect(
          canvas,
          x1: 8,
          y1: y,
          x2: 8 + barWidth,
          y2: y + 12,
          color: img.ColorRgb8(80, 80, 80),
        );
        y += 16;
        if (y > maxHeight - 8) break;
      }
      final jpg = img.encodeJpg(canvas, quality: 85);
      await File(outPath).writeAsBytes(jpg, flush: true);
      return outPath;
    } catch (e) {
      if (kDebugMode) print('ThumbnailService: text preview render failed: $e');
      return null;
    }
  }

  /// Generate icon-based thumbnail for non-image files
  Future<String?> _generateIconThumbnail({
    required String iconType,
    required String outputPath,
    required int maxWidth,
    required int maxHeight,
    required Color color,
  }) async {
    try {
      // Create a simple colored rectangle as icon thumbnail
      final image = img.Image(width: maxWidth, height: maxHeight);
      img.fill(image, color: img.ColorRgb8(230, 230, 230)); // Light gray background
      
      // Add colored rectangle in center
      final rectWidth = (maxWidth * 0.6).round();
      final rectHeight = (maxHeight * 0.8).round();
      final rectX = (maxWidth - rectWidth) ~/ 2;
      final rectY = (maxHeight - rectHeight) ~/ 2;
      
      final cr = (color.r * 255.0).round() & 0xFF;
      final cg = (color.g * 255.0).round() & 0xFF;
      final cb = (color.b * 255.0).round() & 0xFF;
      img.fillRect(
        image,
        x1: rectX,
        y1: rectY,
        x2: rectX + rectWidth,
        y2: rectY + rectHeight,
        color: img.ColorRgb8(cr, cg, cb),
      );
      
      // Add some decoration lines
      for (int i = 0; i < 3; i++) {
        final lineY = rectY + rectHeight ~/ 4 + i * (rectHeight ~/ 6);
        img.drawLine(
          image,
          x1: rectX + rectWidth ~/ 8,
          y1: lineY,
          x2: rectX + rectWidth - rectWidth ~/ 8,
          y2: lineY,
          color: img.ColorRgb8(255, 255, 255),
          thickness: 2,
        );
      }

      final outputBytes = img.encodeJpg(image, quality: 90);
      await File(outputPath).writeAsBytes(outputBytes, flush: true);
      
      return outputPath;
    } catch (e) {
      if (kDebugMode) {
        print('ThumbnailService: Icon thumbnail generation failed: $e');
      }
      return null;
    }
  }
  
  /// Fit width/height into max bounds preserving aspect

  /// Calculate optimal thumbnail dimensions maintaining aspect ratio
  ({int width, int height}) _calculateThumbnailDimensions({
    required int originalWidth,
    required int originalHeight,
    required int maxWidth,
    required int maxHeight,
  }) {
    if (originalWidth <= maxWidth && originalHeight <= maxHeight) {
      return (width: originalWidth, height: originalHeight);
    }
    
    final widthRatio = maxWidth / originalWidth;
    final heightRatio = maxHeight / originalHeight;
    final ratio = widthRatio < heightRatio ? widthRatio : heightRatio;
    
    return (
      width: (originalWidth * ratio).round(),
      height: (originalHeight * ratio).round(),
    );
  }
  
  /// Cache management and maintenance
  void _updateCacheAccess(String cacheKey) {
    _cacheTimestamps[cacheKey] = DateTime.now();
  }
  
  Future<void> _performCacheMaintenance() async {
    try {
      final dir = await _thumbDir();
      final files = await dir.list().where((f) => f is File).cast<File>().toList();
      
      // Check cache size
      int totalSize = 0;
      final fileStats = <File, FileStat>{};
      
      for (final file in files) {
        try {
          final stat = await file.stat();
          fileStats[file] = stat;
          totalSize += stat.size;
        } catch (_) {}
      }
      
      // Clean up if cache is too large or has too many entries
      if (totalSize > _maxCacheSize || files.length > _maxCacheEntries) {
        // Sort by access time (oldest first)
        files.sort((a, b) {
          final aTime = fileStats[a]?.accessed ?? DateTime(0);
          final bTime = fileStats[b]?.accessed ?? DateTime(0);
          return aTime.compareTo(bTime);
        });
        
        // Remove oldest files until we're under limits
        int currentSize = totalSize;
        int currentCount = files.length;
        
        for (final file in files) {
          if (currentSize <= _maxCacheSize * 0.8 && currentCount <= _maxCacheEntries * 0.8) {
            break;
          }
          
          try {
            final stat = fileStats[file];
            await file.delete();
            if (stat != null) {
              currentSize -= stat.size;
            }
            currentCount--;
            
            // Clean up memory cache too
            final fileName = p.basename(file.path);
            _memoryCache.removeWhere((key, path) => p.basename(path) == fileName);
          } catch (_) {}
        }
        
        if (kDebugMode) {
          print('ThumbnailService: Cache maintenance completed. Size: ${currentSize ~/ 1024}KB, Count: $currentCount');
        }
      }
      
      // Clean up expired entries from memory cache
      final now = DateTime.now();
      _cacheTimestamps.removeWhere((key, time) => now.difference(time) > _cacheValidityDuration);
      _memoryCache.removeWhere((key, _) => !_cacheTimestamps.containsKey(key));
      
    } catch (e) {
      if (kDebugMode) {
        print('ThumbnailService: Cache maintenance error: $e');
      }
    }
  }
  
  /// Helper methods
  Future<Uint8List?> _extractOpenXmlEmbeddedThumbBytes(Uint8List bytes) async {
    try {
      final arch = z.ZipDecoder().decodeBytes(bytes, verify: false);
      for (final f in arch.files) {
        final name = f.name.toLowerCase();
        if (name == 'docprops/thumbnail.jpeg' && f.isFile) {
          final content = f.content as List<int>;
          return Uint8List.fromList(content);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isOfficeDocument(String mimeType) {
    final mime = mimeType.toLowerCase();
    return mime.contains('word') ||
           mime.contains('excel') ||
           mime.contains('powerpoint') ||
           mime.contains('officedocument') ||
           mime.contains('spreadsheet') ||
           mime.contains('presentation');
  }
  
  bool _looksLikeBase64(String content) {
    if (content.length < 20) return false;
    final cleaned = content.replaceAll(RegExp(r'\s'), '');
    if (cleaned.length % 4 != 0) return false;
    return RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(cleaned);
  }
  
  /// Clear all cached thumbnails
  Future<void> clearCache() async {
    try {
      final dir = await _thumbDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
      _memoryCache.clear();
      _cacheTimestamps.clear();
      
      if (kDebugMode) {
        print('ThumbnailService: Cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ThumbnailService: Cache clear error: $e');
      }
    }
  }
}

/// Isolate function for image decoding
img.Image? _decodeImageIsolate(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}
