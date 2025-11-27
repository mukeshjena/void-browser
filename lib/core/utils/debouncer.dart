import 'dart:async';
import 'package:flutter/material.dart';

/// Debouncer utility for delaying function calls
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Call the function after delay, canceling any pending calls
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel any pending calls
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose the debouncer
  void dispose() {
    cancel();
  }
}
