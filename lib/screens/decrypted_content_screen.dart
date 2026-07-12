import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import 'gallery_screen.dart';

class DecryptedContentScreen extends StatelessWidget {
  final List<Map<String, String>> protectedFolders;

  const DecryptedContentScreen({super.key, required this.protectedFolders});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),

          child: Column(
            children: [
              // HEADER SAME AS LOGIN + DASHBOARD
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },

                    icon: const Icon(
                      Icons.arrow_back_ios_new,

                      color: Colors.white,
                    ),
                  ),

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
                ],
              ),

              const SizedBox(height: 45),

              // TITLE
              const Align(
                alignment: Alignment.centerLeft,

                child: Text(
                  "Decrypted Content",

                  style: TextStyle(
                    color: Colors.white,

                    fontSize: 28,

                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Align(
                alignment: Alignment.centerLeft,

                child: Text(
                  "Select a folder to view decrypted files",

                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),

              const SizedBox(height: 30),

              Expanded(
                child: protectedFolders.isEmpty
                    ? const Center(
                        child: Text(
                          "No decrypted content available",

                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        itemCount: protectedFolders.length,

                        itemBuilder: (context, index) {
                          final folder = protectedFolders[index];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,

                                MaterialPageRoute(
                                  builder: (_) => GalleryScreen(
                                    folderName: folder["name"] ?? "Folder",

                                    folderUri: folder["uri"] ?? "",
                                  ),
                                ),
                              );
                            },

                            child: Container(
                              margin: const EdgeInsets.only(bottom: 15),

                              padding: const EdgeInsets.all(18),

                              decoration: BoxDecoration(
                                color: AppColors.card,

                                borderRadius: BorderRadius.circular(20),

                                border: Border.all(
                                  color: AppColors.cyan.withOpacity(.35),
                                ),
                              ),

                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),

                                    decoration: BoxDecoration(
                                      gradient: AppColors.buttonGradient,

                                      borderRadius: BorderRadius.circular(14),
                                    ),

                                    child: const Icon(
                                      Icons.folder,

                                      color: Colors.white,
                                    ),
                                  ),

                                  const SizedBox(width: 18),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        Text(
                                          folder["name"] ?? "Folder",

                                          style: const TextStyle(
                                            color: Colors.white,

                                            fontSize: 18,

                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(height: 5),

                                        const Text(
                                          "Tap to view decrypted files",

                                          style: TextStyle(
                                            color: Colors.white60,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Icon(
                                    Icons.arrow_forward_ios,

                                    color: AppColors.cyan,

                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
