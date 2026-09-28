import 'dart:convert';
import 'package:http/http.dart' as http;

import 'storage_service.dart';

class MediaApiService {
  static const String baseUrl = 'https://192.168.137.1:8383';

  // ============================================================
  // REGISTER ENCRYPTED FILE
  // ============================================================

  static Future<Map<String, dynamic>> registerFile({
    required String originalName,
    required String encryptedName,
    required String mimeType,
    required int fileSize,
    required String fileHash,
  }) async {
    print('==============================================');
    print('MEDIA REGISTER: START');
    print('==============================================');

    final token = await StorageService.getJwtToken();
    await StorageService.debugJwtContents();

    print('MEDIA REGISTER: JWT = ${token != null ? "FOUND" : "NULL"}');

    if (token == null) {
      throw Exception('JWT token not found');
    }

    final url = '$baseUrl/media/register';

    print('MEDIA REGISTER: URL = $url');
    print('MEDIA REGISTER: originalName = $originalName');
    print('MEDIA REGISTER: encryptedName = $encryptedName');
    print('MEDIA REGISTER: mimeType = $mimeType');
    print('MEDIA REGISTER: fileSize = $fileSize');
    print('MEDIA REGISTER: fileHash = $fileHash');

    final requestBody = {
      'original_name': originalName,
      'encrypted_name': encryptedName,
      'mime_type': mimeType,
      'file_size': fileSize,
      'file_hash': fileHash,
    };

    print('MEDIA REGISTER: BODY = ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('MEDIA REGISTER: STATUS = ${response.statusCode}');
      print('MEDIA REGISTER: RESPONSE = ${response.body}');

      if (response.statusCode != 201) {
        throw Exception(
          'Failed to register file: '
          '${response.statusCode} '
          '${response.body}',
        );
      }

      print('MEDIA REGISTER: SUCCESS');
      print('==============================================');

      return jsonDecode(response.body);
    } catch (e) {
      print('MEDIA REGISTER: ERROR = $e');
      print('==============================================');
      rethrow;
    }
  }

  // ============================================================
  // GET CURRENT USER FILES
  // ============================================================

  static Future<List<Map<String, dynamic>>> getMyFiles() async {
    final token = await StorageService.getJwtToken();

    if (token == null) {
      throw Exception('JWT token not found');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/media/fetch'),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('MEDIA FETCH: STATUS = ${response.statusCode}');

    print('MEDIA FETCH: RESPONSE = ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get user files: '
        '${response.statusCode} '
        '${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    return List<Map<String, dynamic>>.from(data['files']);
  }
}
