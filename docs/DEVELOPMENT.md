# 🛠️ Development Guide

This guide provides comprehensive information for developers working on the Wahda Bank Email Client project.

## 📋 Table of Contents

- [Development Environment](#development-environment)
- [Project Setup](#project-setup)
- [Development Workflow](#development-workflow)
- [Code Standards](#code-standards)
- [Testing Guidelines](#testing-guidelines)
- [Debugging](#debugging)
- [Performance Optimization](#performance-optimization)
- [Common Issues](#common-issues)

## 💻 Development Environment

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| **Flutter SDK** | 3.24.3+ | Framework |
| **Dart SDK** | 3.5.3+ | Programming language |
| **Android Studio** | 2023.1+ | IDE (recommended) |
| **VS Code** | 1.80+ | Alternative IDE |
| **Git** | 2.30+ | Version control |
| **Node.js** | 18+ | Web development |

### IDE Setup

#### Android Studio
```bash
# Install Flutter plugin
# File → Settings → Plugins → Flutter

# Configure SDK paths
# File → Settings → Languages & Frameworks → Flutter
# Set Flutter SDK path: /path/to/flutter
```

#### VS Code Extensions
```json
{
  "recommendations": [
    "dart-code.flutter",
    "dart-code.dart-code",
    "ms-vscode.vscode-json",
    "bradlc.vscode-tailwindcss",
    "usernamehw.errorlens"
  ]
}
```

### Environment Configuration

Create `.env` file in project root:
```env
# Development
DEBUG_MODE=true
LOG_LEVEL=debug

# API Configuration
API_BASE_URL=https://dev-api.wahdabank.com
API_TIMEOUT=30000

# Features
ENABLE_ANALYTICS=false
ENABLE_CRASH_REPORTING=true
ENABLE_DEBUG_TOOLS=true

# Email Testing
TEST_EMAIL_PROVIDER=gmail
TEST_IMAP_SERVER=imap.gmail.com
TEST_SMTP_SERVER=smtp.gmail.com
```

## 🚀 Project Setup

### 1. Clone and Setup

```bash
# Clone repository
git clone https://github.com/dfangys/dits.ly.wahdamail.git
cd dits.ly.wahdamail

# Switch to development branch
git checkout final-fixes

# Install dependencies
flutter pub get

# Generate code (if needed)
flutter packages pub run build_runner build
```

### 2. Platform-specific Setup

#### Android
```bash
# Accept licenses
flutter doctor --android-licenses

# Create keystore for signing
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

#### iOS
```bash
# Install CocoaPods
sudo gem install cocoapods

# Install iOS dependencies
cd ios && pod install && cd ..

# Open in Xcode for signing setup
open ios/Runner.xcworkspace
```

#### Web
```bash
# Enable web support
flutter config --enable-web

# Install web dependencies
flutter pub get
```

### 3. Database Setup

```bash
# Initialize SQLite database
flutter packages pub run sqflite:setup

# Run database migrations
flutter packages pub run floor:generate
```

## 🔄 Development Workflow

### Branch Strategy

```
main                    # Production-ready code
├── final-fixes        # Latest stable development
├── feature/email-sync # Feature branches
├── bugfix/cache-issue # Bug fix branches
└── hotfix/security    # Critical fixes
```

### Development Process

1. **Create Feature Branch**
   ```bash
   git checkout final-fixes
   git pull origin final-fixes
   git checkout -b feature/new-feature
   ```

2. **Development Cycle**
   ```bash
   # Make changes
   # Run tests
   flutter test
   
   # Check code quality
   flutter analyze
   
   # Format code
   dart format .
   
   # Commit changes
   git add .
   git commit -m "feat: add new feature"
   ```

3. **Testing & Review**
   ```bash
   # Run all tests
   flutter test --coverage
   
   # Build for all platforms
   flutter build apk
   flutter build ios
   flutter build web
   
   # Push and create PR
   git push origin feature/new-feature
   ```

### Commit Message Convention

```
type(scope): description

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation
- style: Code style changes
- refactor: Code refactoring
- test: Adding tests
- chore: Maintenance

Examples:
feat(email): add swipe gestures for email actions
fix(cache): resolve memory leak in cache manager
docs(api): update API documentation
```

## 📏 Code Standards

### Dart Style Guide

Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines:

```dart
// ✅ Good
class EmailService {
  final String _baseUrl;
  
  EmailService(this._baseUrl);
  
  Future<List<Email>> fetchEmails({
    required String mailbox,
    int limit = 20,
  }) async {
    // Implementation
  }
}

// ❌ Bad
class emailservice {
  String baseUrl;
  
  emailservice(baseUrl) {
    this.baseUrl = baseUrl;
  }
  
  fetchEmails(mailbox, [limit]) async {
    // Implementation
  }
}
```

### File Organization

```dart
// File: lib/services/email_service.dart

// 1. Imports (grouped and sorted)
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/email.dart';
import '../utils/constants.dart';

// 2. Class documentation
/// Service for managing email operations.
/// 
/// Provides methods for fetching, sending, and managing emails
/// across different email providers.
class EmailService extends GetxService {
  // 3. Constants
  static const int _defaultTimeout = 30;
  
  // 4. Private fields
  final String _baseUrl;
  final HttpClient _client;
  
  // 5. Constructor
  EmailService(this._baseUrl) : _client = HttpClient();
  
  // 6. Public methods
  Future<List<Email>> fetchEmails() async {
    // Implementation
  }
  
  // 7. Private methods
  Future<void> _authenticate() async {
    // Implementation
  }
}
```

### Widget Structure

```dart
class EmailListView extends StatefulWidget {
  const EmailListView({
    super.key,
    required this.mailbox,
    this.onEmailTap,
  });
  
  final Mailbox mailbox;
  final ValueChanged<Email>? onEmailTap;
  
  @override
  State<EmailListView> createState() => _EmailListViewState();
}

class _EmailListViewState extends State<EmailListView> {
  late final ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildEmailList(),
    );
  }
  
  Widget _buildEmailList() {
    return GetBuilder<MailBoxController>(
      builder: (controller) => ListView.builder(
        controller: _scrollController,
        itemCount: controller.emails.length,
        itemBuilder: (context, index) => EmailTile(
          email: controller.emails[index],
          onTap: () => widget.onEmailTap?.call(controller.emails[index]),
        ),
      ),
    );
  }
  
  void _onScroll() {
    // Scroll handling logic
  }
}
```

### Error Handling

```dart
// ✅ Comprehensive error handling
Future<List<Email>> fetchEmails() async {
  try {
    final response = await _client.get('/emails').timeout(
      Duration(seconds: _defaultTimeout),
    );
    
    if (response.statusCode == 200) {
      return _parseEmails(response.body);
    } else {
      throw EmailException(
        'Failed to fetch emails: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  } on TimeoutException {
    throw EmailException('Request timeout');
  } on SocketException {
    throw EmailException('Network error');
  } catch (e) {
    logger.e('Unexpected error fetching emails: $e');
    throw EmailException('Unexpected error: $e');
  }
}

// Custom exception class
class EmailException implements Exception {
  final String message;
  final int? statusCode;
  
  const EmailException(this.message, {this.statusCode});
  
  @override
  String toString() => 'EmailException: $message';
}
```

## 🧪 Testing Guidelines

### Test Structure

```
test/
├── unit/                    # Unit tests
│   ├── controllers/
│   │   └── mailbox_controller_test.dart
│   ├── services/
│   │   └── email_service_test.dart
│   └── models/
│       └── email_test.dart
├── widget/                  # Widget tests
│   ├── email_tile_test.dart
│   └── email_list_test.dart
└── integration/             # Integration tests
    ├── email_flow_test.dart
    └── settings_flow_test.dart
```

### Unit Testing

```dart
// test/unit/services/email_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:wahda_bank/services/email_service.dart';
import 'package:wahda_bank/models/email.dart';

@GenerateMocks([HttpClient])
import 'email_service_test.mocks.dart';

void main() {
  group('EmailService', () {
    late EmailService emailService;
    late MockHttpClient mockClient;
    
    setUp(() {
      mockClient = MockHttpClient();
      emailService = EmailService('https://api.example.com', mockClient);
    });
    
    group('fetchEmails', () {
      test('should return list of emails on successful response', () async {
        // Arrange
        final mockResponse = MockHttpResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.body).thenReturn(jsonEncode([
          {'id': '1', 'subject': 'Test Email', 'sender': 'test@example.com'}
        ]));
        when(mockClient.get('/emails')).thenAnswer((_) async => mockResponse);
        
        // Act
        final emails = await emailService.fetchEmails();
        
        // Assert
        expect(emails, isA<List<Email>>());
        expect(emails.length, equals(1));
        expect(emails.first.subject, equals('Test Email'));
        verify(mockClient.get('/emails')).called(1);
      });
      
      test('should throw EmailException on error response', () async {
        // Arrange
        final mockResponse = MockHttpResponse();
        when(mockResponse.statusCode).thenReturn(500);
        when(mockClient.get('/emails')).thenAnswer((_) async => mockResponse);
        
        // Act & Assert
        expect(
          () => emailService.fetchEmails(),
          throwsA(isA<EmailException>()),
        );
      });
    });
  });
}
```

### Widget Testing

```dart
// test/widget/email_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:wahda_bank/widgets/email_tile.dart';
import 'package:wahda_bank/models/email.dart';

void main() {
  group('EmailTile Widget', () {
    late Email testEmail;
    
    setUp(() {
      testEmail = Email(
        id: '1',
        subject: 'Test Subject',
        sender: 'test@example.com',
        date: DateTime.now(),
        isRead: false,
      );
    });
    
    testWidgets('should display email information correctly', (tester) async {
      // Arrange
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: EmailTile(email: testEmail),
          ),
        ),
      );
      
      // Assert
      expect(find.text('Test Subject'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.byIcon(Icons.mark_email_unread), findsOneWidget);
    });
    
    testWidgets('should call onTap when tapped', (tester) async {
      // Arrange
      bool wasTapped = false;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: EmailTile(
              email: testEmail,
              onTap: () => wasTapped = true,
            ),
          ),
        ),
      );
      
      // Act
      await tester.tap(find.byType(EmailTile));
      await tester.pump();
      
      // Assert
      expect(wasTapped, isTrue);
    });
  });
}
```

### Integration Testing

```dart
// integration_test/email_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:wahda_bank/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Email Flow Integration Tests', () {
    testWidgets('complete email reading flow', (tester) async {
      // Start app
      app.main();
      await tester.pumpAndSettle();
      
      // Navigate to inbox
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      
      // Tap on first email
      await tester.tap(find.byType(EmailTile).first);
      await tester.pumpAndSettle();
      
      // Verify email details screen
      expect(find.byType(EmailDetailScreen), findsOneWidget);
      
      // Mark as read
      await tester.tap(find.byIcon(Icons.mark_email_read));
      await tester.pumpAndSettle();
      
      // Verify success message
      expect(find.text('Email marked as read'), findsOneWidget);
    });
  });
}
```

### Test Coverage

```bash
# Generate coverage report
flutter test --coverage

# View coverage in browser
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 🐛 Debugging

### Debug Tools

#### Flutter Inspector
```dart
// Enable debug mode
void main() {
  if (kDebugMode) {
    debugPaintSizeEnabled = true; // Show widget boundaries
    debugRepaintRainbowEnabled = true; // Show repaints
  }
  runApp(MyApp());
}
```

#### Logging
```dart
// Use structured logging
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

// Usage
logger.d('Debug message');
logger.i('Info message');
logger.w('Warning message');
logger.e('Error message');
```

#### Performance Profiling
```dart
// Profile widget builds
class ProfiledWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Timeline.startSync('ProfiledWidget.build', () {
      // Widget building code
      return Container(child: Text('Hello'));
    });
  }
}

// Profile async operations
Future<void> profiledOperation() async {
  final stopwatch = Stopwatch()..start();
  try {
    await expensiveOperation();
  } finally {
    stopwatch.stop();
    logger.i('Operation took ${stopwatch.elapsedMilliseconds}ms');
  }
}
```

### Common Debugging Scenarios

#### State Management Issues
```dart
// Debug GetX state changes
class DebugMailBoxController extends MailBoxController {
  @override
  void update([List<Object>? ids, bool condition = true]) {
    logger.d('Updating MailBoxController: $ids');
    super.update(ids, condition);
  }
}

// Debug reactive variables
final emails = <Email>[].obs;
ever(emails, (List<Email> emails) {
  logger.d('Emails changed: ${emails.length} items');
});
```

#### Network Issues
```dart
// Debug HTTP requests
class DebugHttpClient {
  static void logRequest(String method, String url, Map<String, String>? headers) {
    logger.d('$method $url');
    if (headers != null) {
      headers.forEach((key, value) => logger.d('  $key: $value'));
    }
  }
  
  static void logResponse(int statusCode, String body) {
    logger.d('Response: $statusCode');
    logger.d('Body: ${body.substring(0, min(body.length, 200))}...');
  }
}
```

## ⚡ Performance Optimization

### Widget Performance

```dart
// Use const constructors
class OptimizedWidget extends StatelessWidget {
  const OptimizedWidget({super.key, required this.title});
  
  final String title;
  
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Text('Static content'),
    );
  }
}

// Implement AutomaticKeepAliveClientMixin for expensive widgets
class ExpensiveListItem extends StatefulWidget {
  @override
  _ExpensiveListItemState createState() => _ExpensiveListItemState();
}

class _ExpensiveListItemState extends State<ExpensiveListItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return ExpensiveWidget();
  }
}
```

### Memory Management

```dart
// Dispose resources properly
class ResourcefulWidget extends StatefulWidget {
  @override
  _ResourcefulWidgetState createState() => _ResourcefulWidgetState();
}

class _ResourcefulWidgetState extends State<ResourcefulWidget> {
  late StreamSubscription _subscription;
  late Timer _timer;
  
  @override
  void initState() {
    super.initState();
    _subscription = stream.listen(_handleData);
    _timer = Timer.periodic(Duration(seconds: 1), _handleTimer);
  }
  
  @override
  void dispose() {
    _subscription.cancel();
    _timer.cancel();
    super.dispose();
  }
}

// Use weak references for callbacks
class WeakCallback {
  final WeakReference<Object> _targetRef;
  final Function _callback;
  
  WeakCallback(Object target, this._callback) : _targetRef = WeakReference(target);
  
  void call() {
    final target = _targetRef.target;
    if (target != null) {
      _callback();
    }
  }
}
```

### Build Optimization

```bash
# Optimize build size
flutter build apk --split-per-abi
flutter build appbundle

# Enable tree shaking
flutter build web --tree-shake-icons

# Profile build performance
flutter build --profile --analyze-size
```

## ❗ Common Issues

### GetX Dependency Issues

```dart
// ❌ Problem: Service not found
final service = Get.find<EmailService>(); // Throws error

// ✅ Solution: Ensure service is registered
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<EmailService>(EmailService(), permanent: true);
  }
}

// ✅ Alternative: Use lazy loading
Get.lazyPut<EmailService>(() => EmailService());
```

### State Update Issues

```dart
// ❌ Problem: UI not updating
emails.add(newEmail); // Direct list modification

// ✅ Solution: Use reactive methods
emails.add(newEmail);
update(); // Force update

// ✅ Better: Use reactive list methods
emails.assignAll(newEmails);
```

### Memory Leaks

```dart
// ❌ Problem: Stream not disposed
StreamSubscription? subscription;

void initState() {
  subscription = stream.listen(_handleData);
}

// ✅ Solution: Proper disposal
@override
void dispose() {
  subscription?.cancel();
  super.dispose();
}
```

### Build Issues

```bash
# Clear build cache
flutter clean
flutter pub get

# Reset Flutter
flutter doctor
flutter upgrade

# Platform-specific issues
cd ios && pod install && cd ..  # iOS
flutter build apk --debug       # Android
```

## 🔧 Development Tools

### Useful Commands

```bash
# Development
flutter run --hot                    # Hot reload
flutter run --profile               # Profile mode
flutter run --release               # Release mode

# Analysis
flutter analyze                     # Static analysis
dart format .                       # Format code
flutter test --coverage             # Test with coverage

# Build
flutter build apk --debug           # Debug APK
flutter build appbundle --release   # Release bundle
flutter build web --release         # Web build

# Debugging
flutter logs                        # View logs
flutter screenshot                  # Take screenshot
flutter drive test/integration_test.dart  # Integration tests
```

### VS Code Tasks

Create `.vscode/tasks.json`:
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Flutter: Analyze",
      "type": "shell",
      "command": "flutter",
      "args": ["analyze"],
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
      }
    },
    {
      "label": "Flutter: Test",
      "type": "shell",
      "command": "flutter",
      "args": ["test", "--coverage"],
      "group": "test",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
      }
    }
  ]
}
```

---

## 📚 Additional Resources

- [Flutter Development Best Practices](https://docs.flutter.dev/development/best-practices)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [GetX Documentation](https://github.com/jonataslaw/getx/blob/master/README.md)
- [Flutter Testing Guide](https://docs.flutter.dev/testing)
- [Performance Best Practices](https://docs.flutter.dev/perf/best-practices)

For architecture details, see [Architecture Guide](ARCHITECTURE.md).
For troubleshooting, see [Troubleshooting Guide](TROUBLESHOOTING.md).

