# 🚀 Deployment Guide

This guide covers deployment strategies and configurations for the Wahda Bank Email Client across different platforms.

## 📋 Table of Contents

- [Pre-deployment Checklist](#pre-deployment-checklist)
- [Android Deployment](#android-deployment)
- [iOS Deployment](#ios-deployment)
- [Web Deployment](#web-deployment)
- [CI/CD Pipeline](#cicd-pipeline)
- [Environment Configuration](#environment-configuration)
- [Security Considerations](#security-considerations)
- [Monitoring & Analytics](#monitoring--analytics)

## ✅ Pre-deployment Checklist

### Code Quality
- [ ] All tests passing (`flutter test`)
- [ ] Code analysis clean (`flutter analyze`)
- [ ] Code formatted (`dart format .`)
- [ ] No debug code in production builds
- [ ] Performance optimizations applied
- [ ] Memory leaks checked and fixed

### Security
- [ ] API keys secured and not hardcoded
- [ ] SSL/TLS certificates configured
- [ ] Authentication mechanisms tested
- [ ] Data encryption implemented
- [ ] Permissions properly configured

### Configuration
- [ ] Environment variables set
- [ ] Build configurations verified
- [ ] App signing configured
- [ ] Version numbers updated
- [ ] Release notes prepared

### Testing
- [ ] Unit tests coverage > 80%
- [ ] Widget tests for critical components
- [ ] Integration tests for main flows
- [ ] Manual testing on target devices
- [ ] Performance testing completed

## 📱 Android Deployment

### Build Configuration

#### 1. Configure App Signing

Create keystore:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Configure signing in `android/app/build.gradle`:
```gradle
android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

Create `android/key.properties`:
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=upload
storeFile=../upload-keystore.jks
```

#### 2. Configure ProGuard

Create `android/app/proguard-rules.pro`:
```proguard
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# GetX
-keep class com.github.jonataslaw.** { *; }

# Email libraries
-keep class enough_mail.** { *; }
-keep class javax.mail.** { *; }

# SQLite
-keep class androidx.sqlite.** { *; }

# Prevent obfuscation of model classes
-keep class com.example.wahda_bank.models.** { *; }
```

#### 3. Build Release APK

```bash
# Build APK
flutter build apk --release

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release

# Build with specific flavor
flutter build appbundle --release --flavor production
```

#### 4. Test Release Build

```bash
# Install release APK
flutter install --release

# Test on multiple devices
adb devices
adb -s DEVICE_ID install build/app/outputs/flutter-apk/app-release.apk
```

### Google Play Store Deployment

#### 1. Prepare Store Listing

Create store assets:
- App icon (512x512 PNG)
- Feature graphic (1024x500 PNG)
- Screenshots (phone, tablet, TV)
- App description and metadata

#### 2. Upload to Play Console

```bash
# Use Play Console or fastlane
bundle exec fastlane android deploy
```

#### 3. Release Management

```yaml
# Configure staged rollout
rollout_percentage: 10  # Start with 10%
track: production       # or internal/alpha/beta
```

### Firebase App Distribution

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login and configure
firebase login
firebase init

# Deploy to App Distribution
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app 1:123456789:android:abcd1234 \
  --groups "testers" \
  --release-notes "Bug fixes and performance improvements"
```

## 🍎 iOS Deployment

### Build Configuration

#### 1. Configure Xcode Project

Open `ios/Runner.xcworkspace` in Xcode:

1. **Set Bundle Identifier**: `com.wahdabank.email`
2. **Configure Team**: Select development team
3. **Set Deployment Target**: iOS 12.0+
4. **Configure Capabilities**: 
   - Background App Refresh
   - Push Notifications
   - Keychain Sharing

#### 2. Configure App Transport Security

In `ios/Runner/Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>wahdabank.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.2</string>
        </dict>
    </dict>
</dict>
```

#### 3. Build Release IPA

```bash
# Build iOS release
flutter build ios --release

# Or build with Xcode
open ios/Runner.xcworkspace
# Product → Archive → Distribute App
```

#### 4. Automated Building with fastlane

Create `ios/fastlane/Fastfile`:
```ruby
default_platform(:ios)

platform :ios do
  desc "Build and upload to TestFlight"
  lane :beta do
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      export_method: "app-store"
    )
    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )
  end
  
  desc "Deploy to App Store"
  lane :release do
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      export_method: "app-store"
    )
    upload_to_app_store(
      force: true,
      submit_for_review: true
    )
  end
end
```

### App Store Deployment

#### 1. Prepare App Store Connect

1. **Create App Record**: In App Store Connect
2. **Configure App Information**:
   - Name: "Wahda Bank Email"
   - Bundle ID: `com.wahdabank.email`
   - SKU: Unique identifier
   - Primary Language: English

3. **Upload Metadata**:
   - App description
   - Keywords
   - Screenshots (all device sizes)
   - App preview videos

#### 2. TestFlight Distribution

```bash
# Upload to TestFlight
fastlane ios beta

# Or manually through Xcode
# Window → Organizer → Upload to App Store Connect
```

#### 3. App Store Review

Prepare for review:
- Demo account credentials
- Review notes explaining features
- Contact information
- Privacy policy URL

## 🌐 Web Deployment

### Build Configuration

#### 1. Configure Web Settings

In `web/index.html`:
```html
<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="Wahda Bank Email Client">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="Wahda Bank Email">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="icon" type="image/png" href="favicon.png"/>
  <title>Wahda Bank Email</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <script>
    window.addEventListener('load', function(ev) {
      _flutter.loader.loadEntrypoint({
        serviceWorker: {
          serviceWorkerVersion: serviceWorkerVersion,
        }
      }).then(function(engineInitializer) {
        return engineInitializer.initializeEngine();
      }).then(function(appRunner) {
        return appRunner.runApp();
      });
    });
  </script>
</body>
</html>
```

#### 2. Configure PWA Manifest

In `web/manifest.json`:
```json
{
  "name": "Wahda Bank Email",
  "short_name": "WB Email",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#0175C2",
  "theme_color": "#0175C2",
  "description": "Secure email client for Wahda Bank",
  "orientation": "portrait-primary",
  "prefer_related_applications": false,
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

#### 3. Build Web Release

```bash
# Build for web
flutter build web --release

# Build with custom base href
flutter build web --release --base-href "/email/"

# Build with tree shaking
flutter build web --release --tree-shake-icons

# Analyze bundle size
flutter build web --release --analyze-size
```

### Deployment Platforms

#### 1. Firebase Hosting

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize Firebase
firebase init hosting

# Configure firebase.json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  }
}

# Deploy
firebase deploy --only hosting
```

#### 2. Netlify

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
netlify deploy --prod --dir=build/web

# Configure _redirects file
echo "/*    /index.html   200" > build/web/_redirects
```

#### 3. GitHub Pages

```yaml
# .github/workflows/deploy.yml
name: Deploy to GitHub Pages

on:
  push:
    branches: [ main ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.24.3'
    
    - run: flutter pub get
    - run: flutter test
    - run: flutter build web --release --base-href "/dits.ly.wahdamail/"
    
    - name: Deploy to GitHub Pages
      uses: peaceiris/actions-gh-pages@v3
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./build/web
```

#### 4. Custom Server (Nginx)

```nginx
# /etc/nginx/sites-available/wahda-email
server {
    listen 80;
    server_name email.wahdabank.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name email.wahdabank.com;
    
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    root /var/www/wahda-email;
    index index.html;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Handle Flutter routing
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

## 🔄 CI/CD Pipeline

### GitHub Actions

Create `.github/workflows/ci-cd.yml`:
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, final-fixes ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.24.3'
        cache: true
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Run tests
      run: flutter test --coverage
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        file: coverage/lcov.info
    
    - name: Analyze code
      run: flutter analyze
    
    - name: Check formatting
      run: dart format --set-exit-if-changed .

  build-android:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.24.3'
    
    - name: Setup Java
      uses: actions/setup-java@v3
      with:
        distribution: 'zulu'
        java-version: '11'
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Build APK
      run: flutter build apk --release
    
    - name: Build App Bundle
      run: flutter build appbundle --release
    
    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: android-builds
        path: |
          build/app/outputs/flutter-apk/app-release.apk
          build/app/outputs/bundle/release/app-release.aab

  build-ios:
    needs: test
    runs-on: macos-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.24.3'
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Build iOS
      run: flutter build ios --release --no-codesign
    
    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: ios-build
        path: build/ios/iphoneos/Runner.app

  build-web:
    needs: test
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.24.3'
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Build Web
      run: flutter build web --release
    
    - name: Deploy to Firebase
      if: github.ref == 'refs/heads/main'
      uses: FirebaseExtended/action-hosting-deploy@v0
      with:
        repoToken: '${{ secrets.GITHUB_TOKEN }}'
        firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
        projectId: wahda-bank-email
        channelId: live

  deploy-android:
    needs: build-android
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    
    - name: Download artifacts
      uses: actions/download-artifact@v3
      with:
        name: android-builds
    
    - name: Deploy to Play Store
      uses: r0adkll/upload-google-play@v1
      with:
        serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
        packageName: com.wahdabank.email
        releaseFiles: app-release.aab
        track: internal
        status: completed
```

### GitLab CI/CD

Create `.gitlab-ci.yml`:
```yaml
stages:
  - test
  - build
  - deploy

variables:
  FLUTTER_VERSION: "3.24.3"

before_script:
  - apt-get update -qq && apt-get install -y -qq git curl unzip
  - git clone https://github.com/flutter/flutter.git -b stable --depth 1
  - export PATH="$PATH:`pwd`/flutter/bin"
  - flutter doctor -v
  - flutter pub get

test:
  stage: test
  script:
    - flutter test --coverage
    - flutter analyze
    - dart format --set-exit-if-changed .
  coverage: '/lines......: \d+\.\d+\%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml

build_android:
  stage: build
  script:
    - flutter build apk --release
    - flutter build appbundle --release
  artifacts:
    paths:
      - build/app/outputs/flutter-apk/app-release.apk
      - build/app/outputs/bundle/release/app-release.aab
    expire_in: 1 week
  only:
    - main

build_web:
  stage: build
  script:
    - flutter build web --release
  artifacts:
    paths:
      - build/web/
    expire_in: 1 week

deploy_web:
  stage: deploy
  script:
    - npm install -g firebase-tools
    - firebase deploy --only hosting --token $FIREBASE_TOKEN
  dependencies:
    - build_web
  only:
    - main
```

## ⚙️ Environment Configuration

### Environment Variables

Create environment-specific configuration:

#### Development (.env.dev)
```env
API_BASE_URL=https://dev-api.wahdabank.com
DEBUG_MODE=true
LOG_LEVEL=debug
ENABLE_ANALYTICS=false
ENABLE_CRASH_REPORTING=false
DATABASE_NAME=wahda_email_dev.db
CACHE_SIZE=50
```

#### Staging (.env.staging)
```env
API_BASE_URL=https://staging-api.wahdabank.com
DEBUG_MODE=false
LOG_LEVEL=info
ENABLE_ANALYTICS=true
ENABLE_CRASH_REPORTING=true
DATABASE_NAME=wahda_email_staging.db
CACHE_SIZE=100
```

#### Production (.env.prod)
```env
API_BASE_URL=https://api.wahdabank.com
DEBUG_MODE=false
LOG_LEVEL=error
ENABLE_ANALYTICS=true
ENABLE_CRASH_REPORTING=true
DATABASE_NAME=wahda_email.db
CACHE_SIZE=200
```

### Configuration Management

```dart
// lib/config/app_config.dart
class AppConfig {
  static const String _environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');
  
  static bool get isProduction => _environment == 'prod';
  static bool get isStaging => _environment == 'staging';
  static bool get isDevelopment => _environment == 'dev';
  
  static String get apiBaseUrl {
    switch (_environment) {
      case 'prod':
        return 'https://api.wahdabank.com';
      case 'staging':
        return 'https://staging-api.wahdabank.com';
      default:
        return 'https://dev-api.wahdabank.com';
    }
  }
  
  static bool get debugMode => isDevelopment;
  static bool get enableAnalytics => !isDevelopment;
}

// Usage
void main() {
  if (AppConfig.debugMode) {
    debugPrint('Running in debug mode');
  }
  
  runApp(MyApp());
}
```

### Build Flavors

#### Android Flavors

In `android/app/build.gradle`:
```gradle
android {
    flavorDimensions "environment"
    
    productFlavors {
        dev {
            dimension "environment"
            applicationIdSuffix ".dev"
            versionNameSuffix "-dev"
            resValue "string", "app_name", "WB Email Dev"
        }
        
        staging {
            dimension "environment"
            applicationIdSuffix ".staging"
            versionNameSuffix "-staging"
            resValue "string", "app_name", "WB Email Staging"
        }
        
        prod {
            dimension "environment"
            resValue "string", "app_name", "Wahda Bank Email"
        }
    }
}
```

#### iOS Schemes

Create multiple schemes in Xcode:
1. **Runner-Dev**: Development configuration
2. **Runner-Staging**: Staging configuration  
3. **Runner-Prod**: Production configuration

Build with flavors:
```bash
# Android
flutter build apk --flavor dev
flutter build appbundle --flavor prod

# iOS
flutter build ios --flavor staging
```

## 🔒 Security Considerations

### API Security

```dart
// Secure API configuration
class ApiClient {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const Duration _timeout = Duration(seconds: 30);
  
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: _timeout,
    receiveTimeout: _timeout,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ))..interceptors.addAll([
    AuthInterceptor(),
    LoggingInterceptor(),
    RetryInterceptor(),
  ]);
  
  // Certificate pinning
  static void configureCertificatePinning() {
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      client.badCertificateCallback = (cert, host, port) {
        // Verify certificate fingerprint
        return _verifyCertificate(cert, host);
      };
      return client;
    };
  }
}
```

### Data Encryption

```dart
// Encrypt sensitive data
class EncryptionService {
  static const String _key = 'your-32-character-secret-key-here';
  
  static String encrypt(String plainText) {
    final key = encrypt.Key.fromBase64(_key);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }
  
  static String decrypt(String encryptedText) {
    final parts = encryptedText.split(':');
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    
    final key = encrypt.Key.fromBase64(_key);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    
    return encrypter.decrypt(encrypted, iv: iv);
  }
}
```

### Secure Storage

```dart
// Store sensitive data securely
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: IOSAccessibility.first_unlock_this_device,
    ),
  );
  
  static Future<void> storeCredentials(String email, String password) async {
    final encryptedPassword = EncryptionService.encrypt(password);
    await _storage.write(key: 'email_$email', value: encryptedPassword);
  }
  
  static Future<String?> getCredentials(String email) async {
    final encryptedPassword = await _storage.read(key: 'email_$email');
    return encryptedPassword != null 
        ? EncryptionService.decrypt(encryptedPassword) 
        : null;
  }
}
```

## 📊 Monitoring & Analytics

### Crash Reporting

```dart
// Firebase Crashlytics
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  if (AppConfig.enableCrashReporting) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  
  runApp(MyApp());
}

// Custom error reporting
class ErrorReporter {
  static void reportError(dynamic error, StackTrace? stackTrace, {
    Map<String, dynamic>? context,
  }) {
    if (AppConfig.enableCrashReporting) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        context: context,
      );
    }
    
    if (AppConfig.debugMode) {
      debugPrint('Error: $error');
      debugPrint('Stack trace: $stackTrace');
    }
  }
}
```

### Performance Monitoring

```dart
// Firebase Performance
class PerformanceMonitor {
  static Future<T> trace<T>(String name, Future<T> Function() operation) async {
    final trace = FirebasePerformance.instance.newTrace(name);
    await trace.start();
    
    try {
      final result = await operation();
      trace.setMetric('success', 1);
      return result;
    } catch (e) {
      trace.setMetric('error', 1);
      rethrow;
    } finally {
      await trace.stop();
    }
  }
  
  static void recordNetworkRequest(String url, int statusCode, int responseSize) {
    final metric = FirebasePerformance.instance.newHttpMetric(url, HttpMethod.Get);
    metric.responseCode = statusCode;
    metric.responsePayloadSize = responseSize;
    metric.stop();
  }
}
```

### Analytics

```dart
// Firebase Analytics
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  static Future<void> logEvent(String name, Map<String, dynamic> parameters) async {
    if (AppConfig.enableAnalytics) {
      await _analytics.logEvent(name: name, parameters: parameters);
    }
  }
  
  static Future<void> setUserProperty(String name, String value) async {
    if (AppConfig.enableAnalytics) {
      await _analytics.setUserProperty(name: name, value: value);
    }
  }
  
  // Email-specific events
  static Future<void> logEmailSent() async {
    await logEvent('email_sent', {'timestamp': DateTime.now().toIso8601String()});
  }
  
  static Future<void> logEmailRead(String mailbox) async {
    await logEvent('email_read', {'mailbox': mailbox});
  }
}
```

---

## 📚 Additional Resources

- [Flutter Deployment Guide](https://docs.flutter.dev/deployment)
- [Android App Bundle](https://developer.android.com/guide/app-bundle)
- [iOS App Store Guidelines](https://developer.apple.com/app-store/guidelines/)
- [Firebase Hosting](https://firebase.google.com/docs/hosting)
- [GitHub Actions for Flutter](https://docs.github.com/en/actions/guides/building-and-testing-flutter-apps)

For development setup, see [Development Guide](DEVELOPMENT.md).
For troubleshooting deployment issues, see [Troubleshooting Guide](TROUBLESHOOTING.md).

