import 'dart:async';
import 'dart:math';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'mail_service.dart';
import 'realtime_update_service.dart';
import 'connection_manager.dart';

/// Optimized IMAP IDLE service for high-performance real-time email updates
/// Compatible with enough_mail v2.1.7 API
class OptimizedIdleService extends GetxService {
  static OptimizedIdleService? _instance;
  static OptimizedIdleService get instance => _instance ??= OptimizedIdleService._();
  
  OptimizedIdleService._();

  // Configuration constants for optimal performance
  static const Duration _idleTimeout = Duration(minutes: 28); // Refresh before 30min server timeout
  static const Duration _initialReconnectDelay = Duration(seconds: 2);
  static const Duration _maxReconnectDelay = Duration(minutes: 5);
  static const Duration _healthCheckInterval = Duration(minutes: 3);
  static const Duration _connectionTimeout = Duration(seconds: 15);
  static const int _maxReconnectAttempts = 10;

  // Internal state management
  Timer? _idleRefreshTimer;
  Timer? _healthCheckTimer;
  Timer? _reconnectTimer;
  bool _isIdleActive = false;
  bool _shouldKeepRunning = false;
  int _reconnectAttempts = 0;
  DateTime? _lastSuccessfulConnection;
  DateTime? _lastIdleStart;
  StreamSubscription<ImapEvent>? _eventSubscription;
  Completer<void>? _idleCompleter;

  // Performance metrics
  int _messagesReceived = 0;
  final int _reconnectionCount = 0;
  Duration _totalUptime = Duration.zero;

  MailService? get _mailService {
    try {
      return Get.find<MailService>();
    } catch (e) {
      if (kDebugMode) {
        print('📧 MailService not available: $e');
      }
      return null;
    }
  }

  RealtimeUpdateService get _realtimeService => RealtimeUpdateService.instance;
  ConnectionManager get _connectionManager => ConnectionManager.instance;

  @override
  void onInit() {
    super.onInit();
    if (kDebugMode) {
      print('📧 OptimizedIdleService initialized');
    }
  }

  /// Start optimized IDLE service with intelligent connection management
  Future<void> startOptimizedIdle() async {
    if (_shouldKeepRunning) {
      if (kDebugMode) {
        print('📧 IDLE service already running');
      }
      return;
    }

    _shouldKeepRunning = true;
    _reconnectAttempts = 0;
    _lastIdleStart = DateTime.now();
    
    if (kDebugMode) {
      print('📧 🚀 Starting optimized IDLE service');
    }

    // Start health monitoring
    _startHealthMonitoring();
    
    // Start main IDLE loop
    unawaited(_runIdleLoop());
  }

  /// Stop IDLE service and cleanup resources
  Future<void> stopOptimizedIdle() async {
    if (kDebugMode) {
      print('📧 🛑 Stopping optimized IDLE service');
    }

    _shouldKeepRunning = false;
    _isIdleActive = false;

    // Cancel all timers
    _idleRefreshTimer?.cancel();
    _healthCheckTimer?.cancel();
    _reconnectTimer?.cancel();
    
    // Cancel event subscription
    await _eventSubscription?.cancel();
    _eventSubscription = null;

    // Complete any pending IDLE operation
    _idleCompleter?.complete();
    _idleCompleter = null;

    // Calculate total uptime
    if (_lastIdleStart != null) {
      _totalUptime += DateTime.now().difference(_lastIdleStart!);
    }

    if (kDebugMode) {
      print('📧 📊 IDLE service stopped. Stats: ${_getPerformanceStats()}');
    }
  }

  /// Main IDLE loop with intelligent reconnection and error handling
  Future<void> _runIdleLoop() async {
    while (_shouldKeepRunning) {
      try {
        await _ensureConnection();
        await _startIdleSession();
        
        // Reset reconnect attempts on successful session
        _reconnectAttempts = 0;
        _lastSuccessfulConnection = DateTime.now();
        
        if (kDebugMode) {
          print('📧 ✅ IDLE session completed successfully');
        }
        
      } catch (e) {
        if (kDebugMode) {
          print('📧 ❌ IDLE loop error: $e');
        }
        
        if (_shouldKeepRunning) {
          await _handleConnectionError(e);
        }
      }
    }
  }

  /// Ensure IMAP connection is established and healthy using ConnectionManager
  Future<void> _ensureConnection() async {
    try {
      // Use connection manager for intelligent connection handling
      final isConnected = await _connectionManager.connect();
      
      if (!isConnected) {
        throw Exception('Failed to establish connection via ConnectionManager');
      }

      final mailService = _mailService;
      if (mailService == null) {
        throw Exception('MailService not available');
      }

      // Ensure inbox is selected for IDLE
      final selectedMailbox = mailService.client.selectedMailbox;
      if (selectedMailbox == null || !selectedMailbox.isInbox) {
        final inbox = mailService.client.mailboxes?.firstWhere(
          (mb) => mb.isInbox,
          orElse: () => mailService.client.mailboxes!.first,
        );
        
        if (inbox != null) {
          await mailService.client.selectMailbox(inbox).timeout(_connectionTimeout);
          if (kDebugMode) {
            print('📧 📥 Selected inbox for IDLE monitoring');
          }
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('📧 ❌ Connection establishment failed: $e');
      }
      rethrow;
    }
  }

  /// Verify connection health with a lightweight operation

  /// Start polling session for real-time updates (v2.1.7 compatible)
  Future<void> _startIdleSession() async {
    final mailService = _mailService;
    if (mailService == null || !_shouldKeepRunning) return;

    try {
      if (kDebugMode) {
        print('📧 ⏳ Starting polling session for real-time updates');
      }

      _isIdleActive = true;
      _idleCompleter = Completer<void>();

      // Set up event listener before starting polling
      _setupEventListener();

      // Set up refresh timer to prevent server timeout
      _scheduleIdleRefresh();

      // Start polling mode - this is compatible with v2.1.7
      await mailService.client.startPolling(const Duration(seconds: 30));
      
      // Wait for polling to complete (either by server event or our refresh)
      await _idleCompleter!.future.timeout(
        _idleTimeout + const Duration(seconds: 30), // Extra buffer
        onTimeout: () {
          if (kDebugMode) {
            print('📧 ⏰ Polling session timed out, will refresh');
          }
        },
      );
      
    } catch (e) {
      _isIdleActive = false;
      if (kDebugMode) {
        print('📧 ❌ Polling session error: $e');
      }
      rethrow;
    } finally {
      _isIdleActive = false;
      _idleRefreshTimer?.cancel();
      
      // Properly stop polling if it's still active
      try {
        final mailService = _mailService;
        if (mailService?.client.isConnected == true) {
          // Use stopPolling() for v2.1.7 compatibility
          await mailService!.client.stopPolling();
        }
      } catch (e) {
        if (kDebugMode) {
          print('📧 ⚠️ Error stopping polling: $e');
        }
      }
    }
  }

  /// Set up event listener for IMAP events during IDLE
  void _setupEventListener() {
    final mailService = _mailService;
    if (mailService == null) return;

    // Cancel existing subscription
    _eventSubscription?.cancel();

    // Listen for IMAP events
    _eventSubscription = mailService.client.eventBus.on<ImapEvent>().listen(
      (event) async {
        try {
          await _handleImapEvent(event);
        } catch (e) {
          if (kDebugMode) {
            print('📧 ❌ Error handling IMAP event: $e');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('📧 ❌ IMAP event stream error: $error');
        }
      },
    );
  }

  /// Handle IMAP events with proper error handling and performance tracking
  Future<void> _handleImapEvent(ImapEvent event) async {
    if (!_shouldKeepRunning) return;

    if (kDebugMode) {
      print('📧 📨 Received IMAP event: ${event.runtimeType}');
    }

    try {
      // Handle different event types based on their string representation
      // This is more compatible with different versions of enough_mail
      final eventType = event.runtimeType.toString();
      
      if (eventType.contains('MessagesAdded') ||
          eventType.contains('NewMessage') ||
          eventType.contains('Exist') || // e.g., ImapMessagesExistEvent/Exists
          eventType.contains('Exists') ||
          eventType.contains('Recent')) {
        await _handleNewMessagesGeneric(event);
      } else if (eventType.contains('Flags') || eventType.contains('FlagChanged')) {
        await _handleFlagChangesGeneric(event);
      } else if (eventType.contains('Deleted') || eventType.contains('Expunge')) {
        await _handleDeletedMessagesGeneric(event);
      } else if (eventType.contains('ConnectionLost') || eventType.contains('Disconnect')) {
        await _handleConnectionLost();
      } else {
        if (kDebugMode) {
          print('📧 ℹ️ Unhandled IMAP event: $eventType');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 ❌ Error processing IMAP event ${event.runtimeType}: $e');
      }
    }
  }

  /// Handle new messages with generic event handling
  Future<void> _handleNewMessagesGeneric(ImapEvent event) async {
    try {
      _messagesReceived += 1; // Increment counter
      
      if (kDebugMode) {
        print('📧 📬 New message event detected');
      }

      // Trigger a refresh of the mailbox to get new messages
      // This is a safer approach than trying to parse specific event data
      await _triggerMailboxRefresh();
      
    } catch (e) {
      if (kDebugMode) {
        print('📧 ❌ Error handling new messages: $e');
      }
    }
  }

  /// Handle flag changes with generic event handling
  Future<void> _handleFlagChangesGeneric(ImapEvent event) async {
    try {
      if (kDebugMode) {
        print('📧 🏷️ Flag change event detected');
      }

      // Trigger a refresh to update message flags
      await _triggerMailboxRefresh();
      
    } catch (e) {
      if (kDebugMode) {
        print('📧 ❌ Error handling flag changes: $e');
      }
    }
  }

  /// Handle deleted messages with generic event handling
  Future<void> _handleDeletedMessagesGeneric(ImapEvent event) async {
    try {
      if (kDebugMode) {
        print('📧 🗑️ Message deletion event detected');
      }

      // Trigger a refresh to update the message list
      await _triggerMailboxRefresh();
      
    } catch (e) {
      if (kDebugMode) {
        print('📧 ❌ Error handling deleted messages: $e');
      }
    }
  }

  /// Trigger mailbox refresh through the realtime service
  Future<void> _triggerMailboxRefresh() async {
    try {
      if (kDebugMode) {
        print('📧 ✅ Triggered mailbox refresh via notifyNewMessages');
      }
      
      // Use the public method to notify about potential new messages
      // This will trigger a refresh of the mailbox
      await _realtimeService.notifyNewMessages([]);
      
    } catch (e) {
      if (kDebugMode) {
        print('📧 ❌ Error triggering mailbox refresh: $e');
      }
    }
  }

  /// Handle connection lost event
  Future<void> _handleConnectionLost() async {
    if (kDebugMode) {
      print('📧 🔌 IMAP connection lost, triggering reconnection');
    }
    
    _isIdleActive = false;
    _idleRefreshTimer?.cancel();
    
    // Complete the IDLE session to trigger reconnection
    _idleCompleter?.complete();
    
    // Trigger reconnection by throwing an exception
    throw Exception('Connection lost - will reconnect');
  }

  /// Schedule IDLE refresh to prevent server timeout
  void _scheduleIdleRefresh() {
    _idleRefreshTimer?.cancel();
    _idleRefreshTimer = Timer(_idleTimeout, () {
      if (_isIdleActive && _shouldKeepRunning) {
        if (kDebugMode) {
          print('📧 🔄 Refreshing IDLE session to prevent timeout');
        }
        _idleCompleter?.complete();
      }
    });
  }

  /// Handle connection errors with smart exponential backoff
  Future<void> _handleConnectionError(dynamic error) async {
    if (!_shouldKeepRunning) return;

    _reconnectAttempts++;
    _isIdleActive = false;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        print('📧 🚫 Max reconnection attempts reached, stopping IDLE service');
      }
      _shouldKeepRunning = false;
      return;
    }

    // Smart exponential backoff with jitter
    final baseDelay = _initialReconnectDelay.inMilliseconds;
    final exponentialDelay = baseDelay * pow(2, _reconnectAttempts - 1).toInt();
    final cappedDelay = min(exponentialDelay, _maxReconnectDelay.inMilliseconds);
    
    // Add jitter to prevent thundering herd
    final jitter = Random().nextInt(1000); // 0-1 second jitter
    final totalDelay = cappedDelay + jitter;
    
    final delayDuration = Duration(milliseconds: totalDelay);

    if (kDebugMode) {
      print('📧 ⏳ Reconnection attempt $_reconnectAttempts in ${delayDuration.inSeconds}s (error: ${error.toString().substring(0, min(50, error.toString().length))})');
    }

    await Future.delayed(delayDuration);
  }

  /// Start health monitoring for proactive connection management
  void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      if (_shouldKeepRunning) {
        unawaited(_performHealthCheck());
      }
    });
  }

  /// Perform proactive health check using ConnectionManager
  Future<void> _performHealthCheck() async {
    if (!_shouldKeepRunning || _isIdleActive) return;

    try {
      // Use connection manager's health monitoring
      if (!_connectionManager.isHealthy) {
        if (kDebugMode) {
          print('📧 ⚠️ Connection manager reports unhealthy connection');
        }
        
        // Trigger reconnection through connection manager
        await _connectionManager.forceReconnect();
      } else {
        if (kDebugMode) {
          print('📧 ✅ Health check passed via ConnectionManager');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 ⚠️ Health check failed: $e');
      }
    }
  }

  /// Get comprehensive service status and performance metrics
  Map<String, dynamic> getStatus() {
    final uptime = _lastIdleStart != null 
        ? _totalUptime + DateTime.now().difference(_lastIdleStart!)
        : _totalUptime;
        
    return {
      'isRunning': _shouldKeepRunning,
      'isIdleActive': _isIdleActive,
      'reconnectAttempts': _reconnectAttempts,
      'lastSuccessfulConnection': _lastSuccessfulConnection?.toIso8601String(),
      'isConnected': _mailService?.client.isConnected ?? false,
      'performance': _getPerformanceStats(),
      'uptime': uptime.toString(),
      'connectionManager': _connectionManager.getConnectionStats(),
    };
  }

  /// Get performance statistics
  Map<String, dynamic> _getPerformanceStats() {
    final uptime = _lastIdleStart != null 
        ? _totalUptime + DateTime.now().difference(_lastIdleStart!)
        : _totalUptime;
        
    return {
      'messagesReceived': _messagesReceived,
      'reconnectionCount': _reconnectionCount,
      'uptimeHours': uptime.inHours,
      'messagesPerHour': uptime.inHours > 0 ? (_messagesReceived / uptime.inHours).toStringAsFixed(2) : '0',
'reliability': _reconnectionCount > 0 ? '${(uptime.inMinutes / _reconnectionCount).toStringAsFixed(2)} min/reconnect' : 'Perfect',
    };
  }

  /// Restart the IDLE service (useful for configuration changes)
  Future<void> restartIdleService() async {
    if (kDebugMode) {
      print('📧 🔄 Restarting IDLE service');
    }
    
    await stopOptimizedIdle();
    await Future.delayed(const Duration(seconds: 1));
    await startOptimizedIdle();
  }

  @override
  void onClose() {
    stopOptimizedIdle();
    super.onClose();
  }
}

/// Helper function for fire-and-forget async operations
void unawaited(Future<void> future) {
  future.catchError((error) {
    if (kDebugMode) {
      print('📧 ⚠️ Unawaited future error: $error');
    }
  });
}

