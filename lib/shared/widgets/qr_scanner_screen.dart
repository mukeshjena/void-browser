import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  final Function(String)? onQRCodeScanned;

  const QRScannerScreen({
    super.key,
    this.onQRCodeScanned,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  final String code = barcode.rawValue!;
                  widget.onQRCodeScanned?.call(code);
                  Navigator.pop(context);
                  break;
                }
              }
            },
          ),
          // Overlay with scanning area
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: CustomPaint(
              painter: _ScannerOverlayPainter(),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final scanAreaLeft = (size.width - scanAreaSize) / 2;
    final scanAreaTop = (size.height - scanAreaSize) / 2;

    // Draw dark overlay
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final scanPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(scanAreaLeft, scanAreaTop, scanAreaSize, scanAreaSize),
          const Radius.circular(20),
        ),
      );

    final cutoutPath = Path.combine(
      PathOperation.difference,
      path,
      scanPath,
    );

    canvas.drawPath(cutoutPath, paint);

    // Draw corner indicators
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final cornerLength = 30.0;
    final cornerWidth = 4.0;

    // Top-left corner
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + cornerLength),
      Offset(scanAreaLeft, scanAreaTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop),
      Offset(scanAreaLeft + cornerLength, scanAreaTop),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize - cornerLength),
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + cornerLength, scanAreaTop + scanAreaSize),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize - cornerLength),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

