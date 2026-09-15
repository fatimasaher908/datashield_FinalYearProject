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
    print('AUTH HTTPS: Creating secure client...');

    final securityContext = SecurityContext(withTrustedRoots: true);

    final rootCa = await rootBundle.load('assets/certs/rootca.pem');

    print('AUTH HTTPS: rootCA.pem loaded successfully.');

    securityContext.setTrustedCertificatesBytes(
      rootCa.buffer.asUint8List(),
    );

    print('AUTH HTTPS: Custom root CA added.');

    final httpClient = HttpClient(context: securityContext);

    print('AUTH HTTPS: HttpClient created.');

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
      print('REGISTER: Starting registration...');

      client = await _createSecureClient();

      final url = Uri.parse('$baseUrl/auth/register');

      print('REGISTER: About to send POST request.');
      print('REGISTER: URL = $url');

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': name,
          'email': email,
          'password': password,
        }),
      );

      print('REGISTER: Response received!');
      print('REGISTER: Status code = ${response.statusCode}');
      print('REGISTER: Response body = ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final user = data['user'];

        if (user == null || user['id'] == null) {
          print('REGISTER: Server did not return user ID.');
          return false;
        }

        final userId = user['id'].toString();

        await StorageService.saveUserId(userId);
        await StorageService.saveAccount(true);

        print('REGISTER: Registration successful.');
        print('REGISTER: Logging in automatically...');

        return await login(
          email: email,
          password: password,
        );
      }

      print(
        'REGISTER: Registration failed with status '
        '${response.statusCode}.',
      );

      return false;
    } catch (e, stackTrace) {
      print('REGISTER: Error = $e');
      print('REGISTER: Stack trace = $stackTrace');

      return false;
    } finally {
      client?.close();
      print('REGISTER: HTTP client closed.');
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
      print('LOGIN: Starting login request...');

      client = await _createSecureClient();

      print('LOGIN: Secure client created.');

      final url = Uri.parse('$baseUrl/auth/login/mobile');

      print('LOGIN: About to send POST request.');
      print('LOGIN: URL = $url');
      print('LOGIN: Email = $email');

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('LOGIN: Response received!');
      print('LOGIN: Status code = ${response.statusCode}');
      print('LOGIN: Response body = ${response.body}');

      if (response.statusCode == 200) {
        print('LOGIN: Server returned 200.');

        final data = jsonDecode(response.body);

        final token = data['token'];
        final user = data['user'];

        if (token == null || token.toString().isEmpty) {
          print('LOGIN: Server did not return JWT token.');
          return false;
        }

        print('LOGIN: JWT token received.');

        // SAVE JWT TOKEN
        await StorageService.saveJwtToken(
          token.toString(),
        );

        print('LOGIN: JWT token saved.');

        // SAVE USER ID
        if (user != null && user['id'] != null) {
          await StorageService.saveUserId(
            user['id'].toString(),
          );

          print(
            'LOGIN: User ID saved = ${user['id']}',
          );
        } else {
          print('LOGIN: No user ID returned by server.');
        }

        await StorageService.saveLoggedIn(true);
        await StorageService.saveAccount(true);

        print('LOGIN: Login completed successfully.');

        return true;
      }

      print(
        'LOGIN: Server returned status ${response.statusCode}.',
      );

      return false;
    } catch (e, stackTrace) {
      print('LOGIN: ERROR = $e');
      print('LOGIN: STACK TRACE = $stackTrace');

      return false;
    } finally {
      client?.close();
      print('LOGIN: HTTP client closed.');
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