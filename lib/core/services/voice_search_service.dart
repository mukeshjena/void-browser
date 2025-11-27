import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class VoiceSearchService {
  static final VoiceSearchService _instance = VoiceSearchService._internal();
  factory VoiceSearchService() => _instance;
  VoiceSearchService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;

  Future<bool> initialize() async {
    if (_isAvailable) return true;
    
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        return false;
      }

      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        onError: (error) {
          _isListening = false;
        },
      );

      return _isAvailable;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isAvailable() async {
    if (!_isAvailable) {
      await initialize();
    }
    return _isAvailable;
  }

  Future<String?> startListening({
    required Function(String text) onResult,
    Function()? onError,
  }) async {
    if (_isListening) {
      return null;
    }

    if (!await isAvailable()) {
      onError?.call();
      return null;
    }

    String? recognizedText;

    _isListening = true;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          recognizedText = result.recognizedWords;
          _isListening = false;
          onResult(recognizedText!);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
    );

    return recognizedText;
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  bool get isListening => _isListening;

  void dispose() {
    _speech.cancel();
    _isListening = false;
  }
}

