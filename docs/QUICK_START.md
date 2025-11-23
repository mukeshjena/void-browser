# Quick Start Guide

Get Void Browser up and running in 5 minutes!

---

## 🚀 Quick Setup

### 1. Prerequisites

Ensure you have:
- Flutter 3.10.1+ installed
- Android Studio or VS Code
- Android device or emulator

**Verify**:
```bash
flutter doctor
```

### 2. Clone & Install

```bash
# Clone the repository
git clone https://github.com/yourusername/void-browser.git
cd void-browser

# Install dependencies
flutter pub get
```

### 3. Configure API Keys

```bash
# Copy template
cp ENV_FILE_TEMPLATE.txt .env

# Edit .env and add your API keys
# See docs/API_KEYS_SETUP.md for details
```

**Minimum Required**:
- `GNEWS_API_KEY` - Get free at [gnews.io](https://gnews.io/)
- `UNSPLASH_ACCESS_KEY` - Get free at [unsplash.com/developers](https://unsplash.com/developers)

### 4. Run the App

```bash
flutter run
```

That's it! 🎉

---

## 📱 First Run

1. **Grant Permissions** (if prompted):
   - Location (for weather)
   - Storage (for downloads)

2. **Explore Features**:
   - Browse the web
   - Check out the Discovery panel
   - Try multi-tab browsing
   - Test ad-blocking

---

## 🛠️ Common Issues

### "API key not found"
- Ensure `.env` file exists in root directory
- Check API key variable names match exactly
- Restart the app after adding keys

### "Build failed"
- Run `flutter clean`
- Run `flutter pub get`
- Check Flutter version: `flutter --version`

### "No devices found"
- Connect Android device via USB
- Enable USB debugging
- Or start an emulator

---

## 📚 Next Steps

- **Build for Release**: See [Play Store Publishing Guide](PLAY_STORE_PUBLISHING.md)
- **Configure APIs**: See [API Keys Setup](API_KEYS_SETUP.md)
- **Contribute**: See [Contributing Guide](CONTRIBUTING.md)
- **Understand Architecture**: See [Architecture Overview](ARCHITECTURE.md)

---

## 💡 Tips

- Use **AAB** format for Play Store (smaller downloads)
- Use **split APKs** for direct distribution
- Test on multiple devices before release
- Monitor API usage in provider dashboards

---

**Need Help?** Check the [full documentation](../README.md) or open an issue on GitHub.

