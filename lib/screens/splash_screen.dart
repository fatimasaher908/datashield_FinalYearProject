import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/storage_service.dart';
import '../utils/app_colors.dart';
import 'login_screen.dart';
import 'enter_pin_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkUser();
  }

  Future<void> checkUser() async {
    await Future.delayed(const Duration(seconds: 8));

    bool hasAccount = await StorageService.hasAccount();
    bool loggedIn = await StorageService.isLoggedIn();

    if (!mounted) return;

    if (!hasAccount) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else if (loggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EnterPinScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  "assets/images/logo.JPG",
                  width: 170,
                  height: 170,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 30),

                // App Name
                Text(
                  "DATASHIELD",
                  style: GoogleFonts.orbitron(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 4,
                    shadows: const [
                      Shadow(color: Color(0xFF48C6EF), blurRadius: 10),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  "Secure Mobile Data & Management System",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock, color: Colors.greenAccent, size: 18),
                    SizedBox(width: 6),
                    Text(
                      "End-to-End Encryption",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}