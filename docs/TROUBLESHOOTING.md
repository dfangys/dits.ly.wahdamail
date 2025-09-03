# 🔧 Troubleshooting Guide

This guide helps developers and users resolve common issues with the Wahda Bank Email Client.

## 📋 Table of Contents

- [Installation Issues](#installation-issues)
- [Build Problems](#build-problems)
- [Runtime Errors](#runtime-errors)
- [Email Connection Issues](#email-connection-issues)
- [Performance Problems](#performance-problems)
- [UI/UX Issues](#uiux-issues)
- [Platform-Specific Issues](#platform-specific-issues)
- [Debug Tools](#debug-tools)

## 🚀 Installation Issues

### Flutter SDK Issues

#### Problem: Flutter command not found
```bash
flutter: command not found
```

**Solution:**
```bash
# Add Flutter to PATH
export PATH="$PATH:/path/to/flutter/bin"

# Make permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export PATH="$PATH:/path/to/flutter/bin"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
flutter doctor
```

#### Problem: Flutter doctor shows issues
```bash
[✗] Android toolchain - develop for Android devices
[✗] Xcode - develop for iOS and macOS
```

**Solution:**
```bash
# Android issues
flutter doctor --android-licenses
sdkmanager "platform-tools" "platforms;android-33"

# iOS issues (macOS only)
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# Install CocoaPods
sudo gem install cocoapods
```

### Dependency Issues

#### Problem: Package version conflicts
```
Because wahda_bank depends on package_a >=1.0.0 and package_b >=2.0.0...
```

**Solution:**
```yaml
# In pubspec.yaml, use dependency overrides
dependency_overrides:
  package_a: ^1.2.0
  package_b: ^2.1.0
```

```bash
# Clear cache and reinstall
flutter clean
flutter pub cache repair
flutter pub get
```

#### Problem: Native dependencies not found
```
CocoaPods not installed or not in valid state
```

**Solution:**
```bash
# iOS
cd ios
pod deintegrate
pod install
cd ..

# Android
cd android
./gradlew clean
cd ..

# Rebuild
flutter clean
flutter pub get
```

## 🔨 Build Problems

### Android Build Issues

#### Problem: Gradle build fails
```
FAILURE: Build failed with an exception.
* What went wrong: Execution failed for task ':app:processDebugResources'.
```

**Solution:**
```bash
# Clean and rebuild
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk

# If still failing, check gradle version
# In android/gradle/wrapper/gradle-wrapper.properties
distributionUrl=https\://services.gradle.org/distributions/gradle-7.6.1-all.zip
```

#### Problem: Multidex issues
```
Cannot fit requested classes in a single dex file
```

**Solution:**
```kotlin
// In android/app/build.gradle
android {
    defaultConfig {
        multiDexEnabled true
    }
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
}
```

### iOS Build Issues

#### Problem: Code signing errors
```
Code Signing Error: No signing certificate "iOS Development" found
```

**Solution:**
```bash
# Open Xcode
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select Runner project
# 2. Go to Signing & Capabilities
# 3. Select your team
# 4. Enable "Automatically manage signing"
```

#### Problem: Pod installation fails
```
[!] CocoaPods could not find compatible versions for pod "Firebase/Core"
```

**Solution:**
```bash
cd ios
pod repo update
pod install --repo-update
cd ..
```

### Web Build Issues

#### Problem: Web build fails with CORS errors
```
Access to XMLHttpRequest blocked by CORS policy
```

**Solution:**
```bash
# For development, use Chrome with disabled security
flutter run -d chrome --web-browser-flag "--disable-web-security"

# For production, configure server CORS headers
# Or use a proxy server
```

#### Problem: Large bundle size
```
Warning: Bundle size is 2.5MB, consider code splitting
```

**Solution:**
```bash
# Enable tree shaking
flutter build web --tree-shake-icons --dart-define=FLUTTER_WEB_USE_SKIA=true

# Analyze bundle size
flutter build web --analyze-size
```

## 🐛 Runtime Errors

### GetX Dependency Injection Issues

#### Problem: Service not found
```
"MailService" not found. You need to call "Get.put(MailService())"
```

**Solution:**
```dart
// Ensure service is registered in binding
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<MailService>(MailService(), permanent: true);
  }
}

// Or use lazy loading
Get.lazyPut<MailService>(() => MailService());

// Check if service is registered
// Access the service via its singleton instance
final service = MailService.instance;
```

#### Problem: Circular dependency
```
Circular dependency detected: A -> B -> A
```

**Solution:**
```dart
// Use lazy loading to break circular dependencies
class ServiceA extends GetxService {
  ServiceB get serviceB => Get.find<ServiceB>();
}

class ServiceB extends GetxService {
  // Don't inject ServiceA in constructor
  ServiceA get serviceA => Get.find<ServiceA>();
}

// Register with lazy loading
Get.lazyPut<ServiceA>(() => ServiceA());
Get.lazyPut<ServiceB>(() => ServiceB());
```

### State Management Issues

#### Problem: UI not updating
```dart
// Observable not triggering UI updates
final emails = <Email>[].obs;
emails.add(newEmail); // UI doesn't update
```

**Solution:**
```dart
// Use reactive list methods
emails.add(newEmail);
emails.refresh(); // Force update

// Or use assignAll
emails.assignAll([...emails, newEmail]);

// For complex objects, use update()
final user = User().obs;
user.value.name = 'New Name';
user.refresh(); // Notify listeners
```

#### Problem: Memory leaks with streams
```dart
// Stream subscription not disposed
StreamSubscription? subscription;
```

**Solution:**
```dart
class MyController extends GetxController {
  StreamSubscription? _subscription;
  
  @override
  void onInit() {
    super.onInit();
    _subscription = stream.listen(_handleData);
  }
  
  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
```

### Database Issues

#### Problem: SQLite database locked
```
database is locked (code 5 SQLITE_BUSY)
```

**Solution:**
```dart
// Use transactions for multiple operations
await database.transaction((txn) async {
  await txn.insert('messages', message.toMap());
  await txn.update('mailboxes', mailbox.toMap());
});

// Add timeout to database operations
final result = await database.query('messages')
    .timeout(Duration(seconds: 10));

// Close database connections properly
await database.close();
```

#### Problem: Database migration fails
```
table messages has no column named new_column
```

**Solution:**
```dart
// Implement proper migration
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE messages ADD COLUMN new_column TEXT');
  }
  if (oldVersion < 3) {
    await db.execute('CREATE INDEX idx_messages_date ON messages(date_received)');
  }
}

// Or recreate database for development
await deleteDatabase(path);
final db = await openDatabase(path, version: newVersion, onCreate: _onCreate);
```

## 📧 Email Connection Issues

### IMAP/SMTP Connection Problems

#### Problem: Connection timeout
```
SocketException: Connection timed out
```

**Solution:**
```dart
// Increase timeout
final client = ImapClient(
  timeout: Duration(seconds: 30),
  connectionTimeout: Duration(seconds: 15),
);

// Retry with exponential backoff
Future<void> connectWithRetry() async {
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      await client.connect();
      return;
    } catch (e) {
      if (attempt == 2) rethrow;
      await Future.delayed(Duration(seconds: 1 << attempt));
    }
  }
}
```

#### Problem: Authentication failed
```
AuthenticationException: Invalid credentials
```

**Solution:**
```dart
// Check credentials
final credentials = PlainAuthentication(
  username: 'user@gmail.com', // Full email address
  password: 'app-password',   // Not regular password for Gmail
);

// For Gmail, use app-specific password
// 1. Enable 2FA
// 2. Generate app password
// 3. Use app password instead of regular password

// For OAuth2 (Gmail)
final oauth2 = OauthAuthentication(
  userName: 'user@gmail.com',
  accessToken: accessToken,
);
```

#### Problem: SSL/TLS errors
```
HandshakeException: Handshake error in client
```

**Solution:**
```dart
// For development, allow bad certificates
final client = ImapClient(
  allowBadCertificates: true, // Only for development
);

// For production, use proper certificates
final client = ImapClient(
  allowBadCertificates: false,
  trustedCertificates: [certificate],
);

// Check server settings
final config = ImapServerConfig(
  hostname: 'imap.gmail.com',
  port: 993,
  isSecure: true, // Use SSL
);
```

### Email Provider Specific Issues

#### Gmail Issues
```dart
// Use OAuth2 for Gmail
final googleSignIn = GoogleSignIn(scopes: ['https://mail.google.com/']);
final account = await googleSignIn.signIn();
final auth = await account?.authentication;

// Or use app password
// Settings → Security → 2-Step Verification → App passwords
```

#### Outlook Issues
```dart
// Use modern authentication
final config = ImapServerConfig(
  hostname: 'outlook.office365.com',
  port: 993,
  isSecure: true,
);

// Enable modern auth in Outlook admin
```

#### Yahoo Issues
```dart
// Yahoo requires app password
// Account Info → Account Security → Generate app password
final config = ImapServerConfig(
  hostname: 'imap.mail.yahoo.com',
  port: 993,
  isSecure: true,
);
```

## ⚡ Performance Problems

### Slow Email Loading

#### Problem: Long loading times
```
Email list takes 10+ seconds to load
```

**Solution:**
```dart
// Implement pagination
Future<void> loadEmails({int page = 1, int limit = 20}) async {
  final start = (page - 1) * limit + 1;
  final end = page * limit;
  
  final sequence = MessageSequence.fromRange(start, end);
  final messages = await client.fetchMessages(sequence);
  
  if (page == 1) {
    emails.assignAll(messages);
  } else {
    emails.addAll(messages);
  }
}

// Use lazy loading
class LazyEmailList extends StatefulWidget {
  @override
  _LazyEmailListState createState() => _LazyEmailListState();
}

class _LazyEmailListState extends State<LazyEmailList> {
  final ScrollController _controller = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (_controller.position.pixels >= 
        _controller.position.maxScrollExtent * 0.8) {
      Get.find<MailBoxController>().loadMoreEmails();
    }
  }
}
```

### Memory Issues

#### Problem: High memory usage
```
Out of memory error or app crashes
```

**Solution:**
```dart
// Implement proper caching
class CacheManager {
  final LRUMap<String, MimeMessage> _cache = LRUMap(maxSize: 100);
  
  void cacheMessage(String key, MimeMessage message) {
    _cache[key] = message;
  }
  
  void clearOldEntries() {
    final cutoff = DateTime.now().subtract(Duration(hours: 1));
    _cache.removeWhere((key, value) => 
        value.date?.isBefore(cutoff) ?? false);
  }
}

// Dispose resources properly
@override
void dispose() {
  _scrollController.dispose();
  _subscription?.cancel();
  _timer?.cancel();
  super.dispose();
}

// Use const constructors
const EmailTile({
  super.key,
  required this.email,
});
```

### UI Performance Issues

#### Problem: Janky scrolling
```
Frame rendering takes >16ms
```

**Solution:**
```dart
// Use ListView.builder for large lists
ListView.builder(
  itemCount: emails.length,
  itemBuilder: (context, index) => EmailTile(
    email: emails[index],
  ),
);

// Implement AutomaticKeepAliveClientMixin for expensive widgets
class ExpensiveEmailTile extends StatefulWidget {
  @override
  _ExpensiveEmailTileState createState() => _ExpensiveEmailTileState();
}

class _ExpensiveEmailTileState extends State<ExpensiveEmailTile>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ExpensiveWidget();
  }
}

// Use RepaintBoundary for complex widgets
RepaintBoundary(
  child: ComplexEmailWidget(),
)
```

## 🎨 UI/UX Issues

### Layout Issues

#### Problem: Overflow errors
```
RenderFlex overflowed by 123 pixels on the right
```

**Solution:**
```dart
// Use Flexible or Expanded
Row(
  children: [
    Flexible(
      child: Text('Long text that might overflow'),
    ),
    Icon(Icons.star),
  ],
)

// Use SingleChildScrollView for scrollable content
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(children: widgets),
)

// Use FittedBox for scaling
FittedBox(
  fit: BoxFit.scaleDown,
  child: Text('Text that scales to fit'),
)
```

#### Problem: Keyboard overflow
```
Bottom overflowed by 123 pixels
```

**Solution:**
```dart
// Use Scaffold with resizeToAvoidBottomInset
Scaffold(
  resizeToAvoidBottomInset: true,
  body: SingleChildScrollView(
    child: Column(children: widgets),
  ),
)

// Or use MediaQuery to adjust layout
Widget build(BuildContext context) {
  final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
  return Padding(
    padding: EdgeInsets.only(bottom: keyboardHeight),
    child: content,
  );
}
```

### Theme Issues

#### Problem: Dark mode not working
```
Colors don't change in dark mode
```

**Solution:**
```dart
// Use theme-aware colors
Container(
  color: Theme.of(context).colorScheme.surface,
  child: Text(
    'Hello',
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
    ),
  ),
)

// Define proper theme data
ThemeData.dark().copyWith(
  colorScheme: ColorScheme.dark(
    primary: Colors.blue,
    surface: Colors.grey[900]!,
    onSurface: Colors.white,
  ),
)
```

### Navigation Issues

#### Problem: Navigation not working
```
Navigator operation requested with a context that does not include a Navigator
```

**Solution:**
```dart
// Use GetX navigation
Get.to(() => NextScreen());
Get.back();
Get.offAll(() => HomeScreen());

// Or ensure context has Navigator
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => NextScreen()),
        ),
        child: Text('Navigate'),
      ),
    );
  }
}
```

## 📱 Platform-Specific Issues

### Android Issues

#### Problem: App crashes on startup
```
java.lang.RuntimeException: Unable to start activity
```

**Solution:**
```xml
<!-- In android/app/src/main/AndroidManifest.xml -->
<application
    android:name="io.flutter.app.FlutterApplication"
    android:label="wahda_bank"
    android:usesCleartextTraffic="true">
    
    <!-- Add required permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
</application>
```

#### Problem: ProGuard issues in release
```
ClassNotFoundException in release build
```

**Solution:**
```proguard
# In android/app/proguard-rules.pro
-keep class com.example.wahda_bank.** { *; }
-keep class io.flutter.** { *; }
-keep class androidx.** { *; }

# Keep GetX classes
-keep class com.github.jonataslaw.** { *; }
```

### iOS Issues

#### Problem: App rejected by App Store
```
Your app uses non-public APIs
```

**Solution:**
```dart
// Remove debug code from release builds
if (kDebugMode) {
  debugPrint('Debug information');
}

// Use conditional imports
import 'debug_tools.dart' if (dart.library.io) 'debug_tools_io.dart';
```

#### Problem: Background app refresh not working
```
Background sync stops working
```

**Solution:**
```xml
<!-- In ios/Runner/Info.plist -->
<key>UIBackgroundModes</key>
<array>
    <string>background-fetch</string>
    <string>background-processing</string>
</array>
```

### Web Issues

#### Problem: CORS errors
```
Access to fetch blocked by CORS policy
```

**Solution:**
```dart
// Use proxy for development
// In web/index.html
<script>
  if (window.location.hostname === 'localhost') {
    window.flutterConfiguration = {
      canvasKitBaseUrl: "/canvaskit/"
    };
  }
</script>

// Configure server CORS headers
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Headers: Content-Type, Authorization
```

## 🔍 Debug Tools

### Flutter Inspector

```dart
// Enable debug tools
void main() {
  if (kDebugMode) {
    debugPaintSizeEnabled = true;
    debugRepaintRainbowEnabled = false;
  }
  runApp(MyApp());
}
```

### Logging

```dart
// Structured logging
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
logger.d('Debug: Loading emails');
logger.i('Info: ${emails.length} emails loaded');
logger.w('Warning: Slow network detected');
logger.e('Error: Failed to connect', error, stackTrace);
```

### Performance Monitoring

```dart
// Monitor frame rendering
import 'dart:developer' as developer;

void monitorPerformance() {
  WidgetsBinding.instance.addTimingsCallback((timings) {
    for (final timing in timings) {
      if (timing.totalSpan.inMilliseconds > 16) {
        logger.w('Slow frame: ${timing.totalSpan.inMilliseconds}ms');
      }
    }
  });
}

// Profile specific operations
Future<void> profiledOperation() async {
  final stopwatch = Stopwatch()..start();
  try {
    await expensiveOperation();
  } finally {
    stopwatch.stop();
    developer.log(
      'Operation completed',
      name: 'Performance',
      time: DateTime.now(),
      sequenceNumber: 1,
      level: 800,
      message: 'Duration: ${stopwatch.elapsedMilliseconds}ms',
    );
  }
}
```

### Network Debugging

```dart
// Log HTTP requests
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger.d('REQUEST: ${options.method} ${options.uri}');
    logger.d('Headers: ${options.headers}');
    super.onRequest(options, handler);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    logger.d('RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
    super.onResponse(response, handler);
  }
  
  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    logger.e('ERROR: ${err.message}');
    super.onError(err, handler);
  }
}
```

## 🆘 Getting Help

### Before Asking for Help

1. **Check logs**: Look for error messages and stack traces
2. **Search issues**: Check GitHub issues for similar problems
3. **Try clean build**: Run `flutter clean && flutter pub get`
4. **Update dependencies**: Ensure you're using latest versions
5. **Test on different devices**: Verify if issue is device-specific

### Providing Information

When reporting issues, include:

```
**Environment:**
- Flutter version: (run `flutter --version`)
- Dart version: 
- Platform: iOS/Android/Web
- Device: 

**Issue Description:**
- What you expected to happen
- What actually happened
- Steps to reproduce

**Logs:**
```
Paste relevant logs here
```

**Code:**
```dart
// Minimal code example that reproduces the issue
```
```

### Resources

- **GitHub Issues**: [Project Issues](https://github.com/dfangys/dits.ly.wahdamail/issues)
- **Flutter Docs**: [flutter.dev](https://flutter.dev)
- **GetX Docs**: [GetX GitHub](https://github.com/jonataslaw/getx)
- **Stack Overflow**: Tag questions with `flutter`, `dart`, `getx`

---

## 📚 Additional Resources

- [Flutter Debugging Guide](https://docs.flutter.dev/testing/debugging)
- [Dart Observatory](https://dart.dev/tools/dart-devtools)
- [Flutter Performance Profiling](https://docs.flutter.dev/perf/ui-performance)
- [GetX Troubleshooting](https://github.com/jonataslaw/getx/blob/master/documentation/en_US/troubleshooting.md)

For development guidelines, see [Development Guide](DEVELOPMENT.md).
For architecture details, see [Architecture Guide](ARCHITECTURE.md).

