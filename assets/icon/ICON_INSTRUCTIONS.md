# App Icon Setup Instructions

## Current Status
✅ Flutter Launcher Icons package is installed and configured
✅ Icon generator has been run successfully
✅ Icons have been generated for all Android densities

## To Add a Custom Icon

1. **Create or obtain your icon image:**
   - Size: 1024x1024 pixels (square)
   - Format: PNG with transparency
   - Design: Simple, recognizable icon for "Void" browser

2. **Replace the icon file:**
   - Place your custom icon at: `assets/icon/app_icon.png`
   - Make sure it's exactly 1024x1024 pixels

3. **Regenerate icons:**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

4. **Rebuild your app:**
   ```bash
   flutter clean
   flutter build apk --release
   ```

## Recommended Icon Design
- Black background (#000000) to match the app theme
- White or blue "V" letter for "Void"
- Simple, modern design
- High contrast for visibility

## Online Icon Generators
You can use these tools to create your icon:
- https://www.favicon-generator.org/
- https://www.appicon.co/
- https://icon.kitchen/

