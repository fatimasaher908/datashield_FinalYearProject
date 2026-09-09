import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/io_client.dart';

import '../services/storage_service.dart';

class AuthService {
  static const String baseUrl = 'https://192.168.18.46:8383';

  // ============================================================
  // CREATE SECURE HTTPS CLIENT
  // ============================================================

  Future<IOClient> _createSecureClient() async {
    final securityContext = SecurityContext(withTrustedRoots: true);

    final rootCa = await rootBundle.load('assets/certs/rootca.pem');
    securityContext.setTrustedCertificatesBytes(rootCa.buffer.asUint8List());

    final httpClient = HttpClient(context: securityContext);
    return IOClient(httpClient);
  }

  // ============================================================
  // SIGNUP / REGISTER
  // ============================================================

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    IOClient? client;

    try {
      client = await _createSecureClient();
      final url = Uri.parse('$baseUrl/auth/register');

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': name,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final user = data['user'];

        if (user == null || user['id'] == null) {
          print('Register error: Server did not return user ID');
          return false;
        }

        final userId = user['id'].toString();

        await StorageService.saveUserId(userId);
        await StorageService.saveAccount(true);

        print('Registration successful. Logging in automatically...');

        return await login(email: email, password: password);
      }

      return false;
    } catch (e) {
      print('Register error: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    IOClient? client;

    try {
      client = await _createSecureClient();
      final url = Uri.parse('$baseUrl/auth/login/mobile');

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final user = data['user'];

        if (token == null || token.toString().isEmpty) {
          print('Login error: Server did not return JWT token');
          return false;
        }

        // SAVE JWT TOKEN (CRITICAL FOR KEY UNWRAPPING)
        await StorageService.saveJwtToken(token.toString());

        // SAVE USER ID
        if (user != null && user['id'] != null) {
          await StorageService.saveUserId(user['id'].toString());
        }

        await StorageService.saveLoggedIn(true);
        await StorageService.saveAccount(true);

        return true;
      }

      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  // ============================================================
  // STATUS & ACCOUNT HELPERS
  // ============================================================

  Future<bool> hasAccount() async {
    return await StorageService.hasAccount();
  }

  Future<bool> isLoggedIn() async {
    return await StorageService.isLoggedIn();
  }

  Future<String?> getUserId() async {
    return await StorageService.getUserId();
  }

  Future<void> logout() async {
    await StorageService.deleteJwtToken();
    await StorageService.logout();
  }
}