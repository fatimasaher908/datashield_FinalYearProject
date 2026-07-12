import 'package:flutter/services.dart';

class NativeService {
  static const MethodChannel _channel =
      MethodChannel('datashield/service');

  static Future<void> startService(
    List<String> folders,
  ) async {
    await _channel.invokeMethod(
      "startService",
      {
        "folders": folders,
      },
    );
  }

  static Future<void> stopService() async {
    await _channel.invokeMethod(
      "stopService",
    );
  }
}