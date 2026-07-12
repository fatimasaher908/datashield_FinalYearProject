import 'dart:typed_data';
import 'package:flutter/services.dart';

class DecryptionService {

  static const MethodChannel _channel =
      MethodChannel("datashield/encryption");

  static Future<List<dynamic>> getEncryptedImages(
      String folderUri) async {

    final List<dynamic> images =
        await _channel.invokeMethod(
      "getEncryptedImages",
      {
        "uri": folderUri,
      },
    );

    return images;
  }

 static Future<Uint8List?> decryptImage(
    String imageUri,
) async {

  final result =
      await _channel.invokeMethod(
    "decryptImage",
    {
      "uri": imageUri,
    },
  );


  if(result == null){
    print("Decryption returned NULL");
    return null;
  }


  final bytes = Uint8List.fromList(
    List<int>.from(result),
  );


  print(
    "Flutter received bytes: ${bytes.length}"
  );


  print(
    "First 10 bytes: ${bytes.take(10).toList()}"
  );


  return bytes;
}

  static Future<void> deleteEncryptedImage(
      String imageUri,
  ) async {

    await _channel.invokeMethod(
      "deleteEncryptedImage",
      {
        "uri": imageUri,
      },
    );

  }

}