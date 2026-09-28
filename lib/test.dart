import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'services/key_services.dart';

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  // ============================================================
  // BYTES → UPPERCASE HEX WITH SPACES
  // ============================================================

  String bytesToHex(Uint8List bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  // ============================================================
  // SHA-256
  // ============================================================

  String sha256Hex(Uint8List bytes) {
    final digest = sha256.convert(bytes);

    return digest.toString().toUpperCase();
  }

  // ============================================================
  // TEST DEK
  // ============================================================

  Future<void> testDEK() async {
    debugPrint('');
    debugPrint('============================================================');
    debugPrint('DEK DEBUG: FLUTTER DEK VERIFICATION');
    debugPrint('============================================================');

    const pin = '1234';

    debugPrint('DEK DEBUG: Calling KeyService.getUnwrappedKey()...');

    try {
      final dek = await KeyService.getUnwrappedKey(pin: pin);

      // ========================================================
      // NULL CHECK
      // ========================================================

      if (dek == null) {
        debugPrint('DEK DEBUG: DEK is NULL');
        debugPrint('DEK DEBUG: Failed to retrieve/unwrapped DEK');

        debugPrint(
          '============================================================',
        );

        return;
      }

      // ========================================================
      // CONVERT TO Uint8List
      // ========================================================

      final rawDek = Uint8List.fromList(dek);

      // ========================================================
      // DEK LENGTH
      // ========================================================

      debugPrint('DEK DEBUG: Raw DEK length = ${rawDek.length} bytes');

      // ========================================================
      // RAW DEK
      // ========================================================

      debugPrint('DEK DEBUG: Raw DEK = ${bytesToHex(rawDek)}');

      // ========================================================
      // SHA-256
      // ========================================================

      final dekHash = sha256Hex(rawDek);

      debugPrint('DEK DEBUG: RAW DEK SHA-256 = $dekHash');

      // ========================================================
      // BASE64
      // ========================================================

      debugPrint('DEK DEBUG: Raw DEK Base64 = ${base64Encode(rawDek)}');

      // ========================================================
      // AES-256 VALIDATION
      // ========================================================

      if (rawDek.length == 32) {
        debugPrint('DEK DEBUG: DEK LENGTH CHECK = PASS');
        debugPrint('DEK DEBUG: AES-256 DEK confirmed');
      } else {
        debugPrint('DEK DEBUG: DEK LENGTH CHECK = FAILED');
        debugPrint(
          'DEK DEBUG: Expected 32 bytes, '
          'received ${rawDek.length} bytes',
        );
      }

      // ========================================================
      // FINAL
      // ========================================================

      debugPrint(
        '============================================================',
      );
      debugPrint('DEK DEBUG: VERIFICATION COMPLETE');
      debugPrint(
        '============================================================',
      );
    } catch (e, stackTrace) {
      debugPrint('DEK DEBUG: ERROR = $e');
      debugPrint('DEK DEBUG: STACK TRACE = $stackTrace');

      debugPrint(
        '============================================================',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: testDEK, child: const Text('Test DEK'));
  }
}
