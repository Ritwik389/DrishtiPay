import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vibration/vibration.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

final flutterTtsProvider = Provider((ref) => FlutterTts());
final speechToTextProvider = Provider((ref) => SpeechToText());

class AccessibilityManager extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> _applyTtsVoice(FlutterTts tts) async {
    await tts.setLanguage("en-IN");
    try {
      final List<dynamic> voices = await tts.getVoices;
      for (var voice in voices) {
        if (voice['name'].toString().toLowerCase().contains('female') ||
            voice['name']
                .toString()
                .toLowerCase()
                .contains('en-in-x-ahp-local')) {
          await tts.setVoice({
            "name": voice['name'],
            "locale": voice['locale']
          });
          break;
        }
      }
    } catch (e) {
      debugPrint("Could not set female voice: $e");
    }
    await tts.setPitch(1.2);
  }

  Future<void> speak(String text) async {
    final tts = ref.read(flutterTtsProvider);
    await _applyTtsVoice(tts);
    await tts.awaitSpeakCompletion(false);
    await tts.speak(text);
  }

  Future<void> speakAndWait(String text) async {
    final tts = ref.read(flutterTtsProvider);
    await _applyTtsVoice(tts);
    await tts.awaitSpeakCompletion(true);
    await tts.speak(text);
    await tts.awaitSpeakCompletion(false);
  }

  /// 🔥 FIXED: Now compatible with your QR scanner code
  Future<void> stop() async {
    final tts = ref.read(flutterTtsProvider);
    await tts.stop();
  }

  /// Existing method (kept for compatibility)
  Future<void> stopSpeaking() async {
    final tts = ref.read(flutterTtsProvider);
    await tts.stop();
  }

  Future<void> vibrateShort() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 100);
    }
  }

  Future<void> vibrateLong() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 500);
    }
  }

  Future<void> vibratePulse() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [500, 500], repeat: 1);
    }
  }

  void stopVibration() {
    Vibration.cancel();
  }

  void resetPaymentSession() {
    ref.read(amountProvider.notifier).state = '0';
    ref.read(upiIdProvider.notifier).state = '';
    ref.read(merchantNameProvider.notifier).state = 'Sharma Grocery';
    ref.read(pinStrokesProvider.notifier).state = 0;
  }

  void activateDrishtiPay() {
    resetPaymentSession();
    state = true;
    speak("DrishtiPay Activated");
  }

  void deactivateDrishtiPay() {
    state = false;
    resetPaymentSession();
  }

  Future<bool> checkBiometrics() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics =
          await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();
      if (canAuthenticate) {
        return await auth.authenticate(
          localizedReason: 'Please authenticate to complete the payment',
        );
      }
    } catch (e) {
      debugPrint("Biometric Error: $e");
    }
    return false;
  }

  String encryptTransaction(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return base64.encode(utf8.encode("ENC-$digest"));
  }
}

final accessibilityProvider =
    NotifierProvider<AccessibilityManager, bool>(AccessibilityManager.new);

// ── State providers ──────────────────────────────────────────────────────────

class AmountNotifier extends Notifier<String> {
  @override
  String build() => "0";
  @override
  set state(String val) => super.state = val;
}
final amountProvider =
    NotifierProvider<AmountNotifier, String>(AmountNotifier.new);

class MerchantNotifier extends Notifier<String> {
  @override
  String build() => "Sharma Grocery";
  @override
  set state(String val) => super.state = val;
}
final merchantNameProvider =
    NotifierProvider<MerchantNotifier, String>(MerchantNotifier.new);

class UpiIdNotifier extends Notifier<String> {
  @override
  String build() => "";
  @override
  set state(String val) => super.state = val;
}
final upiIdProvider =
    NotifierProvider<UpiIdNotifier, String>(UpiIdNotifier.new);

class PinStrokeNotifier extends Notifier<int> {
  @override
  int build() => 0;
  @override
  set state(int val) => super.state = val;
}
final pinStrokesProvider =
    NotifierProvider<PinStrokeNotifier, int>(PinStrokeNotifier.new);