import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../news/presentation/screens/news_screen.dart';
import '../../../images/presentation/screens/images_screen.dart';
import '../providers/browser_navigation_provider.dart';
import 'browser_tab_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const BrowserTabScreen(), // Browser with tabs (discover is home page)
    const NewsScreen(),
    const ImagesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Listen to browser navigation requests
    ref.listen(browserNavigationProvider, (previous, next) {
      // Switch tabs if the index changed
      if (next.tabIndex != _currentIndex) {
        setState(() {
          _currentIndex = next.tabIndex;
        });
      }
    });
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            ref.read(browserNavigationProvider.notifier).switchTab(index);
          },
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore, size: 24),
              activeIcon: Icon(Icons.explore, size: 24),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.article, size: 24),
              activeIcon: Icon(Icons.article, size: 24),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.collections, size: 24),
              activeIcon: Icon(Icons.collections, size: 24),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}
