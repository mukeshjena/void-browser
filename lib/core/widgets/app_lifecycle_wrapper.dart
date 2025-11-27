import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/biometric_service.dart';
import '../../features/settings/presentation/providers/settings_provider.dart';
import '../../features/settings/presentation/widgets/lock_screen.dart';

class AppLifecycleWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecycleWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends ConsumerState<AppLifecycleWrapper> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _hasCheckedInitialLock = false;
  bool _isShowingLockScreen = false; // Track if we're currently showing lock screen
  DateTime? _lastPausedTime;
  DateTime? _lastSuccessfulUnlock; // Track when authentication was last successful
  DateTime? _lastLockScreenDismissed; // Track when lock screen was last dismissed
  static const Duration _gracePeriod = Duration(seconds: 3); // Grace period after successful unlock
  static const Duration _lockDelay = Duration(seconds: 5); // Lock after 5 seconds of being paused
  static const Duration _dismissCooldown = Duration(seconds: 1); // Cooldown after dismissing lock screen

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkInitialLock() async {
    if (_hasCheckedInitialLock) return;
    _hasCheckedInitialLock = true;

    final settings = ref.read(settingsProvider);
    if (settings.fingerprintLockEnabled) {
      final biometricService = BiometricService();
      final isAvailable = await biometricService.isAvailable();
      if (isAvailable) {
        _showLockScreen();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = ref.read(settingsProvider);
    
    if (!settings.fingerprintLockEnabled) {
      return;
    }

    if (state == AppLifecycleState.paused) {
      // App went to background or screen turned off
      _lastPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // App came to foreground or screen turned on
      
      // Don't show lock screen if already showing or just dismissed
      if (_isLocked || _isShowingLockScreen) {
        return;
      }

      // Check if lock screen was just dismissed (cooldown period)
      if (_lastLockScreenDismissed != null) {
        final timeSinceDismiss = DateTime.now().difference(_lastLockScreenDismissed!);
        if (timeSinceDismiss < _dismissCooldown) {
          return;
        }
      }

      // Check if we're in grace period (just unlocked)
      if (_lastSuccessfulUnlock != null) {
        final timeSinceUnlock = DateTime.now().difference(_lastSuccessfulUnlock!);
        if (timeSinceUnlock < _gracePeriod) {
          // Still in grace period, don't lock again
          return;
        }
      }

      // Check if we should lock based on pause duration
      if (_lastPausedTime != null) {
        final timeSincePause = DateTime.now().difference(_lastPausedTime!);
        // Lock if app was paused for more than 5 seconds
        if (timeSincePause >= _lockDelay) {
          _showLockScreen();
        }
      } else {
        // If no pause time recorded but app resumed, check if we should lock
        // This handles cases where screen was turned off/on quickly
        // Only lock if not in grace period
        if (_lastSuccessfulUnlock == null || 
            DateTime.now().difference(_lastSuccessfulUnlock!) >= _gracePeriod) {
          _showLockScreen();
        }
      }
    }
  }

  void _showLockScreen() {
    // Prevent multiple simultaneous lock screen attempts
    if (_isLocked || _isShowingLockScreen) return;
    
    // Check grace period one more time before showing
    if (_lastSuccessfulUnlock != null) {
      final timeSinceUnlock = DateTime.now().difference(_lastSuccessfulUnlock!);
      if (timeSinceUnlock < _gracePeriod) {
        // Still in grace period, don't show lock screen
        return;
      }
    }
    
    // Check cooldown period
    if (_lastLockScreenDismissed != null) {
      final timeSinceDismiss = DateTime.now().difference(_lastLockScreenDismissed!);
      if (timeSinceDismiss < _dismissCooldown) {
        return;
      }
    }
    
    // Use a small delay to prevent multiple rapid calls
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || _isLocked || _isShowingLockScreen) return;
      
      // Double-check grace period after delay
      if (_lastSuccessfulUnlock != null) {
        final timeSinceUnlock = DateTime.now().difference(_lastSuccessfulUnlock!);
        if (timeSinceUnlock < _gracePeriod) {
          return;
        }
      }
      
      setState(() {
        _isLocked = true;
        _isShowingLockScreen = true;
      });

      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => const LockScreen(),
          fullscreenDialog: true,
        ),
      ).then((unlocked) {
        if (mounted) {
          if (unlocked == true) {
            // Authentication successful - record the time
            setState(() {
              _isLocked = false;
              _isShowingLockScreen = false;
              _lastSuccessfulUnlock = DateTime.now();
              _lastLockScreenDismissed = DateTime.now();
            });
          } else {
            // If authentication was cancelled, reset lock state after a delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                setState(() {
                  _isLocked = false;
                  _isShowingLockScreen = false;
                  _lastLockScreenDismissed = DateTime.now();
                });
              }
            });
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

