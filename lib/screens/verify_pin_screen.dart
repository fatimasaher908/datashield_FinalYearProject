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
  // ADD DIGIT
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

  // ============================================================
  // DELETE DIGIT
  // ============================================================

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
  // PIN CIRCLE
  // ============================================================

  Widget _buildPinCircle(int index) {
    final filled = index < _pinController.text.length;

    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? Colors.white
            : Colors.transparent,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
      ),
    );
  }

  // ============================================================
  // NUMBER BUTTON
  // ============================================================

  Widget _numberButton(String number) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _isLoading
          ? null
          : () => _addDigit(number),
      child: Container(
        width: 82,
        height: 62,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // KEYPAD ROW
  // ============================================================

  Widget _keypadRow(
    String first,
    String second,
    String third,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 15,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _numberButton(first),
          _numberButton(second),
          _numberButton(third),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 18,
          ),
          child: Column(
            children: [
              const SizedBox(height: 15),

              // ==================================================
              // HEADER
              // ==================================================

              Row(
                children: [
                  Image.asset(
                    "assets/images/logo.JPG",
                    width: 42,
                    height: 42,
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        "DATASHIELD",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Secure Mobile Data & Management System",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 35),

              // ==================================================
              // TITLE
              // ==================================================

              const Text(
                "Verify PIN",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Enter your 4-digit security PIN",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // PIN CIRCLES
              // ==================================================

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => _buildPinCircle(index),
                ),
              ),

              const SizedBox(height: 40),

              // ==================================================
              // KEYPAD
              // ==================================================

              _keypadRow("1", "2", "3"),
              _keypadRow("4", "5", "6"),
              _keypadRow("7", "8", "9"),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(
                    width: 82,
                    height: 62,
                  ),
                  _numberButton("0"),
                  const SizedBox(
                    width: 82,
                    height: 62,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ==================================================
              // DELETE BUTTON
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed:
                      _isLoading ? null : _removeDigit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    disabledBackgroundColor:
                        Colors.redAccent.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(
                    Icons.backspace_outlined,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "Delete",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // ==================================================
              // LOADING
              // ==================================================

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),

              // ==================================================
              // FOOTER
              // ==================================================

              const Text(
                "Enter your PIN to activate DataShield protection.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
