# 📧 Wahda Bank Email Client

A modern, feature-rich Flutter email client application with advanced email management capabilities, real-time updates, and comprehensive security features.

![Flutter](https://img.shields.io/badge/Flutter-3.24.3-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.5.3-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Web-lightgrey.svg)

## 🌟 Features

### 📬 Email Management
- **Multi-Account Support**: Manage multiple email accounts from different providers
- **Real-time Synchronization**: Instant email updates with IMAP IDLE support
- **Advanced Search**: Powerful search functionality across all mailboxes
- **Offline Support**: Read and compose emails offline with automatic sync
- **Draft Management**: Auto-save drafts with local SQLite storage

### 🎨 User Interface
- **Modern Design**: Clean, intuitive interface with Material Design 3
- **Dark/Light Theme**: Automatic theme switching based on system preferences
- **Responsive Layout**: Optimized for mobile, tablet, and web platforms
- **Customizable Swipe Gestures**: Configure swipe actions for email management
- **Priority-based Mailbox Sorting**: Intelligent mailbox organization

### 🔒 Security & Privacy
- **App Lock**: PIN/Biometric authentication for app access
- **Auto-lock**: Configurable auto-lock timing for enhanced security
- **Notification Privacy**: Option to hide sensitive content in notifications
- **Remote Image Blocking**: Prevent tracking through remote images
- **Enhanced Spam Filter**: Advanced spam detection and filtering

### ⚡ Performance
- **Lazy Loading**: Efficient email loading with pagination
- **Smart Caching**: Multi-level caching for optimal performance
- **Background Sync**: Automatic email synchronization in background
- **Memory Optimization**: Efficient memory usage with automatic cleanup
- **Real-time Updates**: Live UI updates without manual refresh

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK**: 3.24.3 or higher
- **Dart SDK**: 3.5.3 or higher
- **Android Studio** / **VS Code** with Flutter extensions
- **Git** for version control

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/dfangys/dits.ly.wahdamail.git
   cd dits.ly.wahdamail
   ```

2. **Switch to the latest stable branch**
   ```bash
   git checkout final-fixes
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the application**
   ```bash
   # For development
   flutter run
   
   # For web
   flutter run -d chrome
   
   # For specific device
   flutter run -d <device-id>
   ```

### Build for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## 📱 Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| **Android** | ✅ Fully Supported | Android 5.0+ (API 21+) |
| **iOS** | ✅ Fully Supported | iOS 12.0+ |
| **Web** | ✅ Fully Supported | Modern browsers |
| **macOS** | 🔄 In Development | Coming soon |
| **Windows** | 🔄 In Development | Coming soon |
| **Linux** | 🔄 In Development | Coming soon |

## 🏗️ Architecture

### Project Structure
```
lib/
├── app/
│   ├── bindings/          # Dependency injection bindings
│   ├── controllers/       # GetX controllers for state management
│   └── routes/           # Application routing configuration
├── models/               # Data models and database schemas
├── services/             # Business logic and API services
├── views/                # UI screens and widgets
│   ├── compose/          # Email composition screens
│   ├── settings/         # Settings and configuration
│   └── view/            # Email viewing and management
├── widgets/              # Reusable UI components
├── utils/                # Utility functions and helpers
└── main.dart            # Application entry point
```

### Key Technologies

- **State Management**: GetX for reactive state management
- **Database**: SQLite with sqflite for local data storage
- **Email Protocol**: IMAP/SMTP with enough_mail package
- **UI Framework**: Flutter with Material Design 3
- **Caching**: Multi-level caching with LRU algorithms
- **Security**: Local authentication with biometrics support

## 🔧 Configuration

### Email Account Setup

The app supports various email providers:

- **Gmail**: OAuth2 and App Password authentication
- **Outlook/Hotmail**: Modern authentication support
- **Yahoo Mail**: App-specific password required
- **Custom IMAP/SMTP**: Manual server configuration
- **Exchange**: Basic Exchange server support

### Environment Variables

Create a `.env` file in the project root:

```env
# API Configuration
API_BASE_URL=https://your-api-server.com
API_TIMEOUT=30000

# Security
ENCRYPTION_KEY=your-encryption-key
JWT_SECRET=your-jwt-secret

# Features
ENABLE_ANALYTICS=false
ENABLE_CRASH_REPORTING=true
```

## 📚 Documentation

### For Developers
- [📖 API Documentation](docs/API.md)
- [🏗️ Architecture Guide](docs/ARCHITECTURE.md)
- [🔧 Development Guide](docs/DEVELOPMENT.md)
- [🐛 Troubleshooting](docs/TROUBLESHOOTING.md)
- [🚀 Deployment Guide](docs/DEPLOYMENT.md)

### For Users
- [📱 User Manual](docs/USER_MANUAL.md)
- [⚙️ Settings Guide](docs/SETTINGS.md)
- [🔒 Security Features](docs/SECURITY.md)

## 🧪 Testing

### Run Tests
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Widget tests
flutter test test/widget_test.dart
```

### Test Coverage
```bash
# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Code Style

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` to check code quality
- Format code with `dart format .`
- Write tests for new features

## 📋 Changelog

### Version 2.1.0 (Latest)
- ✅ Fixed email loading and refresh indicator issues
- ✅ Enhanced mailbox switching with proper UID handling
- ✅ Improved draft management with local SQLite storage
- ✅ Added settings-based swipe gesture configuration
- ✅ Implemented priority-based mailbox sorting
- ✅ Enhanced performance with advanced caching
- ✅ Added real-time UI updates with reactive programming

### Version 2.0.0
- 🎉 Complete UI/UX redesign with Material Design 3
- 🔒 Enhanced security features with app lock
- ⚡ Performance optimizations and caching improvements
- 📱 Multi-platform support (iOS, Android, Web)

See [CHANGELOG.md](CHANGELOG.md) for complete version history.

## 🐛 Known Issues

- **WebAssembly Compatibility**: Some packages have WebAssembly limitations
- **Background Sync**: iOS background limitations may affect sync frequency
- **Large Attachments**: Memory usage optimization needed for very large files

See [Issues](https://github.com/dfangys/dits.ly.wahdamail/issues) for current bug reports and feature requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Flutter Team** for the amazing framework
- **GetX Community** for state management solutions
- **enough_mail** package contributors for IMAP/SMTP support
- **Material Design** team for design guidelines

## 📞 Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/dfangys/dits.ly.wahdamail/issues)
- **Discussions**: [GitHub Discussions](https://github.com/dfangys/dits.ly.wahdamail/discussions)
- **Email**: support@wahdabank.com

---

**Made with ❤️ by the Wahda Bank Development Team**

*Building the future of email communication, one commit at a time.*

