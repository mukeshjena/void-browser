import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_dimensions.dart';

class ReaderModeScreen extends ConsumerStatefulWidget {
  final String url;
  final String title;
  final String content;

  const ReaderModeScreen({
    super.key,
    required this.url,
    required this.title,
    required this.content,
  });

  @override
  ConsumerState<ReaderModeScreen> createState() => _ReaderModeScreenState();
}

class _ReaderModeScreenState extends ConsumerState<ReaderModeScreen> {
  double _fontSize = 16.0;
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black87 : Colors.white,
      appBar: AppBar(
        title: const Text('Reader Mode'),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              setState(() {
                _isDarkMode = !_isDarkMode;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: () {
              setState(() {
                _fontSize = (_fontSize - 2).clamp(12.0, 32.0);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: () {
              setState(() {
                _fontSize = (_fontSize + 2).clamp(12.0, 32.0);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: _fontSize + 12,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              widget.content,
              style: TextStyle(
                fontSize: _fontSize,
                color: _isDarkMode ? Colors.white70 : Colors.black87,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppDimensions.xl),
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Source',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.url,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? Colors.blue[300] : Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

