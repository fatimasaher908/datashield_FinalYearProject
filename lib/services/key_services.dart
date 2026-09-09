import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/io_client.dart';
import 'package:pointycastle/export.dart';

import 'storage_service.dart';

class KeyService {
  static const String baseUrl = 'https://192.168.18.46:8383';

  // ============================================================
  // CREATE SECURE HTTPS CLIENT
  // ============================================================

  static Future<IOClient> _createSecureClient() async {
    final securityContext = SecurityContext(withTrustedRoots: true);
    final rootCa = await rootBundle.load('assets/certs/rootca.pem');
    securityContext.setTrustedCertificatesBytes(rootCa.buffer.asUint8List());

    final httpClient = HttpClient(context: securityContext);
    return IOClient(httpClient);
  }

  // ============================================================
  // MAIN UNWRAP FUNCTION
  // ============================================================

  static Future<Uint8List?> getUnwrappedKey({required String pin}) async {
    IOClient? client;

    try {
      final userId = await StorageService.getUserId();
      final token = await StorageService.getJwtToken();

      if (userId == null || userId.isEmpty || token == null || token.isEmpty) {
        print('Key retrieval failed: Missing credentials in storage.');
        return null;
      }

      client = await _createSecureClient();
      final url = Uri.parse('$baseUrl/key/$userId');

      final response = await client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        print('Server returned status ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      final encryptedKeyBase64 = data['encrypted_key'];
      final kekSaltBase64 = data['kek_salt'];

      if (encryptedKeyBase64 == null || kekSaltBase64 == null) {
        print('Server payload missing encrypted_key or kek_salt.');
        return null;
      }

      final encryptedKey = base64Decode(encryptedKeyBase64);
      final salt = base64Decode(kekSaltBase64);

      // Derive Key Encryption Key (KEK) using PBKDF2-SHA256
      final kek = _deriveKEK(pin, Uint8List.fromList(salt));

      // Unwrap to obtain Data Encryption Key (DEK)
      final dek = _unwrapRFC3394(Uint8List.fromList(encryptedKey), kek);

      return dek;
    } catch (e) {
      print('Key unwrap failed (incorrect PIN or corrupted payload): $e');
      return null;
    } finally {
      client?.close();
    }
  }

  // ============================================================
  // KEK DERIVATION (PBKDF2-HMAC-SHA256)
  // ============================================================

  static Uint8List _deriveKEK(String pin, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 100000, 32));

    return derivator.process(Uint8List.fromList(utf8.encode(pin)));
  }

  // ============================================================
  // RFC 3394 AES KEY UNWRAP
  // ============================================================

  static Uint8List _unwrapRFC3394(Uint8List wrappedKey, Uint8List kek) {
    if (wrappedKey.length < 24 || wrappedKey.length % 8 != 0) {
      throw Exception('Invalid wrapped key length.');
    }
    if (kek.length != 16 && kek.length != 24 && kek.length != 32) {
      throw Exception('Invalid KEK length.');
    }

    final cipher = AESFastEngine()..init(false, KeyParameter(kek));
    final n = (wrappedKey.length ~/ 8) - 1;

    Uint8List a = Uint8List.fromList(wrappedKey.sublist(0, 8));
    final r = List<Uint8List>.generate(
      n,
      (i) => Uint8List.fromList(wrappedKey.sublist(8 + (i * 8), 16 + (i * 8))),
    );

    final block = Uint8List(16);

    for (int j = 5; j >= 0; j--) {
      for (int i = n; i >= 1; i--) {
        final t = n * j + i;

        block.setRange(0, 8, a);
        for (int k = 7; k >= 0; k--) {
          block[k] ^= (t >> ((7 - k) * 8)) & 0xff;
        }

        block.setRange(8, 16, r[i - 1]);
        cipher.processBlock(block, 0, block, 0);

        a = Uint8List.fromList(block.sublist(0, 8));
        r[i - 1] = Uint8List.fromList(block.sublist(8, 16));
      }
    }

    // Verify Default Integrity Vector (A6 A6 A6 A6 A6 A6 A6 A6)
    const expectedIV = [0xA6, 0xA6, 0xA6, 0xA6, 0xA6, 0xA6, 0xA6, 0xA6];
    for (int i = 0; i < 8; i++) {
      if (a[i] != expectedIV[i]) {
        throw Exception('Integrity check failed. Wrong PIN or key corrupted.');
      }
    }

    final dek = Uint8List(n * 8);
    for (int i = 0; i < n; i++) {
      dek.setRange(i * 8, (i + 1) * 8, r[i]);
    }

    return dek;
  }
}