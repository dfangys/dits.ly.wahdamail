# 📡 API Documentation

This document provides comprehensive information about the Wahda Bank Email Client APIs, services, and data models.

## 🏗️ Core Services

### MailService

The main service for email operations using IMAP/SMTP protocols.

```dart
class MailService extends GetxService {
  // Connection management
  Future<void> connect() async
  Future<void> disconnect() async
  bool get isConnected
  
  // Account management
  MailAccount get account
  Future<void> setAccount(MailAccount account) async
  
  // Email operations
  Future<List<MimeMessage>> fetchMessages(Mailbox mailbox, {int count = 20}) async
  Future<void> sendMessage(MimeMessage message) async
  Future<void> deleteMessage(MimeMessage message) async
  Future<void> markAsRead(MimeMessage message) async
  Future<void> markAsUnread(MimeMessage message) async
}
```

#### Usage Example

```dart
final mailService = Get.find<MailService>();

// Connect to email server
await mailService.connect();

// Fetch latest emails
final messages = await mailService.fetchMessages(
  mailbox, 
  count: 50
);

// Send an email
final message = MimeMessage()
  ..setHeader('to', 'recipient@example.com')
  ..setHeader('subject', 'Hello World')
  ..text = 'This is a test email';
  
await mailService.sendMessage(message);
```

### CacheManager

Advanced caching system for optimal performance.

```dart
class CacheManager {
  static CacheManager get instance
  
  // Message caching
  Future<void> cacheMessage(String key, MimeMessage message) async
  MimeMessage? getCachedMessage(String key)
  
  // Mailbox caching
  Future<void> cacheMailbox(String key, List<MimeMessage> messages) async
  List<MimeMessage>? getCachedMailbox(String key)
  
  // Attachment caching
  Future<void> cacheAttachment(String key, Uint8List data) async
  Uint8List? getCachedAttachment(String key)
  
  // Cache management
  void clearCache()
  Map<String, dynamic> getCacheStats()
}
```

### RealtimeUpdateService

Real-time email synchronization and UI updates.

```dart
class RealtimeUpdateService {
  static RealtimeUpdateService get instance
  
  // Real-time operations
  Future<void> markMessageAsRead(MimeMessage message) async
  Future<void> markMessageAsUnread(MimeMessage message) async
  Future<void> flagMessage(MimeMessage message) async
  Future<void> unflagMessage(MimeMessage message) async
  Future<void> deleteMessage(MimeMessage message) async
  
  // Update streams
  Stream<MailboxUpdate> get mailboxUpdates
  Stream<MessageUpdate> get messageUpdates
}
```

## 🎛️ Controllers

### MailBoxController

Main controller for email management and mailbox operations.

```dart
class MailBoxController extends GetxController {
  // Observables
  RxBool get isBusy
  RxBool get isBoxBusy
  RxList<Mailbox> get mailboxes
  Mailbox? get currentMailbox
  
  // Email operations
  Future<void> loadEmailsForBox(Mailbox mailbox) async
  Future<void> refreshMailbox(Mailbox mailbox) async
  Future<void> loadMoreEmails(Mailbox mailbox, int page) async
  
  // Navigation
  Future<void> navigatToMailBox(Mailbox mailbox) async
  
  // Mailbox management
  Future<void> loadMailBoxes() async
  Future<void> initInbox() async
}
```

#### Key Methods

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `loadEmailsForBox` | Load emails for specific mailbox | `Mailbox mailbox` | `Future<void>` |
| `refreshMailbox` | Refresh mailbox content | `Mailbox mailbox` | `Future<void>` |
| `loadMoreEmails` | Load additional emails (pagination) | `Mailbox mailbox, int page` | `Future<void>` |
| `navigatToMailBox` | Navigate to specific mailbox | `Mailbox mailbox` | `Future<void>` |

### SettingController

Manages application settings and user preferences.

```dart
class SettingController extends GetxController {
  // UI Settings
  RxString get language
  RxBool get readReceipts
  
  // Swipe Gestures
  RxString get swipeGesturesLTR  // Left-to-Right swipe action
  RxString get swipeGesturesRTL  // Right-to-Left swipe action
  
  // Security Settings
  RxBool get appLock
  RxString get lockMethod
  RxString get autoLockTiming
  RxBool get hideNotificationContent
  RxBool get blockRemoteImages
  
  // Signature Settings
  RxString get signature
  RxBool get signatureReply
  RxBool get signatureForward
  RxBool get signatureNewMessage
}
```

#### Swipe Gesture Actions

| Action | Description | Icon | Color |
|--------|-------------|------|-------|
| `read_unread` | Mark as read/unread | `Icons.mark_email_read` | Blue |
| `flag` | Flag/unflag message | `Icons.flag` | Orange |
| `delete` | Delete message | `Icons.delete` | Red |
| `archive` | Archive message | `Icons.archive` | Green |

## 📊 Data Models

### MimeMessage

Core email message model from `enough_mail` package.

```dart
class MimeMessage {
  // Headers
  String? get subject
  List<MailAddress>? get from
  List<MailAddress>? get to
  List<MailAddress>? get cc
  List<MailAddress>? get bcc
  DateTime? get date
  
  // Content
  String? get text
  String? get html
  List<ContentInfo> get attachments
  
  // Flags
  bool get isSeen
  bool get isFlagged
  bool get isDeleted
  bool get isDraft
  
  // Identifiers
  int? get uid
  int? get sequenceId
}
```

### DraftModel

Local draft storage model.

```dart
class DraftModel {
  int? id
  List<String> to
  List<String> cc
  List<String> bcc
  String subject
  String body
  bool isHtml
  DateTime createdAt
  DateTime updatedAt
  
  // Serialization
  Map<String, dynamic> toJson()
  factory DraftModel.fromJson(Map<String, dynamic> json)
}
```

### Mailbox

Email mailbox/folder model.

```dart
class Mailbox {
  String name
  String encodedName
  String path
  String encodedPath
  List<MailboxFlag> flags
  int messagesExists
  int messagesRecent
  int messagesUnseen
  int? uidNext
  int? uidValidity
  
  // Helper properties
  bool get isInbox
  bool get isSent
  bool get isDrafts
  bool get isTrash
  bool get isSpam
}
```

## 🔄 State Management

### GetX Observables

The app uses GetX for reactive state management:

```dart
// Reactive variables
RxBool isLoading = false.obs;
RxList<MimeMessage> emails = <MimeMessage>[].obs;
RxString currentMailboxName = ''.obs;

// Computed properties
bool get hasEmails => emails.isNotEmpty;
int get emailCount => emails.length;

// Reactive updates
void updateEmails(List<MimeMessage> newEmails) {
  emails.assignAll(newEmails);
}
```

### Dependency Injection

Services are registered using GetX dependency injection:

```dart
// In HomeBinding
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Core services
    Get.put<MailService>(MailService(), permanent: true);
    Get.put<CacheManager>(CacheManager(), permanent: true);
    Get.put<RealtimeUpdateService>(RealtimeUpdateService(), permanent: true);
    
    // Controllers
    Get.lazyPut<MailBoxController>(() => MailBoxController());
    Get.lazyPut<SettingController>(() => SettingController());
  }
}
```

## 🗄️ Database Schema

### SQLite Tables

#### Messages Table
```sql
CREATE TABLE messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uid INTEGER,
  sequence_id INTEGER,
  mailbox_name TEXT,
  subject TEXT,
  sender TEXT,
  recipients TEXT,
  date_received INTEGER,
  is_seen INTEGER DEFAULT 0,
  is_flagged INTEGER DEFAULT 0,
  is_deleted INTEGER DEFAULT 0,
  is_draft INTEGER DEFAULT 0,
  body_text TEXT,
  body_html TEXT,
  raw_message BLOB
);
```

#### Drafts Table
```sql
CREATE TABLE drafts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  to_addresses TEXT,
  cc_addresses TEXT,
  bcc_addresses TEXT,
  subject TEXT,
  body TEXT,
  is_html INTEGER DEFAULT 0,
  created_at INTEGER,
  updated_at INTEGER
);
```

#### Attachments Table
```sql
CREATE TABLE attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id INTEGER,
  filename TEXT,
  content_type TEXT,
  size INTEGER,
  data BLOB,
  FOREIGN KEY (message_id) REFERENCES messages (id)
);
```

## 🔌 API Endpoints

### Email Server Configuration

#### IMAP Settings
```dart
final imapConfig = ImapServerConfig(
  hostname: 'imap.gmail.com',
  port: 993,
  isSecure: true,
  username: 'user@gmail.com',
  password: 'app-password',
);
```

#### SMTP Settings
```dart
final smtpConfig = SmtpServerConfig(
  hostname: 'smtp.gmail.com',
  port: 587,
  isSecure: false,
  username: 'user@gmail.com',
  password: 'app-password',
);
```

### Common Email Providers

| Provider | IMAP Server | IMAP Port | SMTP Server | SMTP Port |
|----------|-------------|-----------|-------------|-----------|
| **Gmail** | imap.gmail.com | 993 (SSL) | smtp.gmail.com | 587 (TLS) |
| **Outlook** | outlook.office365.com | 993 (SSL) | smtp-mail.outlook.com | 587 (TLS) |
| **Yahoo** | imap.mail.yahoo.com | 993 (SSL) | smtp.mail.yahoo.com | 587 (TLS) |
| **iCloud** | imap.mail.me.com | 993 (SSL) | smtp.mail.me.com | 587 (TLS) |

## 🔒 Security

### Authentication

```dart
// OAuth2 Authentication (Gmail)
final oauth2Token = await GoogleSignIn().signIn();
final accessToken = await oauth2Token.authentication.accessToken;

// App Password Authentication
final credentials = PlainAuthentication(
  username: 'user@gmail.com',
  password: 'app-specific-password',
);
```

### Data Encryption

```dart
// Local data encryption
final encryptedData = await SecurityService.encrypt(sensitiveData);
final decryptedData = await SecurityService.decrypt(encryptedData);

// Secure storage
await SecureStorage.write(key: 'email_password', value: password);
final password = await SecureStorage.read(key: 'email_password');
```

## 📈 Performance Optimization

### Caching Strategy

1. **L1 Cache**: In-memory cache for frequently accessed data
2. **L2 Cache**: SQLite database for persistent storage
3. **L3 Cache**: File system cache for large attachments

### Memory Management

```dart
// Automatic cleanup
Timer.periodic(Duration(minutes: 5), (timer) {
  CacheManager.instance.cleanup();
  GarbageCollector.collect();
});

// Memory monitoring
final memoryUsage = await MemoryMonitor.getCurrentUsage();
if (memoryUsage > threshold) {
  await CacheManager.instance.clearOldEntries();
}
```

## 🐛 Error Handling

### Common Error Types

```dart
// Network errors
try {
  await mailService.connect();
} on SocketException {
  // Handle network connectivity issues
} on TimeoutException {
  // Handle connection timeouts
} on MailException {
  // Handle email-specific errors
}

// Authentication errors
try {
  await mailService.authenticate(credentials);
} on AuthenticationException {
  // Handle invalid credentials
} on SecurityException {
  // Handle security-related issues
}
```

### Error Recovery

```dart
// Automatic retry with exponential backoff
Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  for (int attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await operation();
    } catch (e) {
      if (attempt == maxRetries - 1) rethrow;
      await Future.delayed(initialDelay * (1 << attempt));
    }
  }
  throw StateError('This should never be reached');
}
```

## 📊 Monitoring & Analytics

### Performance Metrics

```dart
// Track email loading performance
final stopwatch = Stopwatch()..start();
await mailService.fetchMessages(mailbox);
stopwatch.stop();

Analytics.track('email_load_time', {
  'duration_ms': stopwatch.elapsedMilliseconds,
  'message_count': messages.length,
  'mailbox': mailbox.name,
});
```

### Error Tracking

```dart
// Crash reporting
try {
  await riskyOperation();
} catch (error, stackTrace) {
  CrashReporting.recordError(
    error,
    stackTrace,
    context: {'operation': 'email_sync'},
  );
}
```

---

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [GetX Documentation](https://github.com/jonataslaw/getx)
- [enough_mail Package](https://pub.dev/packages/enough_mail)
- [Material Design 3](https://m3.material.io/)

For more detailed examples and advanced usage, see the [Development Guide](DEVELOPMENT.md).

