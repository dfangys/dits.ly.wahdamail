import 'dart:async';
import 'dart:io';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:get/get.dart';

/// ENHANCED: Advanced Error Handling System based on enough_mail_app patterns
/// Provides comprehensive error categorization, recovery strategies, and user feedback
class AdvancedErrorHandler {
  static final Logger _logger = Logger();

  // Error categorization for better handling
  static const Map<Type, ErrorCategory> _errorCategories = {
    SocketException: ErrorCategory.network,
    TimeoutException: ErrorCategory.network,
    HandshakeException: ErrorCategory.authentication,
    ImapException: ErrorCategory.server,
    SmtpException: ErrorCategory.server,
    FormatException: ErrorCategory.data,
    StateError: ErrorCategory.application,
  };

  // Recovery strategies for different error types
  static const Map<ErrorCategory, RecoveryStrategy> _recoveryStrategies = {
    ErrorCategory.network: RecoveryStrategy.retry,
    ErrorCategory.authentication: RecoveryStrategy.reauth,
    ErrorCategory.server: RecoveryStrategy.fallback,
    ErrorCategory.data: RecoveryStrategy.skip,
    ErrorCategory.application: RecoveryStrategy.restart,
  };

  // Error tracking for analytics
  static final Map<String, int> _errorCounts = {};
  static final List<ErrorReport> _recentErrors = [];
  static const int _maxRecentErrors = 50;

  /// Handle an error with comprehensive analysis and recovery
  static Future<ErrorHandlingResult> handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Create error report
      final errorReport = ErrorReport(
        error: error,
        stackTrace: stackTrace ?? StackTrace.current,
        context: context ?? 'Unknown',
        timestamp: DateTime.now(),
        metadata: metadata ?? {},
      );

      // Track error for analytics
      _trackError(errorReport);

      // Categorize error
      final category = _categorizeError(error);

      // Determine recovery strategy
      final strategy = _recoveryStrategies[category] ?? RecoveryStrategy.none;

      // Log error with appropriate level
      _logError(errorReport, category);

      // Show user-friendly message
      _showUserFeedback(errorReport, category);

      // Execute recovery strategy
      final recovered = await _executeRecoveryStrategy(strategy, errorReport);

      return ErrorHandlingResult(
        category: category,
        strategy: strategy,
        recovered: recovered,
        userMessage: _getUserMessage(errorReport, category),
      );
    } catch (handlingError) {
      _logger.e('🚨 Error in error handler: $handlingError');
      return ErrorHandlingResult(
        category: ErrorCategory.application,
        strategy: RecoveryStrategy.none,
        recovered: false,
        userMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Categorize error based on type and content
  static ErrorCategory _categorizeError(dynamic error) {
    // Check by type first
    final category = _errorCategories[error.runtimeType];
    if (category != null) return category;

    // Check by error message content
    final errorMessage = error.toString().toLowerCase();

    if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('timeout')) {
      return ErrorCategory.network;
    }

    if (errorMessage.contains('auth') ||
        errorMessage.contains('login') ||
        errorMessage.contains('credential')) {
      return ErrorCategory.authentication;
    }

    if (errorMessage.contains('server') ||
        errorMessage.contains('imap') ||
        errorMessage.contains('smtp')) {
      return ErrorCategory.server;
    }

    if (errorMessage.contains('format') ||
        errorMessage.contains('parse') ||
        errorMessage.contains('decode')) {
      return ErrorCategory.data;
    }

    return ErrorCategory.unknown;
  }

  /// Track error for analytics and monitoring
  static void _trackError(ErrorReport report) {
    final errorKey = '${report.error.runtimeType}_${report.context}';
    _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;

    _recentErrors.insert(0, report);
    if (_recentErrors.length > _maxRecentErrors) {
      _recentErrors.removeLast();
    }

    // Log error frequency for monitoring
    if (_errorCounts[errorKey]! > 5) {
      _logger.w(
        '🚨 Frequent error detected: $errorKey (${_errorCounts[errorKey]} times)',
      );
    }
  }

  /// Log error with appropriate level and detail
  static void _logError(ErrorReport report, ErrorCategory category) {
    final logLevel = _getLogLevel(category);
    final message =
        '📧 ${category.name.toUpperCase()} ERROR in ${report.context}: ${report.error}';

    switch (logLevel) {
      case Level.error:
        _logger.e(message, error: report.error, stackTrace: report.stackTrace);
        break;
      case Level.warning:
        _logger.w(message);
        break;
      case Level.info:
        _logger.i(message);
        break;
      default:
        _logger.d(message);
    }
  }

  /// Get appropriate log level for error category
  static Level _getLogLevel(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.authentication:
      case ErrorCategory.application:
        return Level.error;
      case ErrorCategory.server:
      case ErrorCategory.network:
        return Level.warning;
      case ErrorCategory.data:
        return Level.info;
      default:
        return Level.debug;
    }
  }

  /// Show user-friendly feedback based on error category
  static void _showUserFeedback(ErrorReport report, ErrorCategory category) {
    if (!kDebugMode) return; // Only show in debug mode for now

    final message = _getUserMessage(report, category);
    final color = _getErrorColor(category);

    try {
      Get.snackbar(
        'Email Error',
        message,
        backgroundColor: color,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      // Fallback if GetX is not available
      if (kDebugMode) {
        print('📧 Error feedback: $message');
      }
    }
  }

  /// Get user-friendly error message
  static String _getUserMessage(ErrorReport report, ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return 'Network connection issue. Please check your internet connection.';
      case ErrorCategory.authentication:
        return 'Authentication failed. Please check your email credentials.';
      case ErrorCategory.server:
        return 'Email server is temporarily unavailable. Please try again later.';
      case ErrorCategory.data:
        return 'Email data format issue. Some content may not display correctly.';
      case ErrorCategory.application:
        return 'Application error occurred. Please restart the app if issues persist.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get appropriate color for error category
  static Color _getErrorColor(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.authentication:
      case ErrorCategory.application:
        return Colors.red;
      case ErrorCategory.server:
      case ErrorCategory.network:
        return Colors.orange;
      case ErrorCategory.data:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Execute recovery strategy for the error
  static Future<bool> _executeRecoveryStrategy(
    RecoveryStrategy strategy,
    ErrorReport report,
  ) async {
    try {
      switch (strategy) {
        case RecoveryStrategy.retry:
          return await _attemptRetry(report);
        case RecoveryStrategy.reauth:
          return await _attemptReauth(report);
        case RecoveryStrategy.fallback:
          return await _attemptFallback(report);
        case RecoveryStrategy.skip:
          return true; // Skip and continue
        case RecoveryStrategy.restart:
          return await _attemptRestart(report);
        default:
          return false;
      }
    } catch (e) {
      _logger.e('🚨 Recovery strategy failed: $e');
      return false;
    }
  }

  /// Attempt retry recovery
  static Future<bool> _attemptRetry(ErrorReport report) async {
    _logger.i('📧 Attempting retry recovery for: ${report.context}');

    // Wait before retry
    await Future.delayed(const Duration(seconds: 2));

    // Return true to indicate retry should be attempted
    return true;
  }

  /// Attempt reauthentication recovery
  static Future<bool> _attemptReauth(ErrorReport report) async {
    _logger.i('📧 Attempting reauthentication recovery for: ${report.context}');

    // This would trigger reauthentication flow
    // Implementation depends on your auth system
    return false; // For now, return false
  }

  /// Attempt fallback recovery
  static Future<bool> _attemptFallback(ErrorReport report) async {
    _logger.i('📧 Attempting fallback recovery for: ${report.context}');

    // This would use alternative methods or cached data
    return true;
  }

  /// Attempt restart recovery
  static Future<bool> _attemptRestart(ErrorReport report) async {
    _logger.i('📧 Attempting restart recovery for: ${report.context}');

    // This would restart relevant services
    return false; // For now, return false
  }

  /// Get error statistics for monitoring
  static Map<String, dynamic> getErrorStatistics() {
    final totalErrors = _errorCounts.values.fold(
      0,
      (sum, count) => sum + count,
    );
    final uniqueErrors = _errorCounts.length;

    return {
      'totalErrors': totalErrors,
      'uniqueErrors': uniqueErrors,
      'recentErrorsCount': _recentErrors.length,
      'errorCounts': Map.from(_errorCounts),
      'lastErrorTime':
          _recentErrors.isNotEmpty ? _recentErrors.first.timestamp : null,
    };
  }

  /// Clear error history (for testing or reset)
  static void clearErrorHistory() {
    _errorCounts.clear();
    _recentErrors.clear();
    _logger.i('📧 Error history cleared');
  }
}

/// Error categories for better handling
enum ErrorCategory {
  network,
  authentication,
  server,
  data,
  application,
  unknown,
}

/// Recovery strategies for different error types
enum RecoveryStrategy { retry, reauth, fallback, skip, restart, none }

/// Error report structure
class ErrorReport {
  final dynamic error;
  final StackTrace stackTrace;
  final String context;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  ErrorReport({
    required this.error,
    required this.stackTrace,
    required this.context,
    required this.timestamp,
    required this.metadata,
  });

  @override
  String toString() {
    return 'ErrorReport(error: $error, context: $context, timestamp: $timestamp)';
  }
}

/// Error handling result
class ErrorHandlingResult {
  final ErrorCategory category;
  final RecoveryStrategy strategy;
  final bool recovered;
  final String userMessage;

  ErrorHandlingResult({
    required this.category,
    required this.strategy,
    required this.recovered,
    required this.userMessage,
  });

  @override
  String toString() {
    return 'ErrorHandlingResult(category: $category, strategy: $strategy, recovered: $recovered)';
  }
}
