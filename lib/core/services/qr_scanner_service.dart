import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerService {
  static final QRScannerService _instance = QRScannerService._internal();
  factory QRScannerService() => _instance;
  QRScannerService._internal();

  MobileScannerController? _controller;

  MobileScannerController getController() {
    _controller ??= MobileScannerController();
    return _controller!;
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}

