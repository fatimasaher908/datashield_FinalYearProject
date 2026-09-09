import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/io_client.dart';

import 'storage_service.dart';

class UserService {
  static const String baseUrl = 'https://192.168.18.46:8383';

  Future<IOClient> _createSecureClient() async {
    final securityContext = SecurityContext(withTrustedRoots: true);

    final rootCa = await rootBundle.load('assets/certs/rootca.pem');
    securityContext.setTrustedCertificatesBytes(rootCa.buffer.asUint8List());

    final httpClient = HttpClient(context: securityContext);
    return IOClient(httpClient);
  }

  /// Fetch user profile details
  Future<Map<String, dynamic>?> getUserProfile() async {
    IOClient? client;

    try {
      final userId = await StorageService.getUserId();
      final token = await StorageService.getJwtToken();

      if (userId == null || token == null) {
        print("Missing user ID or auth token");
        return null;
      }

      client = await _createSecureClient();
      final url = Uri.parse('$baseUrl/user/$userId');

      final response = await client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print("Error fetching profile: $e");
      return null;
    } finally {
      client?.close();
    }
  }
}