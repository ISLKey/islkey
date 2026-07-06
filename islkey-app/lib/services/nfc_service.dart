import 'package:nfc_manager/nfc_manager.dart';

class NfcService {
  /// Returns true if the device supports NFC.
  static Future<bool> isAvailable() async {
    return NfcManager.instance.isAvailable();
  }

  /// Format raw bytes to an uppercase hex UID with NO separators, matching the
  /// form the backend expects (e.g. [0x58, 0xE1, 0x04, 0xDD] → "58E104DD").
  static String formatUid(List<int> bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
  }

  /// Normalise an arbitrary UID string to uppercase hex, no colons/spaces.
  static String normalise(String uid) =>
      uid.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();

  /// Start an NFC scan session. Calls [onRead] with the formatted UID when a tag
  /// is detected, [onError] on failure. Reads the first tag per session only.
  static Future<void> startSession({
    required void Function(String uid) onRead,
    required void Function(String error) onError,
  }) async {
    // Guard against the reader firing onDiscovered multiple times for the same
    // tap (it polls continuously while a tag is held near the phone). Only the
    // first successful read per session is processed.
    var handled = false;
    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        if (handled) return;
        handled = true;
        try {
          // Pull the identifier from whatever tag technology is available.
          // NfcA/B/F/V and Ndef all carry an identifier.
          List<int>? identifier;

          final ndef = Ndef.from(tag);
          if (ndef != null) {
            identifier = tag.data['nfca']?['identifier'] as List<int>? ??
                tag.data['nfcb']?['identifier'] as List<int>? ??
                tag.data['nfcf']?['identifier'] as List<int>? ??
                tag.data['nfcv']?['identifier'] as List<int>? ??
                tag.data['ndef']?['identifier'] as List<int>?;
          }

          identifier ??= tag.data['nfca']?['identifier'] as List<int>? ??
              tag.data['nfcb']?['identifier'] as List<int>? ??
              tag.data['nfcf']?['identifier'] as List<int>? ??
              tag.data['nfcv']?['identifier'] as List<int>?;

          // iOS ISO7816 (MIFARE DESFire, etc)
          identifier ??= tag.data['iso7816']?['identifier'] as List<int>?;

          if (identifier == null || identifier.isEmpty) {
            onError('Could not read tag identifier.');
            return;
          }

          final uid = formatUid(identifier);
          NfcManager.instance.stopSession();
          onRead(uid);
        } catch (e) {
          NfcManager.instance.stopSession(errorMessage: 'Read failed.');
          onError('Tag read failed. Please try again.');
        }
      },
    );
  }

  static void stopSession() {
    NfcManager.instance.stopSession();
  }
}
