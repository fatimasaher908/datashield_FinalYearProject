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
    print('HTTPS: Creating secure client...');

    final securityContext = SecurityContext(withTrustedRoots: true);

    final rootCa = await rootBundle.load('assets/certs/rootca.pem');

    print('HTTPS: rootCA.pem loaded successfully.');

    securityContext.setTrustedCertificatesBytes(
      rootCa.buffer.asUint8List(),
    );

    print('HTTPS: Custom root CA added.');

    final httpClient = HttpClient(context: securityContext);

    print('HTTPS: HttpClient created.');

    return IOClient(httpClient);
  }

  // ============================================================
  // MAIN UNWRAP FUNCTION
  // ============================================================

  static Future<Uint8List?> getUnwrappedKey({
    required String pin,
  }) async {
    IOClient? client;

    try {
      print('KEY: Starting key retrieval...');

      final userId = await StorageService.getUserId();
      final token = await StorageService.getJwtToken();

      if (userId == null ||
          userId.isEmpty ||
          token == null ||
          token.isEmpty) {
        print('KEY: Missing credentials in storage.');
        return null;
      }

      print('KEY: User ID found.');
      print('KEY: JWT token found.');

      client = await _createSecureClient();

      final url = Uri.parse('$baseUrl/key/$userId');

      print('KEY: About to send GET request.');
      print('KEY: URL = $url');

      final response = await client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('KEY: Response received!');
      print('KEY: Status code = ${response.statusCode}');
      print('KEY: Response body = ${response.body}');

      if (response.statusCode != 200) {
        print(
          'KEY: Server returned status ${response.statusCode}: '
          '${response.body}',
        );
        return null;
      }

      final data = jsonDecode(response.body);

      final encryptedKeyBase64 = data['encrypted_key'];
      final kekSaltBase64 = data['kek_salt'];

      if (encryptedKeyBase64 == null || kekSaltBase64 == null) {
        print('KEY: Server payload missing encrypted_key or kek_salt.');
        return null;
      }

      print('KEY: Encrypted key received.');
      print('KEY: KEK salt received.');

      final encryptedKey = base64Decode(encryptedKeyBase64);
      final salt = base64Decode(kekSaltBase64);

      // ========================================================
      // DERIVE KEY ENCRYPTION KEY
      // ========================================================

      print('KEY: Deriving KEK using PBKDF2-SHA256...');

      final kek = _deriveKEK(
        pin,
        Uint8List.fromList(salt),
      );

      print('KEY: KEK derived successfully.');

      // ========================================================
      // UNWRAP DATA ENCRYPTION KEY
      // ========================================================

      print('KEY: Unwrapping DEK using RFC3394...');

      final dek = _unwrapRFC3394(
        Uint8List.fromList(encryptedKey),
        kek,
      );

      print('KEY: DEK successfully unwrapped.');
      print('KEY: DEK length = ${dek.length} bytes.');

      return dek;
    } catch (e, stackTrace) {
      print('KEY: Key retrieval/unwrap failed.');
      print('KEY: Error = $e');
      print('KEY: Stack trace = $stackTrace');

      return null;
    } finally {
      client?.close();
      print('KEY: HTTP client closed.');
    }
  }

  // ============================================================
  // KEK DERIVATION (PBKDF2-HMAC-SHA256)
  // ============================================================

  static Uint8List _deriveKEK(
    String pin,
    Uint8List salt,
  ) {
    final derivator = PBKDF2KeyDerivator(
      HMac(SHA256Digest(), 64),
    )..init(
        Pbkdf2Parameters(
          salt,
          100000,
          32,
        ),
      );

    return derivator.process(
      Uint8List.fromList(
        utf8.encode(pin),
      ),
    );
  }

  // ============================================================
  // RFC 3394 AES KEY UNWRAP
  // ============================================================

  static Uint8List _unwrapRFC3394(
    Uint8List wrappedKey,
    Uint8List kek,
  ) {
    if (wrappedKey.length < 24 ||
        wrappedKey.length % 8 != 0) {
      throw Exception('Invalid wrapped key length.');
    }

    if (kek.length != 16 &&
        kek.length != 24 &&
        kek.length != 32) {
      throw Exception('Invalid KEK length.');
    }

    final cipher = AESFastEngine()
      ..init(
        false,
        KeyParameter(kek),
      );

    final n = (wrappedKey.length ~/ 8) - 1;

    Uint8List a = Uint8List.fromList(
      wrappedKey.sublist(0, 8),
    );

    final r = List<Uint8List>.generate(
      n,
      (i) => Uint8List.fromList(
        wrappedKey.sublist(
          8 + (i * 8),
          16 + (i * 8),
        ),
      ),
    );

    final block = Uint8List(16);

    for (int j = 5; j >= 0; j--) {
      for (int i = n; i >= 1; i--) {
        final t = n * j + i;

        block.setRange(
          0,
          8,
          a,
        );

        for (int k = 7; k >= 0; k--) {
          block[k] ^= (t >> ((7 - k) * 8)) & 0xff;
        }

        block.setRange(
          8,
          16,
          r[i - 1],
        );

        cipher.processBlock(
          block,
          0,
          block,
          0,
        );

        a = Uint8List.fromList(
          block.sublist(0, 8),
        );

        r[i - 1] = Uint8List.fromList(
          block.sublist(8, 16),
        );
      }
    }

    // ============================================================
    // VERIFY DEFAULT INTEGRITY VECTOR
    // ============================================================

    const expectedIV = [
      0xA6,
      0xA6,
      0xA6,
      0xA6,
      0xA6,
      0xA6,
      0xA6,
      0xA6,
    ];

    for (int i = 0; i < 8; i++) {
      if (a[i] != expectedIV[i]) {
        throw Exception(
          'Integrity check failed. '
          'Wrong PIN or key corrupted.',
        );
      }
    }

    final dek = Uint8List(n * 8);

    for (int i = 0; i < n; i++) {
      dek.setRange(
        i * 8,
        (i + 1) * 8,
        r[i],
      );
    }

    return dek;
  }
}