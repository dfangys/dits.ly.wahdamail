import 'dart:async';
import 'dart:convert';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Single definition of storage class to avoid ambiguous imports
class MailboxStorage {
  final MailAccount mailAccount;
  final Mailbox mailbox;
  late Box<Uint8List> _messageBox;
  late Box<Map> _envelopeBox;
  
  // ValueNotifier for UI updates
  late ValueNotifier<Box<Map>> dataStream;
  
  MailboxStorage({
    required this.mailAccount,
    required this.mailbox,
  });

  // Initialize storage
  Future<void> init() async {
    final String boxName = '${mailAccount.email}_${mailbox.path}_messages';
    final String envelopeBoxName = '${mailAccount.email}_${mailbox.path}_envelopes';
    
    try {
      _messageBox = await Hive.openBox<Uint8List>(boxName);
      _envelopeBox = await Hive.openBox<Map>(envelopeBoxName);
      dataStream = ValueNotifier<Box<Map>>(_envelopeBox);
    } catch (e) {
      if (kDebugMode) {
        print('Error opening Hive boxes: $e');
      }
      // Try to recover by deleting and recreating the boxes
      await Hive.deleteBoxFromDisk(boxName);
      await Hive.deleteBoxFromDisk(envelopeBoxName);
      _messageBox = await Hive.openBox<Uint8List>(boxName);
      _envelopeBox = await Hive.openBox<Map>(envelopeBoxName);
      dataStream = ValueNotifier<Box<Map>>(_envelopeBox);
    }
  }

  // Save message envelopes to storage
  Future<void> saveMessageEnvelopes(List<MimeMessage> messages) async {
    for (final message in messages) {
      if (message.sequenceId != null) {
        final key = 'seq_${message.sequenceId}';
        final envelope = _createEnvelopeMap(message);
        await _envelopeBox.put(key, envelope);
      }
    }
    // Notify listeners
    dataStream.value = _envelopeBox;
  }

  // Save full message content to storage
  Future<void> saveMessage(MimeMessage message) async {
    if (message.sequenceId == null) return;
    
    try {
      final key = 'seq_${message.sequenceId}';
      
      // Save envelope data
      final envelope = _createEnvelopeMap(message);
      await _envelopeBox.put(key, envelope);
      
      // Save full message content if available
      final mimeData = message.mimeData;
      if (mimeData != null) {
        final bytes = Uint8List.fromList(utf8.encode(mimeData.toString()));
        await _messageBox.put(key, bytes);
      }
      
      // Notify listeners
      dataStream.value = _envelopeBox;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving message: $e');
      }
    }
  }

  // Get cached message by sequence ID
  Future<MimeMessage?> getMessage(int sequenceId) async {
    final key = 'seq_$sequenceId';
    final Uint8List? data = _messageBox.get(key);
    
    if (data != null) {
      try {
        final mimeMessage = MimeMessage();
        mimeMessage.sequenceId = sequenceId;
        // Set basic properties from envelope
        final envelope = _envelopeBox.get(key);
        if (envelope != null) {
          _applyEnvelopeToMessage(mimeMessage, envelope);
        }
        return mimeMessage;
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing cached message: $e');
        }
        // Remove corrupted data
        await _messageBox.delete(key);
      }
    }
    
    return null;
  }

  // Check if message is cached
  bool isMessageCached(int sequenceId) {
    final key = 'seq_$sequenceId';
    return _messageBox.containsKey(key);
  }

  // Clear all cached data
  Future<void> clear() async {
    await _envelopeBox.clear();
    await _messageBox.clear();
    dataStream.value = _envelopeBox;
  }

  // Create envelope map from message
  Map _createEnvelopeMap(MimeMessage message) {
    return {
      'sequenceId': message.sequenceId,
      'uid': message.uid,
      'subject': message.decodeSubject(),
      'from': message.from?.map((e) => {'email': e.email, 'name': e.personalName}).toList(),
      'date': message.decodeDate()?.millisecondsSinceEpoch,
      'isSeen': message.isSeen,
      'hasAttachments': message.hasAttachments(),
    };
  }

  // Apply envelope data to message
  void _applyEnvelopeToMessage(MimeMessage message, Map envelope) {
    message.sequenceId = envelope['sequenceId'];
    message.uid = envelope['uid'];
    
    // Set seen flag
    if (envelope['isSeen'] == true) {
      message.setFlag(MessageFlags.seen, true);
    }
    
    // Set from
    if (envelope['from'] != null && (envelope['from'] as List).isNotEmpty) {
      final fromList = envelope['from'] as List;
      message.from = fromList.map((f) => 
        MailAddress(f['name'] ?? '', f['email'] ?? '')
      ).toList();
    }
    
    // Set date - using a different approach since setter isn't available
    if (envelope['date'] != null) {
      final timestamp = envelope['date'] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      message.addHeader('Date', date.toIso8601String());
    }
  }
}

// Single adapter for message storage
class MessageStorageAdapter extends TypeAdapter<dynamic> {
  @override
  final int typeId = 1;

  @override
  dynamic read(BinaryReader reader) {
    return null;
  }

  @override
  void write(BinaryWriter writer, dynamic obj) {}
}

// Extension method to convert envelope to MimeMessage
extension EnvelopeToMimeMessage on Map {
  MimeMessage toMimeMessage() {
    final message = MimeMessage();
    message.sequenceId = this['sequenceId'];
    message.uid = this['uid'];
    
    // Set seen flag
    if (this['isSeen'] == true) {
      message.setFlag(MessageFlags.seen, true);
    }
    
    // Set from
    if (this['from'] != null && (this['from'] as List).isNotEmpty) {
      final fromList = this['from'] as List;
      message.from = fromList.map((f) => 
        MailAddress(f['name'] ?? '', f['email'] ?? '')
      ).toList();
    }
    
    // Set date - using a different approach since setter isn't available
    if (this['date'] != null) {
      final timestamp = this['date'] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      message.addHeader('Date', date.toIso8601String());
    }
    
    return message;
  }
}
