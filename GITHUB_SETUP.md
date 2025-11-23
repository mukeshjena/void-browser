# GitHub Setup Guide

Quick guide to push Void Browser to GitHub.

---

## 🚀 Initial Setup

### 1. Create GitHub Repository

1. Go to [GitHub](https://github.com/new)
2. Create a new repository:
   - **Name**: `void-browser` (or your preferred name)
   - **Description**: Ultra-lightweight privacy browser for Android
   - **Visibility**: Public (for open source) or Private
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)

### 2. Initialize Git (if not already done)

```bash
# Check if git is initialized
git status

# If not initialized, run:
git init
```

### 3. Add Remote Repository

```bash
git remote add origin https://github.com/yourusername/void-browser.git
# Or use SSH:
# git remote add origin git@github.com:yourusername/void-browser.git
```

### 4. Verify Remote

```bash
git remote -v
```

---

## 📝 Pre-Commit Checklist

Before committing, ensure:

- [ ] `.env` file is **NOT** in the repository (check `.gitignore`)
- [ ] `local.properties` is **NOT** in the repository
- [ ] No API keys are hardcoded in source files
- [ ] Build artifacts are cleaned (`flutter clean` already run)
- [ ] All documentation is complete
- [ ] No sensitive information in any files

---

## 🔒 Security Check

### Files That Should NOT Be Committed

Verify these are in `.gitignore`:
- `.env` - Contains API keys
- `android/local.properties` - Contains user-specific paths
- `*.jks`, `*.keystore` - Signing keys
- `android/key.properties` - Keystore passwords
- `build/` - Build artifacts
- `.dart_tool/` - Dart tooling cache

### Verify Before Committing

```bash
# Check what will be committed
git status

# Check for sensitive files
git ls-files | grep -E "\.env|local\.properties|\.jks|\.keystore|key\.properties"
```

If any sensitive files appear, add them to `.gitignore` and remove from staging:

```bash
git rm --cached <file>
```

---

## 📤 First Commit

### 1. Stage All Files

```bash
git add .
```

### 2. Verify Staged Files

```bash
git status
```

**Important**: Ensure no sensitive files are staged!

### 3. Create Initial Commit

```bash
git commit -m "Initial commit: Void Browser v1.0.0

- Complete browser implementation with multi-tab support
- Discovery panel with news, recipes, weather, and images
- Ad-blocking, bookmarks, downloads, and reader mode
- Clean Architecture with Riverpod state management
- Comprehensive documentation and Play Store publishing guide"
```

### 4. Push to GitHub

```bash
# Push to main branch
git push -u origin main

# Or if using master:
# git push -u origin master
```

---

## 🌿 Branch Strategy

### Main Branches

- `main` - Production-ready code
- `develop` - Development branch (optional)

### Feature Branches

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Work on feature
# ... make changes ...

# Commit changes
git add .
git commit -m "feat: Add your feature"

# Push feature branch
git push origin feature/your-feature-name

# Create PR on GitHub
```

---

## 📋 Recommended Repository Settings

### 1. Repository Settings

1. Go to **Settings** → **General**
2. Enable:
   - ✅ Issues
   - ✅ Discussions
   - ✅ Projects
   - ✅ Wiki (optional)

### 2. Branch Protection (for main branch)

1. Go to **Settings** → **Branches**
2. Add rule for `main` branch:
   - ✅ Require pull request reviews
   - ✅ Require status checks to pass
   - ✅ Require branches to be up to date

### 3. Topics/Tags

Add relevant topics:
- `flutter`
- `dart`
- `android`
- `browser`
- `privacy`
- `ad-blocker`
- `mobile-app`

---

## 🏷️ Release Tags

### Create Release Tag

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# Push tags
git push origin v1.0.0
```

### Create GitHub Release

1. Go to **Releases** → **Draft a new release**
2. **Tag**: `v1.0.0`
3. **Title**: `Void Browser v1.0.0`
4. **Description**: Copy from `CHANGELOG.md`
5. **Attach**: AAB or APK files (optional)
6. **Publish release**

---

## 🔄 Regular Workflow

### Daily Development

```bash
# Pull latest changes
git pull origin main

# Create feature branch
git checkout -b feature/new-feature

# Make changes, commit
git add .
git commit -m "feat: Add new feature"

# Push and create PR
git push origin feature/new-feature
```

### After PR Merge

```bash
# Switch to main
git checkout main

# Pull latest
git pull origin main

# Delete local feature branch
git branch -d feature/new-feature
```

---

## 📊 GitHub Actions

The repository includes a CI workflow (`.github/workflows/ci.yml`) that:
- Runs `flutter analyze` on push/PR
- Runs `flutter test` on push/PR
- Checks code formatting

**Status**: Should show ✅ on all checks before merging PRs.

---

## 🐛 Issue Templates

The repository includes issue templates:
- **Bug Report** (`.github/ISSUE_TEMPLATE/bug_report.md`)
- **Feature Request** (`.github/ISSUE_TEMPLATE/feature_request.md`)

Users can use these when creating issues.

---

## 📝 Pull Request Template

PRs automatically use the template (`.github/PULL_REQUEST_TEMPLATE.md`) which includes:
- Description
- Type of change
- Testing checklist
- Code review checklist

---

## ✅ Final Checklist

Before pushing to GitHub:

- [ ] All sensitive files are in `.gitignore`
- [ ] `flutter clean` has been run
- [ ] All documentation is complete
- [ ] README.md is updated
- [ ] LICENSE file is present
- [ ] CHANGELOG.md is updated
- [ ] No API keys in source code
- [ ] No user-specific paths in files
- [ ] Git is initialized
- [ ] Remote is configured
- [ ] Ready to commit and push

---

## 🚨 Common Issues

### "Permission denied"
- Check SSH keys or use HTTPS with personal access token
- Verify GitHub credentials

### "Large file detected"
- Use Git LFS for large files (if needed)
- Or remove large files from history

### "Merge conflicts"
- Pull latest changes first
- Resolve conflicts manually
- Test before pushing

---

## 📚 Resources

- [GitHub Docs](https://docs.github.com/)
- [Git Handbook](https://guides.github.com/introduction/git-handbook/)
- [Flutter CI/CD](https://docs.flutter.dev/deployment/ci-cd)

---

**Your repository is now ready for open source! 🎉**

