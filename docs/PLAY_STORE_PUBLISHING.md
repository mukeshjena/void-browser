# Play Store Publishing Guide

Complete guide for building and publishing Void Browser to Google Play Store.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Build Checklist](#pre-build-checklist)
3. [Building the App Bundle](#building-the-app-bundle)
4. [Signing the App](#signing-the-app)
5. [Play Console Setup](#play-console-setup)
6. [Uploading to Play Store](#uploading-to-play-store)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before publishing, ensure you have:

- ✅ **Google Play Developer Account** ($25 one-time fee)
- ✅ **App signing key** (keystore file)
- ✅ **App icon** (1024x1024px, PNG)
- ✅ **Feature graphic** (1024x500px, PNG)
- ✅ **Screenshots** (at least 2, up to 8)
- ✅ **Privacy Policy URL** (required for apps with permissions)
- ✅ **App description** (short and full)
- ✅ **All API keys configured** (see [API Keys Setup](API_KEYS_SETUP.md))

---

## Pre-Build Checklist

### 1. Update App Version

Edit `pubspec.yaml`:

```yaml
version: 1.0.0+1  # Version name + Version code
```

**Version Code**: Increment for each release (1, 2, 3, ...)
**Version Name**: User-visible version (1.0.0, 1.0.1, 1.1.0, ...)

### 2. Update App Information

Edit `lib/core/constants/app_constants.dart`:

```dart
static const String appVersion = '1.0.0';
```

### 3. Configure App Icon

1. Place your app icon at `assets/icon/app_icon.webp` (1024x1024px, WebP format)
2. Run:

```bash
flutter pub run flutter_launcher_icons
```

Or manually configure in `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  image_path: "assets/icon/app_icon.webp"
  adaptive_icon_background: "#000000"
  adaptive_icon_foreground: "assets/icon/app_icon.webp"
```

### 4. Verify API Keys

Ensure all API keys are configured in `.env` file:
- `GNEWS_API_KEY`
- `UNSPLASH_ACCESS_KEY`

See [API Keys Setup](API_KEYS_SETUP.md) for details.

### 5. Test the App

```bash
# Run on device
flutter run --release

# Test all features
# - Browser navigation
# - Tab management
# - News feed
# - Recipes
# - Weather
# - Images
# - Bookmarks
# - Downloads
# - Settings
```

---

## Building the App Bundle

### Step 1: Create a Keystore (First Time Only)

If you don't have a keystore, create one:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Important**: 
- Store the keystore file securely
- Remember the password
- Keep the alias name (`upload`)
- **DO NOT** commit the keystore to version control

### Step 2: Configure Key Properties

Create `android/key.properties`:

```properties
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=<path-to-keystore>/upload-keystore.jks
```

**Important**: Add `android/key.properties` to `.gitignore`

### Step 3: Update build.gradle.kts

Edit `android/app/build.gradle.kts` to use the keystore:

```kotlin
// Add at the top of the file
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing code ...
    
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    
    buildTypes {
        release {
            // ... existing code ...
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### Step 4: Build the App Bundle

```bash
flutter build appbundle --release
```

**Output**: `build/app/outputs/bundle/release/app-release.aab`

**Expected Size**: ~42.8MB (Play Store will optimize automatically)

### Step 5: Verify the Bundle

Check the bundle:

```bash
# On macOS/Linux
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab --output=app.apks

# Extract and check sizes
unzip app.apks
ls -lh *.apk
```

---

## Signing the App

### Option 1: Google Play App Signing (Recommended)

Google Play can manage your app signing key automatically:

1. Upload your AAB to Play Console
2. Google Play will generate and manage the signing key
3. You only need to keep your upload key

### Option 2: Manual Signing

If you prefer to sign manually:

```bash
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 -keystore upload-keystore.jks app-release.aab upload
```

---

## Play Console Setup

### 1. Create New App

1. Go to [Google Play Console](https://play.google.com/console)
2. Click **Create app**
3. Fill in:
   - **App name**: Void
   - **Default language**: English (United States)
   - **App or game**: App
   - **Free or paid**: Free
   - **Declarations**: Check all applicable boxes

### 2. Set Up App Content

#### Store Listing

**Required Information:**
- **App name**: Void
- **Short description**: Ultra-lightweight privacy browser for Android (80 chars max)
- **Full description**: See [App Description Template](#app-description-template)
- **App icon**: 512x512px PNG
- **Feature graphic**: 1024x500px PNG
- **Screenshots**: 
  - Phone: At least 2, up to 8 (16:9 or 9:16)
  - Tablet: Optional (7" and 10")
- **Category**: Productivity or Communication
- **Tags**: Browser, Privacy, Web, Ad-blocker

**App Description Template:**

```
Void is an ultra-lightweight, privacy-focused mobile browser for Android. Built with Flutter, it combines a clean, modern interface with powerful features.

✨ Features:
• Full web browsing with multi-tab support
• Built-in ad-blocking with EasyList filters
• Discovery panel with news, recipes, weather, and images
• Reader mode for distraction-free reading
• Bookmarks and download manager
• Automatic light/dark mode
• Search engine selection (Google, Bing, DuckDuckGo)

🔒 Privacy:
• No tracking
• Ad-blocking enabled by default
• Secure connection indicators
• Privacy-focused design

⚡ Performance:
• Optimized for low-end devices
• Fast and responsive
• Minimal resource usage

Perfect for users who want a lightweight, privacy-focused browsing experience.
```

#### Privacy Policy

**Required** if your app:
- Requests sensitive permissions
- Collects user data
- Uses third-party services

Create a privacy policy and host it online, then add the URL in Play Console.

**Privacy Policy Template:**

```
Privacy Policy for Void Browser

Last updated: [Date]

Void Browser ("we", "our", or "us") is committed to protecting your privacy.

Data Collection:
- We do not collect, store, or transmit any personal information
- All browsing data is stored locally on your device
- We use third-party APIs (GNews, Unsplash, TheMealDB, Open-Meteo) for discovery features
- Location data is used only for weather forecasts and is not stored or transmitted

Permissions:
- INTERNET: Required for web browsing
- ACCESS_FINE_LOCATION: Optional, for weather forecasts
- WRITE_EXTERNAL_STORAGE: For downloading files

Third-Party Services:
- GNews API: For news feed
- Unsplash API: For images
- TheMealDB: For recipes
- Open-Meteo: For weather data

Contact: [Your email]
```

### 3. Content Rating

1. Complete the content rating questionnaire
2. Answer questions about your app's content
3. Submit for rating (usually takes a few hours)

### 4. Target Audience

- **Age**: Select appropriate age range
- **Content**: Mark if app contains ads, in-app purchases, etc.

### 5. Data Safety

Fill out the Data Safety section:

- **Data collection**: No (if you don't collect data)
- **Data sharing**: No
- **Security practices**: Describe your security measures
- **Data deletion**: Explain how users can delete data

---

## Uploading to Play Store

### Step 1: Create Release

1. Go to **Production** → **Create new release**
2. Upload your AAB file: `app-release.aab`
3. Add **Release name**: `1.0.0 (1)` (Version name + Version code)
4. Add **Release notes**:

```
Initial release of Void Browser

Features:
• Full web browsing with multi-tab support
• Built-in ad-blocking
• Discovery panel with news, recipes, weather, and images
• Reader mode
• Bookmarks and downloads
• Dark mode support
```

### Step 2: Review and Rollout

1. Review all information
2. Click **Save**
3. Click **Review release**
4. If everything looks good, click **Start rollout to Production**

### Step 3: Submit for Review

1. Complete all required sections (Store listing, Content rating, etc.)
2. Click **Submit for review**
3. Wait for review (usually 1-3 days)

---

## Testing

### Internal Testing

Before production release, test with internal testers:

1. Go to **Testing** → **Internal testing**
2. Create a new release
3. Upload AAB
4. Add testers (up to 100)
5. Share test link with testers

### Closed Testing

For broader testing:

1. Go to **Testing** → **Closed testing**
2. Create a new release
3. Upload AAB
4. Create a test track (Alpha/Beta)
5. Add testers via email or Google Groups

### Open Testing

For public beta:

1. Go to **Testing** → **Open testing**
2. Create a new release
3. Upload AAB
4. Anyone can join the test

---

## Troubleshooting

### Build Errors

**Error: Keystore not found**
- Verify `key.properties` path
- Check keystore file exists

**Error: Signing config not found**
- Verify `signingConfigs` in `build.gradle.kts`
- Check keystore properties are loaded correctly

**Error: AAB too large**
- Run `flutter clean`
- Rebuild with optimizations enabled
- Check `OPTIMIZATION_SUMMARY.md`

### Upload Errors

**Error: Version code already exists**
- Increment version code in `pubspec.yaml`
- Rebuild the bundle

**Error: Missing privacy policy**
- Add privacy policy URL in Store listing
- Ensure URL is accessible

**Error: Content rating required**
- Complete content rating questionnaire
- Wait for rating approval

### Review Rejections

**Rejection: Missing functionality**
- Ensure all features work as described
- Test on multiple devices
- Fix bugs before resubmission

**Rejection: Privacy policy issues**
- Update privacy policy
- Ensure it covers all data collection
- Make it easily accessible

---

## Post-Launch

### Monitor Performance

- **Play Console Dashboard**: Track installs, ratings, crashes
- **Analytics**: Monitor user behavior (if implemented)
- **Reviews**: Respond to user feedback

### Update Process

1. Update version in `pubspec.yaml`
2. Make changes
3. Test thoroughly
4. Build new AAB
5. Upload to Play Console
6. Submit for review

### Versioning Strategy

- **Patch** (1.0.0 → 1.0.1): Bug fixes
- **Minor** (1.0.0 → 1.1.0): New features
- **Major** (1.0.0 → 2.0.0): Breaking changes

---

## Resources

- [Google Play Console](https://play.google.com/console)
- [Flutter Build Documentation](https://docs.flutter.dev/deployment/android)
- [Play Store Policies](https://play.google.com/about/developer-content-policy/)
- [App Bundle Guide](https://developer.android.com/guide/app-bundle)

---

## Checklist

Before submitting, ensure:

- [ ] App version updated
- [ ] All API keys configured
- [ ] App icon set
- [ ] Store listing complete
- [ ] Privacy policy added
- [ ] Content rating completed
- [ ] Data Safety form filled
- [ ] App tested on multiple devices
- [ ] No crashes or critical bugs
- [ ] AAB built and signed
- [ ] Release notes written
- [ ] Screenshots uploaded

---

**Good luck with your release! 🚀**

