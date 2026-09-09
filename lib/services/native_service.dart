
import 'dart:typed_data';

import 'package:flutter/services.dart';

class NativeService {
  static const MethodChannel _channel =
      MethodChannel('datashield/service');

  // ============================================================
  // START DATASHIELD PROTECTION
  // ============================================================

  /// Starts background protection for:
  ///
  /// 1. Pictures/
  /// 2. DCIM/ (including DCIM/Camera/)
  ///
  static Future<void> startService(
    String picturesFolderUri,
    String dcimFolderUri,
    Uint8List key,
  ) async {
    if (picturesFolderUri.isEmpty) {
      throw Exception(
        'Pictures folder URI is missing.',
      );
    }

    if (dcimFolderUri.isEmpty) {
      throw Exception(
        'DCIM folder URI is missing.',
      );
    }

    if (key.isEmpty) {
      throw Exception(
        'Encryption key is empty.',
      );
    }

    await _channel.invokeMethod(
      'startService',
      {
        'picturesUri': picturesFolderUri,
        'dcimUri': dcimFolderUri,
        'key': key,
      },
    );
  }

  // ============================================================
  // STOP PROTECTION
  // ============================================================

  static Future<void> stopService() async {
    await _channel.invokeMethod(
      'stopService',
    );
  }
}

