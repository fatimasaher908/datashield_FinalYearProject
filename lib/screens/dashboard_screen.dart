import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../services/native_service.dart';
import 'decrypted_content_screen.dart';
import 'login_screen.dart';
import 'gallery_screen.dart';

class DashboardScreen extends StatelessWidget {
  final Uint8List dek;

  const DashboardScreen({super.key, required this.dek});

  static const Color background = Color(0xff160047);
  static const Color primary = Color(0xff6A00FF);
  static const Color cyan = Color(0xff00FFD5);
  static const Color pink = Color(0xffD900FF);
  static const Color cardColor = Color(0xff220060);

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout(BuildContext context) async {
    try {
      // Stop background monitoring and clear native session key
      await NativeService.stopService();
    } catch (e) {
      debugPrint("Error stopping DataShield service: $e");
    }

    await StorageService.logout();

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              // ==================================================
              // HEADER
              // ==================================================
              Row(
                children: [
                  Image.asset(
                    "assets/images/logo.JPG",
                    width: 42,
                    height: 42,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(width: 10),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () => logout(context),
                    icon: const Icon(Icons.logout, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ============================================
                    // PICTURES PROTECTION STATUS CARD
                    // ============================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(colors: [primary, pink]),
                      ),

                      child: const Column(
                        children: [
                          Icon(Icons.security, color: Colors.white, size: 50),

                          SizedBox(height: 15),

                          Text(
                            "Pictures Folder",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 8),

                          Text(
                            "Automatically protected",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 35),

                    // ============================================
                    // DECRYPTED CONTENT
                    // ============================================
                    _actionCard(
                      context,
                      title: "Protected Content",
                      subtitle:
                          "View your encrypted photos and videos securely",
                      icon: Icons.lock_open,
                      onTap: () async {
                        final folders =
                            await StorageService.loadProtectedFolders();

                        if (!context.mounted) return;

                        String? picturesFolderUri;

                        for (final folder in folders) {
                          if (folder['name'] == 'Pictures') {
                            picturesFolderUri = folder['uri'];
                            break;
                          }
                        }

                        if (picturesFolderUri == null ||
                            picturesFolderUri.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Pictures folder could not be found.',
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GalleryScreen(
                              folderName: "Pictures",
                              folderUri: picturesFolderUri!,
                              dek: dek,
                            ),
                          ),
                        );
                      },
                    ),

                    const Spacer(),

                    Center(
                      child: Text(
                        "DataShield automatically protects your Pictures folder.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(.55)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ACTION CARD
  // ============================================================

  Widget _actionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cyan.withOpacity(.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(subtitle, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            const Icon(Icons.arrow_forward_ios, color: cyan, size: 18),
          ],
        ),
      ),
    );
  }
}
