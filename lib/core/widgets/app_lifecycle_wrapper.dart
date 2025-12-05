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
  DateTime? _lastResumedTime; // Track when app last resumed
  int _rapidPauseResumeCount = 0; // Track rapid pause/resume cycles (system UI overlays)
  static const Duration _gracePeriod = Duration(seconds: 10); // Increased grace period after successful unlock
  static const Duration _lockDelay = Duration(seconds: 5); // Lock after 5 seconds of being paused
  static const Duration _dismissCooldown = Duration(seconds: 2); // Increased cooldown after dismissing lock screen
  static const Duration _systemOverlayThreshold = Duration(milliseconds: 500); // If pause/resume happens within 500ms, it's likely a system overlay
  static const int _maxRapidCycles = 3; // Maximum rapid cycles before ignoring them

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

    final now = DateTime.now();

    if (state == AppLifecycleState.paused) {
      // App went to background or screen turned off
      _lastPausedTime = now;
      
      // Reset rapid cycle counter if enough time has passed since last resume
      if (_lastResumedTime != null) {
        final timeSinceResume = now.difference(_lastResumedTime!);
        if (timeSinceResume > _systemOverlayThreshold) {
          _rapidPauseResumeCount = 0; // Reset counter if it's been a while
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      // App came to foreground or screen turned on
      _lastResumedTime = now;
      
      // Don't show lock screen if already showing or just dismissed
      if (_isLocked || _isShowingLockScreen) {
        return;
      }

      // Check if lock screen was just dismissed (cooldown period)
      if (_lastLockScreenDismissed != null) {
        final timeSinceDismiss = now.difference(_lastLockScreenDismissed!);
        if (timeSinceDismiss < _dismissCooldown) {
          return;
        }
      }

      // Check if we're in grace period (just unlocked)
      if (_lastSuccessfulUnlock != null) {
        final timeSinceUnlock = now.difference(_lastSuccessfulUnlock!);
        if (timeSinceUnlock < _gracePeriod) {
          // Still in grace period, don't lock again
          return;
        }
      }

      // Detect system overlay (notification drawer, popups) - rapid pause/resume cycles
      if (_lastPausedTime != null) {
        final pauseDuration = now.difference(_lastPausedTime!);
        
        // If pause/resume happened very quickly, it's likely a system overlay
        if (pauseDuration < _systemOverlayThreshold) {
          _rapidPauseResumeCount++;
          
          // If we've had multiple rapid cycles, ignore them (system UI overlays)
          if (_rapidPauseResumeCount >= _maxRapidCycles) {
            // Reset pause time to prevent locking
            _lastPausedTime = null;
            return; // Don't show lock screen for system overlays
          }
          
          // For first few rapid cycles, still check but be more lenient
          // Only lock if it's been a significant pause AND not in grace period
          if (pauseDuration < Duration(milliseconds: 200)) {
            // Very rapid (definitely system overlay), ignore
            _lastPausedTime = null;
            return;
          }
        } else {
          // Normal pause duration, reset rapid cycle counter
          _rapidPauseResumeCount = 0;
        }
      } else {
        // No pause time recorded - this shouldn't normally happen
        // But if it does, don't lock unless we're sure user left the app
        // Check if we recently resumed (within last second) - if so, ignore
        if (_lastResumedTime != null) {
          final timeSinceLastResume = now.difference(_lastResumedTime!);
          if (timeSinceLastResume < Duration(seconds: 1)) {
            // Just resumed recently, likely a system overlay, don't lock
            return;
          }
        }
      }

      // Check if we should lock based on pause duration
      if (_lastPausedTime != null) {
        final timeSincePause = now.difference(_lastPausedTime!);
        // Lock if app was paused for more than 5 seconds
        if (timeSincePause >= _lockDelay) {
          _showLockScreen();
        }
        // Reset pause time after checking
        _lastPausedTime = null;
      }
      // Removed the else block that was causing issues - only lock if we have a valid pause time
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

