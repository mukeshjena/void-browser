# Void Browser

<div align="center">

![Void Browser](https://img.shields.io/badge/Void-Browser-black?style=for-the-badge&logo=android)
![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?style=for-the-badge&logo=flutter)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android)

**Ultra-lightweight, privacy-focused mobile browser for Android**

[Features](#-features) • [Installation](#-installation) • [Configuration](#-configuration) • [Building](#-building) • [Contributing](#-contributing) • [License](#-license)

</div>

---

## 📱 About

**Void** is an ultra-lightweight, privacy-focused mobile browser built with Flutter for Android. It combines a clean, modern interface inspired by Chrome and Brave with powerful features including ad-blocking, multi-tab management, reader mode, and a discovery panel with news, recipes, weather, and images.

### Key Highlights

- 🚀 **Ultra-lightweight**: Optimized APK size (~16-19MB per architecture)
- 🔒 **Privacy-focused**: Built-in ad-blocking with EasyList filters
- 🎨 **Modern UI**: Chrome/Brave-inspired design with automatic light/dark mode
- ⚡ **Fast & Responsive**: Optimized for low-end devices (1GB RAM minimum)
- 🌐 **Multi-tab Browser**: Unlimited tabs with tab switcher
- 📰 **Discovery Panel**: News, recipes, weather, and images
- 📖 **Reader Mode**: Distraction-free reading experience
- 🔖 **Bookmarks**: Save and organize your favorite sites
- ⬇️ **Download Manager**: Built-in download management

---

## ✨ Features

### Core Browser Features

- ✅ **Full Web Browsing**: Complete WebView-based browser with full JavaScript support
- ✅ **Multi-Tab System**: Create, switch, and manage unlimited tabs (Brave/Chrome style)
- ✅ **Tab Switcher**: Visual tab overview with previews
- ✅ **Search Bar**: Chrome-style search bar with secure/insecure indicators
- ✅ **Navigation**: Swipe gestures for back/forward, pull-to-refresh
- ✅ **Auto-hide AppBar**: AppBar hides on scroll down, shows on scroll up
- ✅ **Search Engine Selection**: Choose between Google, Bing, or DuckDuckGo

### Privacy & Security

- ✅ **Ad-Blocking**: EasyList filter integration for comprehensive ad-blocking
- ✅ **HTTPS Detection**: Visual indicators for secure connections
- ✅ **Privacy Settings**: Configurable ad-block settings

### Discovery Features

- ✅ **News Feed**: Top headlines and trending news with infinite scroll
- ✅ **Recipes**: Discover delicious recipes from TheMealDB
- ✅ **Weather**: GPS-based weather forecasts with location persistence
- ✅ **Images**: Browse beautiful images from Unsplash with full-screen view

### Additional Features

- ✅ **Reader Mode**: Distraction-free reading experience
- ✅ **Bookmarks**: Save and manage your favorite websites
- ✅ **Download Manager**: Download files with progress tracking
- ✅ **Dark Mode**: Automatic light/dark mode following system preferences
- ✅ **Caching**: Intelligent caching for better performance and offline support
- ✅ **State Management**: Persistent state across app restarts

---

## 🛠️ Tech Stack

- **Framework**: Flutter 3.10+
- **Language**: Dart 3.10+
- **State Management**: Riverpod
- **Local Storage**: Hive, SharedPreferences
- **Networking**: Dio
- **WebView**: flutter_inappwebview
- **Architecture**: Clean Architecture (Presentation, Domain, Data layers)

---

## 📋 Prerequisites

Before you begin, ensure you have:

- **Flutter SDK** 3.10.1 or higher
- **Dart SDK** 3.10.1 or higher
- **Android Studio** or **VS Code** with Flutter extensions
- **Android SDK** (API 21+)
- **Java JDK** 17 or higher
- **Git** for version control

### Verify Installation

```bash
flutter doctor
```

Ensure all checks pass before proceeding.

---

## 🚀 Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/void-browser.git
cd void-browser
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Generate Code (if needed)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Configure API Keys

Create a `.env` file in the root directory:

```bash
cp ENV_FILE_TEMPLATE.txt .env
```

Edit `.env` and add your API keys. See [API Keys Setup Guide](docs/API_KEYS_SETUP.md) for detailed instructions.

**Required API Keys:**
- `GNEWS_API_KEY` - For news feed (free tier available)
- `UNSPLASH_ACCESS_KEY` - For images (free tier available)
- Weather API (Open-Meteo) - No API key required
- Recipes API (TheMealDB) - No API key required

### 5. Run the App

```bash
flutter run
```

---

## ⚙️ Configuration

### Environment Variables

The app uses a `.env` file for configuration. See `ENV_FILE_TEMPLATE.txt` for the template.

**Location**: Root directory (`void_browser/.env`)

### App Configuration

Key configuration files:
- `lib/core/constants/app_constants.dart` - App-wide constants
- `lib/core/constants/api_constants.dart` - API endpoints and URLs
- `android/app/build.gradle.kts` - Android build configuration

---

## 🏗️ Building

### Development Build

```bash
flutter build apk --debug
```

### Release Build (APK)

```bash
flutter build apk --release
```

### Release Build (Split APKs - Recommended)

```bash
flutter build apk --release --split-per-abi
```

This creates separate APKs for each architecture:
- `app-armeabi-v7a-release.apk` (~16.5MB)
- `app-arm64-v8a-release.apk` (~18.7MB)
- `app-x86_64-release.apk` (~20.1MB)

### Android App Bundle (AAB) - For Play Store

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab` (~42.8MB)

**Note**: Play Store will automatically optimize and split the AAB for each device architecture.

### Detailed Build Instructions

For complete build and publishing instructions, see:
- [Play Store Publishing Guide](docs/PLAY_STORE_PUBLISHING.md)
- [Optimization Summary](OPTIMIZATION_SUMMARY.md)

---

## 📁 Project Structure

```
void_browser/
├── android/                 # Android-specific files
│   ├── app/
│   │   ├── build.gradle.kts # Build configuration
│   │   └── proguard-rules.pro # ProGuard rules
│   └── gradle.properties    # Gradle properties
├── assets/                  # Assets (icons, images)
│   └── icon/                # App icon
├── docs/                    # Documentation
│   ├── API_KEYS_SETUP.md    # API keys configuration
│   ├── PLAY_STORE_PUBLISHING.md # Publishing guide
│   ├── CONTRIBUTING.md      # Contributing guidelines
│   └── ARCHITECTURE.md      # Architecture overview
├── lib/
│   ├── core/                # Core functionality
│   │   ├── constants/       # App constants
│   │   ├── network/         # Network layer
│   │   ├── storage/         # Storage layer
│   │   └── theme/           # Theme configuration
│   ├── features/            # Feature modules
│   │   ├── browser/         # Browser functionality
│   │   ├── discover/        # Discovery panel
│   │   ├── news/            # News feature
│   │   ├── recipes/         # Recipes feature
│   │   ├── weather/         # Weather feature
│   │   ├── images/          # Images feature
│   │   ├── bookmarks/       # Bookmarks
│   │   ├── downloads/       # Downloads
│   │   ├── settings/        # Settings
│   │   └── adblock/         # Ad-blocking
│   ├── shared/              # Shared widgets
│   └── main.dart            # App entry point
├── .env                     # Environment variables (create from template)
├── ENV_FILE_TEMPLATE.txt    # Environment file template
├── pubspec.yaml             # Flutter dependencies
└── README.md                # This file
```

---

## 🧪 Testing

### Run Tests

```bash
flutter test
```

### Run with Coverage

```bash
flutter test --coverage
```

---

## 📱 Screenshots

_Screenshots coming soon..._

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](docs/CONTRIBUTING.md) for details.

### Quick Start for Contributors

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Flutter Team** - For the amazing framework
- **EasyList** - For ad-blocking filters
- **GNews API** - For news feed
- **TheMealDB** - For recipe data
- **Open-Meteo** - For weather data
- **Unsplash** - For beautiful images
- **Chrome & Brave** - For UI/UX inspiration

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/void-browser/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/void-browser/discussions)
- **Email**: support@voidbrowser.com (if applicable)

---

## 🗺️ Roadmap

- [ ] iOS support
- [ ] Desktop support (Windows, Linux, macOS)
- [ ] Sync bookmarks across devices
- [ ] Custom themes
- [ ] Extension support
- [ ] Password manager integration
- [ ] VPN integration
- [ ] Enhanced privacy features

---

## ⭐ Star History

If you find this project useful, please consider giving it a star ⭐!

---

<div align="center">

**Made with ❤️ using Flutter**

[⬆ Back to Top](#void-browser)

</div>

