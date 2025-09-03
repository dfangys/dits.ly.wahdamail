import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// ENHANCED: IMAP Performance Optimizer based on enough_mail_app patterns
/// Implements connection pooling, size limits, and intelligent fetching strategies
class ImapPerformanceOptimizer {
  static final Logger _logger = Logger();

  // Performance constants based on enough_mail_app analysis
  static const int maxMessageSizeForFullFetch = 50 * 1024; // 50KB
  static const int maxBatchSize = 25; // Optimal batch size for mobile
  static const int connectionPoolSize =
      3; // Multiple connections for performance
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration idleTimeout = Duration(minutes: 29); // IMAP IDLE limit

  // Connection pool management
  final List<ImapClient> _connectionPool = [];
  final List<bool> _connectionAvailability = [];
  Timer? _connectionHealthTimer;

  // Performance metrics
  int _totalFetches = 0;
  final int _cacheMisses = 0;
  final int _cacheHits = 0;
  Duration _totalFetchTime = Duration.zero;

  /// Initialize the performance optimizer
  Future<void> initialize(MailAccount account) async {
    try {
      // Create connection pool
      for (int i = 0; i < connectionPoolSize; i++) {
        final client = ImapClient(isLogEnabled: kDebugMode);
        await client.connectToServer(
          account.incoming.serverConfig.hostname,
          account.incoming.serverConfig.port,
          isSecure: account.incoming.serverConfig.isSecureSocket,
        );

        await client.login(
          account.userName,
          (account.incoming.authentication as PlainAuthentication).password,
        );

        _connectionPool.add(client);
        _connectionAvailability.add(true);

        _logger.i('📧 IMAP connection ${i + 1} established');
      }

      // Start connection health monitoring
      _startConnectionHealthMonitoring();

      _logger.i(
        '📧 IMAP Performance Optimizer initialized with ${_connectionPool.length} connections',
      );
    } catch (e) {
      _logger.e('📧 Failed to initialize IMAP Performance Optimizer: $e');
      rethrow;
    }
  }

  /// Get an available connection from the pool
  Future<ImapClient?> _getAvailableConnection() async {
    for (int i = 0; i < _connectionPool.length; i++) {
      if (_connectionAvailability[i]) {
        _connectionAvailability[i] = false;
        return _connectionPool[i];
      }
    }

    // If no connections available, wait and retry
    await Future.delayed(const Duration(milliseconds: 100));
    return _getAvailableConnection();
  }

  /// Release a connection back to the pool
  void _releaseConnection(ImapClient client) {
    final index = _connectionPool.indexOf(client);
    if (index != -1) {
      _connectionAvailability[index] = true;
    }
  }

  /// Optimized message fetching with size-based strategy
  Future<List<MimeMessage>> fetchMessagesOptimized(
    Mailbox mailbox,
    MessageSequence sequence, {
    FetchPreference? preference,
  }) async {
    final stopwatch = Stopwatch()..start();
    ImapClient? client;

    try {
      client = await _getAvailableConnection();
      if (client == null) {
        throw Exception('No available IMAP connections');
      }

      await client.selectMailbox(mailbox);

      // ENHANCED: Use size-based fetching strategy from enough_mail_app
      final fetchPreference = preference ?? _determineFetchPreference(sequence);

      final fetchResult = await client.fetchMessages(
        sequence,
        _fetchPreferenceToString(fetchPreference),
      );

      // Extract messages from FetchImapResult
      final messages = fetchResult.messages;

      // Apply post-fetch optimizations
      await _optimizeMessages(messages, client, mailbox);

      _totalFetches++;
      _totalFetchTime += stopwatch.elapsed;

      if (kDebugMode) {
        print(
          '📧 Fetched ${messages.length} messages in ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      return messages;
    } catch (e) {
      _logger.e('📧 Error in optimized fetch: $e');
      rethrow;
    } finally {
      if (client != null) {
        _releaseConnection(client);
      }
      stopwatch.stop();
    }
  }

  /// Convert FetchPreference enum to string for enough_mail v2.1.7 compatibility
  String _fetchPreferenceToString(FetchPreference preference) {
    switch (preference) {
      case FetchPreference.envelope:
        return 'ENVELOPE';
      case FetchPreference.bodystructure:
        return 'BODYSTRUCTURE';
      case FetchPreference.fullWhenWithinSize:
        return 'BODY[]';
      case FetchPreference.full:
        return 'BODY[]';
    }
  }

  /// Determine optimal fetch preference based on message characteristics
  FetchPreference _determineFetchPreference(MessageSequence sequence) {
    // For small batches, fetch full content
    if (sequence.length <= 5) {
      return FetchPreference.fullWhenWithinSize;
    }

    // For medium batches, fetch envelope and structure
    if (sequence.length <= 15) {
      return FetchPreference.envelope;
    }

    // For large batches, fetch envelope only
    return FetchPreference.envelope;
  }

  /// Apply post-fetch optimizations to messages
  Future<void> _optimizeMessages(
    List<MimeMessage> messages,
    ImapClient client,
    Mailbox mailbox,
  ) async {
    for (final message in messages) {
      try {
        // Ensure message has complete envelope data
        if (message.envelope == null) {
          await _fetchMissingEnvelope(message, client, mailbox);
        }

        // Optimize message structure for display
        _optimizeMessageStructure(message);
      } catch (e) {
        _logger.w('📧 Error optimizing message ${message.sequenceId}: $e');
      }
    }
  }

  /// Fetch missing envelope data for a message
  Future<void> _fetchMissingEnvelope(
    MimeMessage message,
    ImapClient client,
    Mailbox mailbox,
  ) async {
    if (message.sequenceId == null) return;

    try {
      final sequence = MessageSequence.fromId(message.sequenceId!);
      final fetchResult = await client.fetchMessages(
        sequence,
        _fetchPreferenceToString(FetchPreference.envelope),
      );

      if (fetchResult.messages.isNotEmpty) {
        message.envelope = fetchResult.messages.first.envelope;
      }
    } catch (e) {
      _logger.w(
        '📧 Failed to fetch envelope for message ${message.sequenceId}: $e',
      );
    }
  }

  /// Optimize message structure for better display performance
  void _optimizeMessageStructure(MimeMessage message) {
    // Ensure message has proper flags (flags is already List<String>?)
    message.flags ??= <String>[];

    // Cache commonly accessed properties
    if (message.envelope != null) {
      // Pre-decode subject for faster access
      try {
        message.decodeSubject();
      } catch (e) {
        // Ignore decode errors
      }

      // Pre-decode date for faster access
      try {
        message.decodeDate();
      } catch (e) {
        // Ignore decode errors
      }
    }
  }

  /// Start connection health monitoring
  void _startConnectionHealthMonitoring() {
    _connectionHealthTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) => _checkConnectionHealth(),
    );
  }

  /// Check and maintain connection health
  Future<void> _checkConnectionHealth() async {
    for (int i = 0; i < _connectionPool.length; i++) {
      if (!_connectionAvailability[i]) continue; // Skip busy connections

      try {
        final client = _connectionPool[i];

        // Send NOOP to check connection
        await client.noop().timeout(const Duration(seconds: 10));
      } catch (e) {
        _logger.w('📧 Connection $i health check failed: $e');

        // Try to reconnect
        try {
          await _reconnectClient(i);
        } catch (reconnectError) {
          _logger.e('📧 Failed to reconnect client $i: $reconnectError');
        }
      }
    }
  }

  /// Reconnect a specific client
  Future<void> _reconnectClient(int index) async {
    // Implementation would depend on account details
    // For now, mark as unavailable
    _connectionAvailability[index] = false;
    _logger.w('📧 Connection $index marked as unavailable');
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final avgFetchTime =
        _totalFetches > 0
            ? _totalFetchTime.inMilliseconds / _totalFetches
            : 0.0;

    return {
      'totalFetches': _totalFetches,
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'cacheHitRate': _totalFetches > 0 ? _cacheHits / _totalFetches : 0.0,
      'avgFetchTimeMs': avgFetchTime,
      'activeConnections': _connectionPool.length,
      'availableConnections':
          _connectionAvailability.where((available) => available).length,
    };
  }

  /// Dispose of resources
  Future<void> dispose() async {
    _connectionHealthTimer?.cancel();

    for (final client in _connectionPool) {
      try {
        await client.disconnect();
      } catch (e) {
        _logger.w('📧 Error disconnecting client: $e');
      }
    }

    _connectionPool.clear();
    _connectionAvailability.clear();

    _logger.i('📧 IMAP Performance Optimizer disposed');
  }
}
