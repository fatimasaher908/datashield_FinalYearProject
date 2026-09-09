import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class EncryptionService {
  static const MethodChannel _channel =
      MethodChannel('datashield/encryption');

  static Future<void> encryptFolder(String uri, Uint8List key) async {
    try {
      await _channel.invokeMethod(
        'encryptFolder',
        {
          "uri": uri,
          "key": key, // Passes unwrapped DEK to Kotlin MainActivity
        },
      );
    } on PlatformException catch (e) {
      log(
        "Encryption error: ${e.message}",
      );
      rethrow;
    }
  }
}