import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'mail_service.dart';

/// Advanced connection manager with intelligent reconnection strategies
/// Handles network failures, server timeouts, and connection optimization
class ConnectionManager extends GetxService {
  static ConnectionManager? _instance;
  static ConnectionManager get instance => _instance ??= ConnectionManager._();

  ConnectionManager._();

  // Advanced reconnection configuration
  static const Duration _baseReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(minutes: 10);
  static const int _maxConsecutiveFailures = 15;
  static const int _fastReconnectThreshold =
      3; // Fast reconnect for first 3 attempts
  static const Duration _fastReconnectDelay = Duration(seconds: 2);
  static const Duration _connectionTimeout = Duration(seconds: 20);
  static const Duration _networkCheckInterval = Duration(seconds: 30);

  // Connection state tracking
  ConnectionState _currentState = ConnectionState.disconnected;
  int _consecutiveFailures = 0;
  int _totalReconnections = 0;
  DateTime? _lastSuccessfulConnection;
  DateTime? _lastFailureTime;
  Timer? _reconnectTimer;
  Timer? _networkMonitorTimer;
  String? _lastErrorMessage;

  // Network quality tracking
  final List<Duration> _connectionTimes = [];
  final List<bool> _recentConnectionAttempts = [];
  static const int _maxHistorySize = 20;

  // Reactive state
  final Rx<ConnectionState> connectionState = ConnectionState.disconnected.obs;
  final RxString connectionStatus = 'Disconnected'.obs;
  final RxDouble connectionQuality = 0.0.obs; // 0.0 to 1.0
  final RxBool isReconnecting = false.obs;

  MailService? get _mailService {
    // Use singleton instance; avoid runtime DI lookups in services
    return MailService.instance;
  }

  @override
  void onInit() {
    super.onInit();
    _startNetworkMonitoring();
    if (kDebugMode) {
      print('🔌 ConnectionManager initialized');
    }
  }

  /// Attempt to establish connection with smart retry logic
  Future<bool> connect({bool forceReconnect = false}) async {
    if (_currentState == ConnectionState.connecting && !forceReconnect) {
      if (kDebugMode) {
        print('🔌 Connection attempt already in progress');
      }
      return false;
    }

    _updateState(ConnectionState.connecting);
    isReconnecting.value = true;

    final stopwatch = Stopwatch()..start();

    try {
      if (kDebugMode) {
        print(
          '🔌 🚀 Attempting connection (attempt ${_consecutiveFailures + 1})',
        );
      }

      final mailService = _mailService;
      if (mailService == null) {
        throw Exception('MailService not available');
      }

      // Perform connection with timeout
      await mailService.connect().timeout(
        _connectionTimeout,
        onTimeout:
            () =>
                throw TimeoutException(
                  'Connection timeout',
                  _connectionTimeout,
                ),
      );

      // Verify connection is actually working
      await _verifyConnection();

      // Connection successful
      stopwatch.stop();
      _onConnectionSuccess(stopwatch.elapsed);

      return true;
    } catch (e) {
      stopwatch.stop();
      await _onConnectionFailure(e, stopwatch.elapsed);
      return false;
    } finally {
      isReconnecting.value = false;
    }
  }

  /// Verify connection is working properly
  Future<void> _verifyConnection() async {
    final mailService = _mailService;
    if (mailService == null) return;

    try {
      // Quick verification - check if we can list mailboxes
      if (mailService.client.mailboxes == null ||
          mailService.client.mailboxes!.isEmpty) {
        await mailService.client.listMailboxes().timeout(
          const Duration(seconds: 10),
        );
      }

      // Ensure we have at least one mailbox
      if (mailService.client.mailboxes?.isEmpty ?? true) {
        throw Exception('No mailboxes available');
      }
    } catch (e) {
      throw Exception('Connection verification failed: $e');
    }
  }

  /// Handle successful connection
  void _onConnectionSuccess(Duration connectionTime) {
    _consecutiveFailures = 0;
    _lastSuccessfulConnection = DateTime.now();
    _lastErrorMessage = null;

    // Track connection performance
    _connectionTimes.add(connectionTime);
    _recentConnectionAttempts.add(true);
    _trimHistory();

    _updateConnectionQuality();
    _updateState(ConnectionState.connected);

    if (kDebugMode) {
      print('🔌 ✅ Connection successful in ${connectionTime.inMilliseconds}ms');
    }
  }

  /// Handle connection failure with smart backoff
  Future<void> _onConnectionFailure(
    dynamic error,
    Duration attemptDuration,
  ) async {
    _consecutiveFailures++;
    _totalReconnections++;
    _lastFailureTime = DateTime.now();
    _lastErrorMessage = error.toString();

    // Track failure
    _recentConnectionAttempts.add(false);
    _trimHistory();

    _updateConnectionQuality();
    _updateState(ConnectionState.disconnected);

    if (kDebugMode) {
      print(
        '🔌 ❌ Connection failed ($_consecutiveFailures/$_maxConsecutiveFailures): $error',
      );
    }

    // Check if we should give up
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      if (kDebugMode) {
        print(
          '🔌 🚫 Max consecutive failures reached, stopping reconnection attempts',
        );
      }
      _updateState(ConnectionState.failed);
      return;
    }

    // Schedule smart reconnection
    await _scheduleReconnection();
  }

  /// Schedule reconnection with intelligent backoff strategy
  Future<void> _scheduleReconnection() async {
    _reconnectTimer?.cancel();

    final delay = _calculateReconnectDelay();

    if (kDebugMode) {
      print('🔌 ⏳ Scheduling reconnection in ${delay.inSeconds}s');
    }

    _reconnectTimer = Timer(delay, () {
      if (_currentState != ConnectionState.connected) {
        unawaited(connect());
      }
    });
  }

  /// Calculate smart reconnection delay based on failure patterns
  Duration _calculateReconnectDelay() {
    // Fast reconnect for first few attempts
    if (_consecutiveFailures <= _fastReconnectThreshold) {
      return _fastReconnectDelay;
    }

    // Exponential backoff with jitter
    final exponentialDelay =
        _baseReconnectDelay.inMilliseconds *
        pow(2, _consecutiveFailures - _fastReconnectThreshold - 1).toInt();

    // Cap the delay
    final cappedDelay = min(
      exponentialDelay,
      _maxReconnectDelay.inMilliseconds,
    );

    // Add jitter (±25% randomization)
    final jitterRange = (cappedDelay * 0.25).toInt();
    final jitter = Random().nextInt(jitterRange * 2) - jitterRange;

    final finalDelay = cappedDelay + jitter;

    return Duration(milliseconds: max(1000, finalDelay)); // Minimum 1 second
  }

  /// Update connection state and notify observers
  void _updateState(ConnectionState newState) {
    _currentState = newState;
    connectionState.value = newState;

    switch (newState) {
      case ConnectionState.connected:
        connectionStatus.value = 'Connected';
        break;
      case ConnectionState.connecting:
        connectionStatus.value = 'Connecting...';
        break;
      case ConnectionState.disconnected:
        connectionStatus.value = 'Disconnected';
        break;
      case ConnectionState.failed:
        connectionStatus.value = 'Connection Failed';
        break;
      case ConnectionState.reconnecting:
        connectionStatus.value = 'Reconnecting...';
        break;
    }
  }

  /// Calculate and update connection quality metric
  void _updateConnectionQuality() {
    if (_recentConnectionAttempts.isEmpty) {
      connectionQuality.value = 0.0;
      return;
    }

    // Calculate success rate
    final successCount =
        _recentConnectionAttempts.where((success) => success).length;
    final successRate = successCount / _recentConnectionAttempts.length;

    // Factor in connection speed
    double speedFactor = 1.0;
    if (_connectionTimes.isNotEmpty) {
      final avgConnectionTime =
          _connectionTimes.fold<int>(
            0,
            (sum, time) => sum + time.inMilliseconds,
          ) /
          _connectionTimes.length;
      speedFactor =
          1.0 -
          min(0.5, avgConnectionTime / 10000); // Penalize slow connections
    }

    // Factor in recent failures
    double stabilityFactor = 1.0;
    if (_consecutiveFailures > 0) {
      stabilityFactor = max(
        0.1,
        1.0 - (_consecutiveFailures / _maxConsecutiveFailures),
      );
    }

    final quality = successRate * speedFactor * stabilityFactor;
    connectionQuality.value = quality.clamp(0.0, 1.0);
  }

  /// Trim history to prevent memory growth
  void _trimHistory() {
    if (_connectionTimes.length > _maxHistorySize) {
      _connectionTimes.removeRange(
        0,
        _connectionTimes.length - _maxHistorySize,
      );
    }
    if (_recentConnectionAttempts.length > _maxHistorySize) {
      _recentConnectionAttempts.removeRange(
        0,
        _recentConnectionAttempts.length - _maxHistorySize,
      );
    }
  }

  /// Start network monitoring for proactive connection management
  void _startNetworkMonitoring() {
    _networkMonitorTimer?.cancel();
    _networkMonitorTimer = Timer.periodic(_networkCheckInterval, (_) {
      _performNetworkCheck();
    });
  }

  /// Perform network connectivity check
  void _performNetworkCheck() {
    if (_currentState == ConnectionState.connected) {
      // Verify existing connection is still healthy
      _verifyExistingConnection();
    } else if (_currentState == ConnectionState.disconnected &&
        _consecutiveFailures < _maxConsecutiveFailures) {
      // Attempt to reconnect if we're not connected and haven't exceeded max failures
      unawaited(connect());
    }
  }

  /// Verify existing connection is still healthy
  Future<void> _verifyExistingConnection() async {
    try {
      final mailService = _mailService;
      if (mailService?.client.isConnected != true) {
        if (kDebugMode) {
          print('🔌 ⚠️ Connection lost, will reconnect');
        }
        _updateState(ConnectionState.disconnected);
        unawaited(connect());
        return;
      }

      // Quick health check - this should be fast
      await _verifyConnection();
    } catch (e) {
      if (kDebugMode) {
        print('🔌 ⚠️ Connection health check failed: $e');
      }
      _updateState(ConnectionState.disconnected);
      unawaited(connect());
    }
  }

  /// Force immediate reconnection
  Future<bool> forceReconnect() async {
    if (kDebugMode) {
      print('🔌 🔄 Force reconnection requested');
    }

    _reconnectTimer?.cancel();
    _consecutiveFailures = 0; // Reset failure count for forced reconnect

    return await connect(forceReconnect: true);
  }

  /// Reset connection manager state
  void reset() {
    if (kDebugMode) {
      print('🔌 🔄 Resetting connection manager');
    }

    _reconnectTimer?.cancel();
    _consecutiveFailures = 0;
    _totalReconnections = 0;
    _lastErrorMessage = null;
    _connectionTimes.clear();
    _recentConnectionAttempts.clear();

    _updateConnectionQuality();
    _updateState(ConnectionState.disconnected);
  }

  /// Get comprehensive connection statistics
  Map<String, dynamic> getConnectionStats() {
    final uptime =
        _lastSuccessfulConnection != null
            ? DateTime.now().difference(_lastSuccessfulConnection!)
            : Duration.zero;

    return {
      'currentState': _currentState.toString(),
      'consecutiveFailures': _consecutiveFailures,
      'totalReconnections': _totalReconnections,
      'connectionQuality': connectionQuality.value,
      'lastSuccessfulConnection': _lastSuccessfulConnection?.toIso8601String(),
      'lastFailureTime': _lastFailureTime?.toIso8601String(),
      'lastError': _lastErrorMessage,
      'uptime': uptime.toString(),
      'averageConnectionTime':
          _connectionTimes.isNotEmpty
              ? '${(_connectionTimes.fold<int>(0, (sum, time) => sum + time.inMilliseconds) / _connectionTimes.length).round()}ms'
              : 'N/A',
      'successRate':
          _recentConnectionAttempts.isNotEmpty
              ? '${((_recentConnectionAttempts.where((success) => success).length / _recentConnectionAttempts.length) * 100).toStringAsFixed(1)}%'
              : 'N/A',
    };
  }

  /// Check if connection is healthy
  bool get isHealthy =>
      _currentState == ConnectionState.connected && _consecutiveFailures == 0;

  /// Check if should attempt reconnection
  bool get shouldReconnect =>
      _currentState != ConnectionState.connected &&
      _consecutiveFailures < _maxConsecutiveFailures;

  @override
  void onClose() {
    _reconnectTimer?.cancel();
    _networkMonitorTimer?.cancel();
    super.onClose();
  }
}

/// Connection state enumeration
enum ConnectionState {
  connected,
  connecting,
  disconnected,
  reconnecting,
  failed,
}

/// Helper function for fire-and-forget async operations
void unawaited(Future<void> future) {
  future.catchError((error) {
    if (kDebugMode) {
      print('🔌 ⚠️ Unawaited future error: $error');
    }
  });
}
