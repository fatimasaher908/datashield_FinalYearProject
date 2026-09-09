import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/key_services.dart';
import '../services/native_service.dart';
import '../services/storage_service.dart';
import '../utils/app_colors.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class EnterPinScreen extends StatefulWidget {
  const EnterPinScreen({super.key});

  @override
  State<EnterPinScreen> createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends State<EnterPinScreen> {
  String enteredPin = "";
  bool isLoading = false;

  // ============================================================
  // ADD DIGIT
  // ============================================================

  void addDigit(String digit) {
    if (enteredPin.length >= 4 || isLoading) {
      return;
    }

    setState(() {
      enteredPin += digit;
    });

    if (enteredPin.length == 4) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          verifyPin();
        }
      });
    }
  }

  // ============================================================
  // DELETE DIGIT
  // ============================================================

  void deleteDigit() {
    if (enteredPin.isNotEmpty && !isLoading) {
      setState(() {
        enteredPin =
            enteredPin.substring(0, enteredPin.length - 1);
      });
    }
  }

  // ============================================================
  // VERIFY PIN & START DATASHIELD
  // ============================================================

  Future<void> verifyPin() async {
    if (enteredPin.length != 4 || isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // ========================================================
      // 1. UNWRAP DEK USING PIN
      // ========================================================

      debugPrint("========================================");
      debugPrint("ENTER PIN: STARTING KEY UNWRAP");
      debugPrint("========================================");

      final Uint8List? dek =
          await KeyService.getUnwrappedKey(
        pin: enteredPin,
      );

      if (dek == null) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
          enteredPin = "";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Incorrect PIN or key unwrapping failed.",
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );

        return;
      }

      debugPrint(
        "DEK unwrapped successfully: ${dek.length} bytes",
      );

      // AES-256 requires exactly 32 bytes.
      if (dek.length != 32) {
        throw Exception(
          "Invalid encryption key. Expected 32 bytes, "
          "received ${dek.length} bytes.",
        );
      }

      // ========================================================
      // 2. GET PICTURES + DCIM FOLDER URIs
      // ========================================================

      debugPrint("Loading protected media folders...");

      String? picturesUri =
          await StorageService.getPicturesFolderUri();

      String? dcimUri =
          await StorageService.getDcimFolderUri();

      debugPrint("Pictures URI: $picturesUri");
      debugPrint("DCIM URI: $dcimUri");

      // ========================================================
      // 3. FALLBACK TO PROTECTED FOLDERS
      // ========================================================
      //
      // This keeps compatibility with older saved data where
      // the folders were stored using saveProtectedFolders().
      //

      if (picturesUri == null || picturesUri.isEmpty) {
        final folders =
            await StorageService.loadProtectedFolders();

        for (final folder in folders) {
          final name = folder['name'];
          final uri = folder['uri'];

          if (name == 'Pictures' &&
              uri != null &&
              uri.isNotEmpty) {
            picturesUri = uri;
            break;
          }
        }
      }

      if (dcimUri == null || dcimUri.isEmpty) {
        final folders =
            await StorageService.loadProtectedFolders();

        for (final folder in folders) {
          final name = folder['name'];
          final uri = folder['uri'];

          if (name == 'DCIM' &&
              uri != null &&
              uri.isNotEmpty) {
            dcimUri = uri;
            break;
          }
        }
      }

      // ========================================================
      // 4. VALIDATE BOTH FOLDERS
      // ========================================================

      if (picturesUri == null ||
          picturesUri.isEmpty) {
        throw Exception(
          "Pictures folder URI not found. "
          "Please grant Pictures folder access.",
        );
      }

      if (dcimUri == null || dcimUri.isEmpty) {
        throw Exception(
          "DCIM folder URI not found. "
          "Please grant DCIM folder access.",
        );
      }

      debugPrint(
        "Pictures folder found successfully.",
      );

      debugPrint(
        "DCIM folder found successfully.",
      );

      // ========================================================
      // 5. START BACKGROUND DATASHIELD SERVICE
      // ========================================================

      debugPrint(
        "Starting DataShield foreground service...",
      );

      await NativeService.startService(
        picturesUri,
        dcimUri,
        dek,
      );

      debugPrint(
        "DataShield foreground service started successfully.",
      );

      // ========================================================
      // 6. SAVE LOGIN STATE
      // ========================================================

      await StorageService.saveLoggedIn(true);

      // ========================================================
      // 7. NAVIGATE TO DASHBOARD
      // ========================================================

      if (!mounted) return;

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
        "========================================",
      );
      debugPrint(
        "ENTER PIN ERROR",
      );
      debugPrint(
        "$e",
      );
      debugPrint(
        "$stackTrace",
      );
      debugPrint(
        "========================================",
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
        enteredPin = "";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Unable to unlock DataShield: $e",
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ============================================================
  // PIN CIRCLE
  // ============================================================

  Widget pinCircle(int index) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: index < enteredPin.length
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

  Widget numberButton(String number) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isLoading
          ? null
          : () => addDigit(number),
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
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // KEYPAD ROW
  // ============================================================

  Widget keypadRow(
    String first,
    String second,
    String third,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceEvenly,
        children: [
          numberButton(first),
          numberButton(second),
          numberButton(third),
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
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const LoginScreen(),
                                ),
                              );
                            },
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Image.asset(
                    "assets/images/logo.JPG",
                    width: 42,
                    height: 42,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "DATASHIELD",
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          "Secure Mobile Data And Management System",
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 35),

              // ==================================================
              // TITLE
              // ==================================================

              const Text(
                "Enter PIN",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Enter your 4-digit security PIN to unwrap key",
                textAlign: TextAlign.center,
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
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => pinCircle(index),
                ),
              ),

              const SizedBox(height: 40),

              // ==================================================
              // KEYPAD
              // ==================================================

              keypadRow("1", "2", "3"),
              keypadRow("4", "5", "6"),
              keypadRow("7", "8", "9"),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(
                    width: 82,
                    height: 62,
                  ),
                  numberButton("0"),
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
                      isLoading ? null : deleteDigit,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.redAccent,
                    shape:
                        RoundedRectangleBorder(
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
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // ==================================================
              // STATUS
              // ==================================================

              if (isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Unwrapping encryption key...",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  "Your PIN will derive the KEK to unwrap your data key.",
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