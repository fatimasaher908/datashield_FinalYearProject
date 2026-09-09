import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/io_client.dart';

import '../services/key_services.dart';
import '../services/storage_service.dart';
import '../utils/app_colors.dart';
import '../services/native_service.dart';
import 'dashboard_screen.dart';

class VerifyPinScreen extends StatefulWidget {
  final String pin;

  const VerifyPinScreen({
    super.key,
    required this.pin,
  });

  @override
  State<VerifyPinScreen> createState() => _VerifyPinScreenState();
}

class _VerifyPinScreenState extends State<VerifyPinScreen> {
  final TextEditingController _pinController = TextEditingController();

  bool _isLoading = false;

  final String baseUrl = 'https://192.168.18.46:8383';

  // ============================================================
  // CREATE SECURE HTTP CLIENT
  // ============================================================

  Future<IOClient> _createSecureClient() async {
    final context = SecurityContext(withTrustedRoots: true);

    final rootCA = await rootBundle.load(
      'assets/certs/rootca.pem',
    );

    context.setTrustedCertificatesBytes(
      rootCA.buffer.asUint8List(),
    );

    final httpClient = HttpClient(context: context);

    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return false;
    };

    return IOClient(httpClient);
  }

  // ============================================================
  // VERIFY PIN
  // ============================================================

  Future<void> _verifyPin() async {
    final enteredPin = _pinController.text.trim();

    if (enteredPin.length != 4) {
      _showError('Please enter your 4-digit PIN.');
      return;
    }

    if (enteredPin != widget.pin) {
      _showError('PIN does not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await _createKey(enteredPin);
  }

  // ============================================================
  // CREATE KEY + REQUEST MEDIA FOLDERS + START SERVICE
  // ============================================================

  Future<void> _createKey(String enteredPin) async {
    IOClient? client;

    try {
      final userId = await StorageService.getUserId();
      final token = await StorageService.getJwtToken();

      if (userId == null || userId.isEmpty) {
        throw Exception('User ID is missing.');
      }

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is missing.');
      }

      // ----------------------------------------------------------
      // STEP 1: CREATE KEY ON SERVER
      // ----------------------------------------------------------

      client = await _createSecureClient();

      final response = await client.post(
        Uri.parse('$baseUrl/key/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'pin': enteredPin,
        }),
      );

      debugPrint(
        'Key create response: ${response.statusCode}',
      );

      debugPrint(
        'Key create body: ${response.body}',
      );

      if (response.statusCode != 200 &&
          response.statusCode != 201) {
        throw Exception(
          'Failed to create encryption key. '
          'Server returned ${response.statusCode}.',
        );
      }

      // ----------------------------------------------------------
      // STEP 2: GET UNWRAPPED AES KEY
      // ----------------------------------------------------------

      final Uint8List? dek = await KeyService.getUnwrappedKey(
  pin: enteredPin,
);

if (dek == null || dek.isEmpty) {
  throw Exception(
    'Encryption key could not be obtained.',
  );
}

      if (dek.isEmpty) {
        throw Exception(
          'Encryption key could not be obtained.',
        );
      }

      debugPrint(
        'Encryption key obtained successfully.',
      );

      // ----------------------------------------------------------
      // STEP 3: REQUEST PICTURES + DCIM ACCESS
      // ----------------------------------------------------------

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Select your Pictures and Camera folders to protect them.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      final mediaFolders =
          await StorageService.requestMediaFolders();

      if (mediaFolders == null) {
        throw Exception(
          'Storage access was not granted.',
        );
      }

      final picturesUri =
          mediaFolders['picturesUri'] ?? '';

      final dcimUri =
          mediaFolders['dcimUri'] ?? '';

      if (picturesUri.isEmpty) {
        throw Exception(
          'Pictures folder access was not granted.',
        );
      }

      if (dcimUri.isEmpty) {
        throw Exception(
          'Camera/DCIM folder access was not granted.',
        );
      }

      debugPrint(
        'Pictures URI: $picturesUri',
      );

      debugPrint(
        'DCIM URI: $dcimUri',
      );

      // ----------------------------------------------------------
      // STEP 4: START BACKGROUND ENCRYPTION SERVICE
      // ----------------------------------------------------------

      await NativeService.startService(
        picturesUri,
        dcimUri,
        dek,
      );

      debugPrint(
        'DataShield background service started.',
      );

      // ----------------------------------------------------------
      // STEP 5: SAVE LOGIN STATE
      // ----------------------------------------------------------

      await StorageService.saveLoggedIn(true);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PIN verified. Pictures and Camera protection are now active.',
          ),
          duration: Duration(seconds: 3),
        ),
      );

      // ----------------------------------------------------------
      // STEP 6: GO TO DASHBOARD
      // ----------------------------------------------------------

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            dek: dek,
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Verify PIN error: $e',
      );

      debugPrint(
        'Stack trace: $stackTrace',
      );

      _showError(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      client?.close();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );

    _pinController.clear();
  }

  // ============================================================
  // PIN INPUT
  // ============================================================

  void _addDigit(String digit) {
    if (_isLoading) return;

    if (_pinController.text.length >= 4) {
      return;
    }

    setState(() {
      _pinController.text += digit;
    });

    if (_pinController.text.length == 4) {
      _verifyPin();
    }
  }

  void _removeDigit() {
    if (_isLoading) return;

    if (_pinController.text.isEmpty) {
      return;
    }

    setState(() {
      _pinController.text = _pinController.text.substring(
        0,
        _pinController.text.length - 1,
      );
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Verify PIN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
          ),
          child: Column(
            children: [
              const SizedBox(height: 35),

              const Icon(
                Icons.lock_outline,
                size: 65,
                color: AppColors.lightPurple,
              ),

              const SizedBox(height: 25),

              const Text(
                'Enter your PIN',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Verify your PIN to activate DataShield protection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 35),

              // --------------------------------------------------
              // PIN DOTS
              // --------------------------------------------------

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) {
                    final filled =
                        index < _pinController.text.length;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 9,
                      ),
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? AppColors.lightPurple
                            : Colors.grey.shade300,
                      ),
                    );
                  },
                ),
              ),

              const Spacer(),

              // --------------------------------------------------
              // KEYPAD
              // --------------------------------------------------

              _buildKeypad(),

              const SizedBox(height: 25),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 25),
                  child: CircularProgressIndicator(),
                ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // KEYPAD
  // ============================================================

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _key('1'),
            _key('2'),
            _key('3'),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _key('4'),
            _key('5'),
            _key('6'),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _key('7'),
            _key('8'),
            _key('9'),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(
              width: 70,
              height: 70,
            ),
            _key('0'),
            _key(
              '⌫',
              onTap: _removeDigit,
            ),
          ],
        ),
      ],
    );
  }

  Widget _key(
    String value, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: _isLoading
          ? null
          : () {
              if (onTap != null) {
                onTap();
              } else {
                _addDigit(value);
              }
            },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}