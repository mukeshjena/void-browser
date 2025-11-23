# Contributing to Void Browser

Thank you for your interest in contributing to Void Browser! This document provides guidelines and instructions for contributing.

---

## 📋 Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Workflow](#development-workflow)
4. [Coding Standards](#coding-standards)
5. [Commit Guidelines](#commit-guidelines)
6. [Pull Request Process](#pull-request-process)
7. [Testing](#testing)
8. [Documentation](#documentation)

---

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors, regardless of background, experience level, gender, gender identity and expression, sexual orientation, disability, personal appearance, body size, race, ethnicity, age, religion, or nationality.

### Expected Behavior

- Be respectful and considerate
- Welcome newcomers and help them learn
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

---

## Getting Started

### 1. Fork the Repository

1. Click the "Fork" button on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/yourusername/void-browser.git
   cd void-browser
   ```

### 2. Set Up Development Environment

1. **Install Flutter** (3.10.1+):
   ```bash
   flutter doctor
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Set Up API Keys**:
   ```bash
   cp ENV_FILE_TEMPLATE.txt .env
   # Edit .env and add your API keys
   ```
   See [API Keys Setup](API_KEYS_SETUP.md) for details.

4. **Generate Code** (if needed):
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

### 3. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

**Branch Naming**:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation
- `refactor/` - Code refactoring
- `test/` - Test additions/changes
- `chore/` - Maintenance tasks

---

## Development Workflow

### 1. Make Changes

- Write clean, readable code
- Follow the coding standards (see below)
- Add tests for new features
- Update documentation as needed

### 2. Test Your Changes

```bash
# Run tests
flutter test

# Run on device
flutter run

# Check for issues
flutter analyze
```

### 3. Commit Changes

Follow the [Commit Guidelines](#commit-guidelines) below.

### 4. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

### 5. Create Pull Request

1. Go to the original repository on GitHub
2. Click "New Pull Request"
3. Select your branch
4. Fill out the PR template
5. Submit for review

---

## Coding Standards

### Dart Style Guide

Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) style guide.

**Key Points**:
- Use `dart format` to format code
- Follow naming conventions:
  - Classes: `PascalCase`
  - Variables/Functions: `camelCase`
  - Constants: `UPPER_SNAKE_CASE`
- Maximum line length: 80 characters (soft limit)
- Use meaningful variable names
- Add comments for complex logic

### Architecture

Follow Clean Architecture principles:

```
lib/
├── core/           # Core functionality (constants, utils, network)
├── features/       # Feature modules
│   └── feature_name/
│       ├── data/           # Data layer (models, repositories)
│       ├── domain/         # Domain layer (entities, use cases)
│       └── presentation/    # Presentation layer (screens, widgets, providers)
└── shared/         # Shared widgets and utilities
```

### Code Formatting

```bash
# Format all Dart files
dart format .

# Or use IDE formatting (Ctrl+Shift+F / Cmd+Shift+F)
```

### Linting

The project uses `flutter_lints`. Run:

```bash
flutter analyze
```

Fix all warnings and errors before submitting a PR.

---

## Commit Guidelines

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples**:

```
feat(browser): Add tab switcher UI

Implement visual tab switcher similar to Chrome/Brave with grid layout and preview thumbnails.

Closes #123
```

```
fix(discover): Fix weather location persistence

Weather location now persists across app restarts using SharedPreferences.

Fixes #456
```

### Commit Best Practices

- Write clear, descriptive commit messages
- Keep commits focused (one logical change per commit)
- Reference issues in commit messages
- Use present tense ("Add feature" not "Added feature")

---

## Pull Request Process

### PR Checklist

Before submitting a PR, ensure:

- [ ] Code follows the style guidelines
- [ ] All tests pass
- [ ] No linting errors (`flutter analyze`)
- [ ] Documentation is updated
- [ ] Commit messages follow guidelines
- [ ] Branch is up to date with `main`
- [ ] Changes are tested on a real device

### PR Template

When creating a PR, include:

1. **Description**: What changes were made and why
2. **Type**: Feature, Bug Fix, Documentation, etc.
3. **Testing**: How the changes were tested
4. **Screenshots**: If UI changes were made
5. **Related Issues**: Link to related issues

### PR Review Process

1. **Automated Checks**: CI will run tests and linting
2. **Code Review**: Maintainers will review your code
3. **Feedback**: Address any requested changes
4. **Approval**: Once approved, your PR will be merged

---

## Testing

### Writing Tests

- Write unit tests for business logic
- Write widget tests for UI components
- Write integration tests for user flows

### Test Structure

```dart
// test/features/browser/presentation/providers/tabs_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:void_browser/features/browser/presentation/providers/tabs_provider.dart';

void main() {
  group('TabsProvider', () {
    test('should create initial discover tab', () {
      // Test implementation
    });
  });
}
```

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/features/browser/presentation/providers/tabs_provider_test.dart

# Run with coverage
flutter test --coverage
```

---

## Documentation

### Code Documentation

- Add doc comments for public APIs:
  ```dart
  /// Creates a new browser tab with the specified URL.
  ///
  /// If [url] is null or empty, creates a discover tab.
  /// Returns the ID of the newly created tab.
  String createTab({String? url});
  ```

### README Updates

- Update README.md if adding new features
- Update API documentation if changing APIs
- Update setup instructions if process changes

---

## Feature Development

### Before Starting

1. **Check Existing Issues**: See if the feature is already requested
2. **Discuss**: Open an issue to discuss the feature
3. **Get Approval**: Wait for maintainer approval before starting

### During Development

1. **Keep It Small**: Break large features into smaller PRs
2. **Test Thoroughly**: Test on multiple devices and Android versions
3. **Update Docs**: Update relevant documentation

### After Completion

1. **Update CHANGELOG**: Add entry to CHANGELOG.md
2. **Update Tests**: Ensure all tests pass
3. **Request Review**: Submit PR for review

---

## Bug Reports

### Before Reporting

1. **Search Issues**: Check if the bug is already reported
2. **Reproduce**: Ensure you can consistently reproduce the bug
3. **Gather Info**: Collect device info, logs, screenshots

### Bug Report Template

```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '...'
3. See error

**Expected behavior**
What you expected to happen.

**Screenshots**
If applicable, add screenshots.

**Device Information**
- Device: [e.g. Samsung Galaxy S21]
- OS: [e.g. Android 12]
- App Version: [e.g. 1.0.0]

**Additional context**
Any other relevant information.
```

---

## Questions?

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and discussions
- **Documentation**: Check the docs folder for detailed guides

---

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Credited in release notes
- Appreciated by the community! 🙏

---

**Thank you for contributing to Void Browser! 🚀**

