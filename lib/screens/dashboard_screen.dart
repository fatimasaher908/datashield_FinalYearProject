import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import 'folder_selection_screen.dart';
import 'decrypted_content_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatelessWidget {
  final List<Map<String, String>> protectedFolders;

  const DashboardScreen({super.key, required this.protectedFolders});

  static const Color background = Color(0xff160047);
  static const Color primary = Color(0xff6A00FF);
  static const Color cyan = Color(0xff00FFD5);
  static const Color pink = Color(0xffD900FF);
  static const Color cardColor = Color(0xff220060);

  Future<void> logout(BuildContext context) async {
    await StorageService.logout();

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),

          child: Column(
            children: [
              // SAME HEADER AS LOGIN SCREEN
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
                    onPressed: () {
                      logout(context);
                    },

                    icon: const Icon(Icons.logout, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ORIGINAL STATS CARD (UNCHANGED)
                    Container(
                      width: double.infinity,

                      padding: const EdgeInsets.all(24),

                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),

                        gradient: const LinearGradient(colors: [primary, pink]),
                      ),

                      child: Column(
                        children: [
                          const Icon(
                            Icons.security,

                            color: Colors.white,

                            size: 50,
                          ),

                          const SizedBox(height: 15),

                          Text(
                            "${protectedFolders.length}",

                            style: const TextStyle(
                              color: Colors.white,

                              fontSize: 40,

                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 5),

                          const Text(
                            "Protected Folders",

                            style: TextStyle(
                              color: Colors.white70,

                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 35),

                    _actionCard(
                      context,

                      title: "Select Folder",

                      subtitle: "Protect another folder",

                      icon: Icons.folder_open,

                      onTap: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => const FolderSelectionScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    _actionCard(
                      context,

                      title: "Decrypted Content",

                      subtitle: "View encrypted folders securely",

                      icon: Icons.lock_open,

                      onTap: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => DecryptedContentScreen(
                              protectedFolders: protectedFolders,
                            ),
                          ),
                        );
                      },
                    ),

                    const Spacer(),

                    Center(
                      child: Text(
                        "DataShield protects your privacy.",

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
