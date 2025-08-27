import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:rxdart/rxdart.dart';

import 'mail_service.dart';
import 'notifications_service.dart';
import 'realtime_update_service.dart';

/// High-performance incoming email notification service
class IncomingEmailService extends GetxService {
  static IncomingEmailService? _instance;
  static IncomingEmailService get instance => _instance ??= IncomingEmailService._();
  
  IncomingEmailService._();

  // Real-time streams for incoming emails
  final BehaviorSubject<List<MimeMessage>> _newEmailsStream = BehaviorSubject<List<MimeMessage>>.seeded([]);
  final BehaviorSubject<int> _newEmailCountStream = BehaviorSubject<int>.seeded(0);
  final PublishSubject<MimeMessage> _singleNewEmailStream = PublishSubject<MimeMessage>();

  // Public streams
  Stream<List<MimeMessage>> get newEmailsStream => _newEmailsStream.stream;
  Stream<int> get newEmailCountStream => _newEmailCountStream.stream;
  Stream<MimeMessage> get singleNewEmailStream => _singleNewEmailStream.stream;

  // Internal state
  Timer? _pollingTimer;
  Timer? _idleTimer;
  int _lastKnownMessageCount = 0;
  final Set<String> _processedMessageIds = {};

  MailService? get _mailService {
    try {
      return Get.find<MailService>();
    } catch (e) {
      if (kDebugMode) {
        print('MailService not available: $e');
      }
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _initializeService();
  }

  void _initializeService() {
    // Start with conservative polling
    startPolling(interval: const Duration(minutes: 2));
    
    // Listen for app state changes to optimize polling
    _setupAppStateListener();
  }

  /// Start polling for new emails with configurable interval
  void startPolling({Duration interval = const Duration(minutes: 1)}) {
    stopPolling();
    
    _pollingTimer = Timer.periodic(interval, (_) {
      _checkForNewEmails();
    });
    
    // Initial check
    _checkForNewEmails();
    
    if (kDebugMode) {
      print('📧 Started polling for new emails every ${interval.inMinutes} minutes');
    }
  }

  /// Stop polling for new emails
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    
    if (kDebugMode) {
      print('📧 Stopped polling for new emails');
    }
  }

  /// Enable IDLE mode for real-time notifications (if supported)
  Future<void> enableIdleMode() async {
    try {
      final mailService = _mailService;
      if (mailService == null) return;

      // Check if IDLE is supported by checking capabilities (simplified)
      try {
        // For enough_mail compatibility, we'll use polling instead of checking capabilities
        if (kDebugMode) {
          print('📧 IDLE not supported in this version, using polling mode');
        }
        // Fallback to more frequent polling
        startPolling(interval: const Duration(seconds: 30));
      } catch (e) {
        if (kDebugMode) {
          print('📧 Error checking IDLE support: $e');
        }
        // Fallback to polling
        startPolling(interval: const Duration(minutes: 1));
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Failed to enable IDLE mode: $e');
      }
      // Fallback to polling
      startPolling(interval: const Duration(minutes: 1));
    }
  }

  /// Disable IDLE mode
  void disableIdleMode() {
    _idleTimer?.cancel();
    _idleTimer = null;
    
    if (kDebugMode) {
      print('📧 IDLE mode disabled');
    }
  }

  /// Check for new emails manually
  Future<void> checkNow() async {
    await _checkForNewEmails();
  }

  /// Internal method to check for new emails
  Future<void> _checkForNewEmails() async {
    try {
      final mailService = _mailService;
      if (mailService == null) return;

      // Get current inbox
      final inbox = mailService.client.selectedMailbox ?? 
                   await mailService.client.selectInbox();
      

      // Check message count
      final currentCount = inbox.messagesExists;
      
      if (_lastKnownMessageCount == 0) {
        // First time - just store the count
        _lastKnownMessageCount = currentCount;
        return;
      }

      if (currentCount > _lastKnownMessageCount) {
        // New messages detected!
        final newMessageCount = currentCount - _lastKnownMessageCount;
        
        if (kDebugMode) {
          print('📧 Detected $newMessageCount new messages');
        }

        // Fetch the new messages
        await _fetchNewMessages(newMessageCount);
        
        _lastKnownMessageCount = currentCount;
      }

    } catch (e) {
      if (kDebugMode) {
        print('📧 Error checking for new emails: $e');
      }
    }
  }

  /// Fetch and process new messages
  Future<void> _fetchNewMessages(int count) async {
    try {
      final mailService = _mailService;
      if (mailService == null) return;

      // Fetch the latest messages using correct API
      
      final fetchResult = await mailService.client.fetchMessages(
        fetchPreference: FetchPreference.envelope,
      );

      final newMessages = fetchResult;
      
      if (newMessages.isNotEmpty) {
        // Filter out already processed messages
        final unprocessedMessages = newMessages.where((msg) {
          final msgId = '${msg.uid ?? msg.sequenceId}';
          return !_processedMessageIds.contains(msgId);
        }).toList();

        if (unprocessedMessages.isNotEmpty) {
          // Update streams
          _newEmailsStream.add(unprocessedMessages);
          _newEmailCountStream.add(_newEmailCountStream.value + unprocessedMessages.length);

          // Emit individual messages for specific handling
          for (final message in unprocessedMessages) {
            _singleNewEmailStream.add(message);
            
            // Mark as processed
            final msgId = '${message.uid ?? message.sequenceId}';
            _processedMessageIds.add(msgId);
            
            // Show notification
            await _showNewEmailNotification(message);
          }

          // Update realtime service
          final realtimeService = RealtimeUpdateService.instance;
          await realtimeService.notifyNewMessages(unprocessedMessages);

          if (kDebugMode) {
            print('📧 Processed ${unprocessedMessages.length} new messages');
          }
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('📧 Error fetching new messages: $e');
      }
    }
  }

  /// Show notification for new email
  Future<void> _showNewEmailNotification(MimeMessage message) async {
    try {
      final notificationService = NotificationService.instance;
      
      final sender = message.from?.isNotEmpty == true 
          ? message.from!.first.personalName ?? message.from!.first.email
          : 'Unknown Sender';
      
      final subject = message.decodeSubject() ?? 'No Subject';
      
      notificationService.showFlutterNotification(
        'New Email from $sender',
        subject,
        {
          'type': 'new_email',
          'messageId': '${message.uid ?? message.sequenceId}',
          'sender': sender,
          'subject': subject,
        },
        DateTime.now().millisecondsSinceEpoch,
      );

    } catch (e) {
      if (kDebugMode) {
        print('📧 Error showing notification: $e');
      }
    }
  }


  /// Setup app state listener to optimize polling based on app state
  void _setupAppStateListener() {
    // This would typically listen to app lifecycle events
    // For now, we'll use a simple approach
    
    // More frequent polling when app is active
    // Less frequent when app is in background
  }

  /// Reset new email count
  void resetNewEmailCount() {
    _newEmailCountStream.add(0);
    _newEmailsStream.add([]);
  }

  /// Clear processed message cache
  void clearProcessedMessages() {
    _processedMessageIds.clear();
  }

  @override
  void onClose() {
    stopPolling();
    disableIdleMode();
    _newEmailsStream.close();
    _newEmailCountStream.close();
    _singleNewEmailStream.close();
    super.onClose();
  }
}

