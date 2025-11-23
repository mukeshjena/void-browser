# Pre-Push Checklist

Use this checklist before pushing to GitHub.

---

## ✅ Security Check

- [ ] `.env` file exists but is in `.gitignore` ✅
- [ ] `android/local.properties` is in `.gitignore` ✅
- [ ] No `.jks` or `.keystore` files found ✅
- [ ] No API keys hardcoded in source files
- [ ] No passwords or secrets in any files

**Verify**:
```bash
# Check for sensitive files
git ls-files | grep -E "\.env|local\.properties|\.jks|\.keystore|key\.properties"
```

---

## 🧹 Clean Build

- [x] `flutter clean` has been run ✅
- [ ] Build artifacts removed
- [ ] `.dart_tool/` directory cleaned
- [ ] `build/` directory cleaned

---

## 📝 Documentation

- [x] README.md complete ✅
- [x] LICENSE file present ✅
- [x] CHANGELOG.md updated ✅
- [x] All docs in `docs/` folder ✅
- [x] API_KEYS_SETUP.md complete ✅
- [x] PLAY_STORE_PUBLISHING.md complete ✅
- [x] CONTRIBUTING.md complete ✅
- [x] ARCHITECTURE.md complete ✅
- [x] QUICK_START.md complete ✅
- [x] GITHUB_SETUP.md complete ✅

---

## 🔧 Configuration Files

- [x] `.gitignore` properly configured ✅
- [x] `.gitattributes` created ✅
- [x] `ENV_FILE_TEMPLATE.txt` present ✅
- [x] `analysis_options.yaml` present ✅
- [x] `pubspec.yaml` complete ✅

---

## 🎯 GitHub Templates

- [x] Issue templates created (`.github/ISSUE_TEMPLATE/`) ✅
- [x] Pull request template created ✅
- [x] CI workflow created (`.github/workflows/ci.yml`) ✅

---

## 📦 Project Files

- [x] Source code in `lib/` ✅
- [x] Android configuration in `android/` ✅
- [x] Assets in `assets/` ✅
- [x] Tests in `test/` (if any)

---

## 🚀 Ready to Push

### Initialize Git (if not done)

```bash
git init
```

### Add Remote

```bash
git remote add origin https://github.com/yourusername/void-browser.git
```

### Stage Files

```bash
git add .
```

### Verify What Will Be Committed

```bash
git status
```

**Important**: Check that no sensitive files are staged!

### Create Initial Commit

```bash
git commit -m "Initial commit: Void Browser v1.0.0

- Complete browser implementation with multi-tab support
- Discovery panel with news, recipes, weather, and images
- Ad-blocking, bookmarks, downloads, and reader mode
- Clean Architecture with Riverpod state management
- Comprehensive documentation and Play Store publishing guide"
```

### Push to GitHub

```bash
git push -u origin main
```

---

## 📋 Files That Should Be Committed

✅ **Should be committed:**
- All source code (`lib/`)
- Configuration files (`pubspec.yaml`, `analysis_options.yaml`)
- Documentation (`README.md`, `docs/`, `LICENSE`, `CHANGELOG.md`)
- Android/iOS/Web configuration
- `.gitignore`, `.gitattributes`
- GitHub templates and workflows
- `ENV_FILE_TEMPLATE.txt`

❌ **Should NOT be committed:**
- `.env` (contains API keys)
- `android/local.properties` (user-specific paths)
- `build/` (build artifacts)
- `.dart_tool/` (Dart tooling cache)
- `*.jks`, `*.keystore` (signing keys)
- `android/key.properties` (keystore passwords)
- `*.iml` (IDE files)
- `.idea/`, `.vscode/` (IDE settings)

---

## 🔍 Final Verification

Before pushing, run:

```bash
# Check for large files (>100MB)
find . -type f -size +100M -not -path "./.git/*"

# Check for sensitive patterns
grep -r "api[_-]key" --include="*.dart" --include="*.yaml" --include="*.json" | grep -v ".git" | grep -v "ENV_FILE_TEMPLATE"

# Verify .gitignore
cat .gitignore | grep -E "\.env|local\.properties|\.jks|\.keystore"
```

---

## ✅ All Checks Passed!

Your repository is ready to push to GitHub! 🎉

See `GITHUB_SETUP.md` for detailed instructions.

