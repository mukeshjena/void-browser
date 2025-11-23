extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }

  bool get isUrl {
    return startsWith('http://') || startsWith('https://');
  }

  String get domain {
    try {
      final uri = Uri.parse(this);
      return uri.host;
    } catch (e) {
      return this;
    }
  }
}

