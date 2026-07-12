import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/storage_service.dart';
import '../services/encryption_service.dart';
import '../services/native_service.dart';
import '../utils/app_colors.dart';

import 'dashboard_screen.dart';

class FolderSelectionScreen extends StatefulWidget {
  const FolderSelectionScreen({super.key});

  @override
  State<FolderSelectionScreen> createState() => _FolderSelectionScreenState();
}

class _FolderSelectionScreenState extends State<FolderSelectionScreen> {
  final List<Map<String, String>> selectedFolders = [];

  Future<void> saveProtectedFolders() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> folders = selectedFolders.map((folder) {
      return "${folder['name']}|${folder['uri']}";
    }).toList();

    await prefs.setStringList("protectedFolders", folders);

    debugPrint("Protected folders saved: $folders");
  }

  Future<void> _pickFolder() async {
    final String? folderUri = await StorageService.pickFolder();

    if (folderUri != null) {
      String folderName = folderUri;

      if (folderUri.contains('%3A')) {
        folderName = folderUri.split('%3A').last;

        folderName = folderName.replaceAll('%2F', '/');
      }

      bool exists = selectedFolders.any((folder) => folder['uri'] == folderUri);

      if (!exists) {
        setState(() {
          selectedFolders.add({"name": folderName, "uri": folderUri});
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Folder already selected")),
        );
      }
    }
  }

  Future<void> openDashboard() async {
    if (selectedFolders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one folder")),
      );

      return;
    }

    await saveProtectedFolders();

    List<String> folders = selectedFolders
        .map((folder) => folder["uri"]!)
        .toList();

    try {
      await NativeService.startService(folders);

      debugPrint("Foreground service started");
    } catch (e) {
      debugPrint("Service error: $e");
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (var folder in selectedFolders) {
        await EncryptionService.encryptFolder(folder['uri']!);
      }

      if (mounted) {
        Navigator.pop(context);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(protectedFolders: selectedFolders),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Encryption failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 75,

        titleSpacing: 0,

        title: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset("assets/images/logo.JPG", width: 42, height: 42),

              const SizedBox(width: 10),

              const Column(
                mainAxisSize: MainAxisSize.min,
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
            ],
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(25),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              "Protected Folders",

              style: TextStyle(
                color: Colors.white,

                fontSize: 26,

                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Select folders you want to protect",

              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),

            const SizedBox(height: 25),

            Expanded(
              child: selectedFolders.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      itemCount: selectedFolders.length,

                      itemBuilder: (context, index) {
                        final folder = selectedFolders[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),

                          padding: const EdgeInsets.all(16),

                          decoration: BoxDecoration(
                            color: AppColors.card,

                            borderRadius: BorderRadius.circular(18),

                            border: Border.all(
                              color: AppColors.cyan.withOpacity(.4),
                            ),
                          ),

                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),

                                decoration: BoxDecoration(
                                  color: AppColors.lightPurple,

                                  borderRadius: BorderRadius.circular(14),
                                ),

                                child: const Icon(
                                  Icons.folder,
                                  color: Colors.white,
                                ),
                              ),

                              const SizedBox(width: 15),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      folder["name"]!,

                                      style: const TextStyle(
                                        color: Colors.white,

                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(height: 5),

                                    const Text(
                                      "Ready for protection",

                                      style: TextStyle(color: Colors.white60),
                                    ),
                                  ],
                                ),
                              ),

                              const Icon(
                                Icons.lock_outline,
                                color: AppColors.cyan,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 15),

            _gradientButton("Select Folder", Icons.folder_open, _pickFolder),

            const SizedBox(height: 15),

            _gradientButton("Continue", Icons.arrow_forward, openDashboard),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          const Icon(Icons.folder_off, size: 75, color: AppColors.cyan),

          const SizedBox(height: 20),

          const Text(
            "No folders selected",

            style: TextStyle(
              color: Colors.white,

              fontSize: 22,

              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientButton(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.symmetric(vertical: 16),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),

          gradient: AppColors.buttonGradient,
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(icon, color: Colors.white),

            const SizedBox(width: 10),

            Text(
              text,

              style: const TextStyle(
                color: Colors.white,

                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
