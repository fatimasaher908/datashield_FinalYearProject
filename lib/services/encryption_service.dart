import 'dart:developer';
import 'package:flutter/services.dart';


class EncryptionService {

  static const MethodChannel _channel =
      MethodChannel('datashield/encryption');


  static Future<void> encryptFolder(String uri) async {

    try {

      await _channel.invokeMethod(
        'encryptFolder',
        {
          "uri": uri,
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