import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> with SingleTickerProviderStateMixin {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;
  bool _hasTriggeredAuth = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _animationController.forward();
    
    // Auto-trigger authentication after animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_hasTriggeredAuth) {
          _authenticate();
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    // Prevent multiple simultaneous authentication attempts
    if (_isAuthenticating) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _hasTriggeredAuth = true;
    });

    try {
      // Check if device supports biometrics
      final isDeviceSupported = await _biometricService.isAvailable();
      if (!isDeviceSupported && mounted) {
        // If biometrics not available, just unlock (fallback)
        Navigator.of(context).pop(true);
        return;
      }

      // Call authenticate - this will show the system biometric dialog
      final didAuthenticate = await _biometricService.authenticate(
        reason: 'Unlock ${AppConstants.appName}',
      );

      if (didAuthenticate && mounted) {
        // Authentication successful, unlock the app
        Navigator.of(context).pop(true);
      } else if (mounted) {
        // Authentication failed or cancelled - reset flag to allow manual retry
        setState(() {
          _isAuthenticating = false;
          _hasTriggeredAuth = false; // Allow manual retry
        });
      }
    } catch (e) {
      // If error occurs, reset flag
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _hasTriggeredAuth = false;
        });
      }
    }
  }

  void _handleQuit() {
    // Exit the app
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        // Prevent back button from closing the lock screen
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkPrimaryBg : AppColors.lightPrimaryBg,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: isDark 
                              ? AppColors.darkCardBg 
                              : AppColors.lightCardBg,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                                  .withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: isDark 
                              ? AppColors.darkPrimary 
                              : AppColors.lightPrimary,
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // App Name
                      Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isDark 
                              ? AppColors.darkTextPrimary 
                              : AppColors.lightTextPrimary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Instructions
                      Text(
                        'Unlock to continue',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark 
                              ? AppColors.darkTextSecondary 
                              : AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'Use your fingerprint or face to unlock',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark 
                              ? AppColors.darkTextTertiary 
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Authenticate Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isAuthenticating ? null : _authenticate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark 
                                ? AppColors.darkPrimary 
                                : AppColors.lightPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            disabledBackgroundColor: (isDark 
                                ? AppColors.darkPrimary 
                                : AppColors.lightPrimary).withOpacity(0.6),
                          ),
                          child: _isAuthenticating
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.fingerprint,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Authenticate',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Quit Button
                      TextButton(
                        onPressed: _handleQuit,
                        style: TextButton.styleFrom(
                          foregroundColor: isDark 
                              ? AppColors.darkTextSecondary 
                              : AppColors.lightTextSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Quit App',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
