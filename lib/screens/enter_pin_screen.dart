import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import 'dashboard_screen.dart';
import '../services/storage_service.dart';
import '../services/native_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnterPinScreen extends StatefulWidget {
  const EnterPinScreen({super.key});

  @override
  State<EnterPinScreen> createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends State<EnterPinScreen> {
  String enteredPin = "";

  void addDigit(String digit) {
    if (enteredPin.length < 6) {
      setState(() {
        enteredPin += digit;
      });

      if (enteredPin.length == 6) {
        Future.delayed(const Duration(milliseconds: 250), () {
          verifyPin();
        });
      }
    }
  }

  void deleteDigit() {
    if (enteredPin.isNotEmpty) {
      setState(() {
        enteredPin = enteredPin.substring(0, enteredPin.length - 1);
      });
    }
  }

  Future<void> verifyPin() async {
    // Firebase PIN verification will be added here
    bool pinMatched = true; // Temporary placeholder

    if (pinMatched) {
      final folders = await StorageService.loadProtectedFolders();

      // Read saved folder URIs
      final prefs = await SharedPreferences.getInstance();
      final savedFolders = prefs.getStringList("protectedFolders") ?? [];

      if (savedFolders.isNotEmpty) {
        final folderUris = savedFolders
            .map((folder) => folder.split("|")[1])
            .toList();

        try {
          await NativeService.startService(folderUris);
          debugPrint("Foreground service started after PIN verification");
        } catch (e) {
          debugPrint("Failed to start service: $e");
        }
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(protectedFolders: folders),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Incorrect PIN"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      setState(() {
        enteredPin = "";
      });
    }
  }

  Widget pinCircle(int index) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: index < enteredPin.length ? Colors.white : Colors.transparent,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }

  Widget numberButton(String number) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => addDigit(number),
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

  Widget keypadRow(String first, String second, String third) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          numberButton(first),
          numberButton(second),
          numberButton(third),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Column(
            children: [
              const SizedBox(height: 15),

              Row(
                children: [
                  Image.asset("assets/images/logo.JPG", width: 42, height: 42),

                  const SizedBox(width: 10),

                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "DATASHIELD",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),

                      Text(
                        "Secure Mobile Data And Management System",
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 35),

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
                "Enter your 6-digit security PIN",
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) => pinCircle(index)),
              ),

              const SizedBox(height: 40),

              keypadRow("1", "2", "3"),
              keypadRow("4", "5", "6"),
              keypadRow("7", "8", "9"),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 82, height: 62),

                  numberButton("0"),

                  const SizedBox(width: 82, height: 62),
                ],
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: deleteDigit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

              const Text(
                "Your PIN will be verified securely before access is granted.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),

              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
