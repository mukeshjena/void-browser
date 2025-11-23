import 'package:flutter/material.dart';
import '../theme/app_dimensions.dart';

enum ScreenSize { small, medium, large }

class ResponsiveHelper {
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < AppDimensions.breakpointSmall) {
      return ScreenSize.small;
    } else if (width < AppDimensions.breakpointMedium) {
      return ScreenSize.medium;
    } else {
      return ScreenSize.large;
    }
  }

  static bool isSmallScreen(BuildContext context) {
    return getScreenSize(context) == ScreenSize.small;
  }

  static bool isMediumScreen(BuildContext context) {
    return getScreenSize(context) == ScreenSize.medium;
  }

  static bool isLargeScreen(BuildContext context) {
    return getScreenSize(context) == ScreenSize.large;
  }

  static double getAddressBarHeight(BuildContext context) {
    return isSmallScreen(context)
        ? AppDimensions.addressBarHeightSmall
        : AppDimensions.addressBarHeight;
  }

  static double getBottomNavHeight(BuildContext context) {
    return isSmallScreen(context)
        ? AppDimensions.bottomNavHeightSmall
        : AppDimensions.bottomNavHeight;
  }

  static int getGridColumns(BuildContext context) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return 2;
      case ScreenSize.medium:
        return 3;
      case ScreenSize.large:
        return 4;
    }
  }

  static EdgeInsets getPagePadding(BuildContext context) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return const EdgeInsets.all(AppDimensions.md);
      case ScreenSize.medium:
        return const EdgeInsets.all(AppDimensions.lg);
      case ScreenSize.large:
        return const EdgeInsets.all(AppDimensions.xl);
    }
  }
}

