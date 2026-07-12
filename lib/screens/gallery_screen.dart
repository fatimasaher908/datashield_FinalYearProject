import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/decryption_service.dart';
import 'image_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  final String folderName;
  final String folderUri;

  const GalleryScreen({
    super.key,
    required this.folderName,
    required this.folderUri,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<String> encryptedImages = [];

  List<Uint8List> decryptedImages = [];

  bool loading = true;

  bool selectionMode = false;

  Set<int> selectedImages = {};

  static const Color background = Color(0xff160047);

  static const Color primary = Color(0xff6A00FF);

  static const Color cyan = Color(0xff00FFD5);

  // static const Color pink = Color(0xffD900FF);

  static const Color cardColor = Color(0xff220060);

  @override
  void initState() {
    super.initState();
    loadImages();
  }

  Future<void> loadImages() async {
    final images = await DecryptionService.getEncryptedImages(widget.folderUri);

    List<Uint8List> tempImages = [];

    for (String image in images) {
      final bytes = await DecryptionService.decryptImage(image);

      if (bytes != null) {
        tempImages.add(bytes);
      }
    }

    if (mounted) {
      setState(() {
        encryptedImages = List<String>.from(images);

        decryptedImages = tempImages;

        loading = false;
      });
    }
  }

  void toggleSelection(int index) {
    setState(() {
      if (selectedImages.contains(index)) {
        selectedImages.remove(index);
      } else {
        selectedImages.add(index);
      }

      if (selectedImages.isEmpty) {
        selectionMode = false;
      }
    });
  }

  Future<void> _deleteSelectedImages() async {
    List<int> indexes = selectedImages.toList();

    indexes.sort((a, b) => b.compareTo(a));

    List<String> filesToDelete = [];

    for (int index in indexes) {
      if (index < encryptedImages.length) {
        filesToDelete.add(encryptedImages[index]);
      }
    }

    // Update UI immediately
    setState(() {
      for (int index in indexes) {
        encryptedImages.removeAt(index);

        decryptedImages.removeAt(index);
      }

      selectedImages.clear();

      selectionMode = false;
    });

    // Delete actual files
    for (String file in filesToDelete) {
      await DecryptionService.deleteEncryptedImage(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: Colors.transparent,

        elevation: 0,

        centerTitle: true,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),

          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          // Select multiple images button
          if (!selectionMode)
            IconButton(
              icon: const Icon(Icons.library_add_check, color: Colors.white),

              onPressed: () {
                setState(() {
                  selectionMode = true;
                });
              },
            ),

          // Delete button appears after selecting images
          if (selectionMode && selectedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),

              onPressed: () {
                _deleteSelectedImages();
              },
            ),

          // Exit selection mode without deleting
          if (selectionMode && selectedImages.isEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),

              onPressed: () {
                setState(() {
                  selectionMode = false;

                  selectedImages.clear();
                });
              },
            ),
        ],

        title: Text(
          widget.folderName,

          style: const TextStyle(
            color: Colors.white,

            fontWeight: FontWeight.bold,

            fontSize: 22,
          ),
        ),
      ),

      body: loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: const [
                  CircularProgressIndicator(color: cyan),

                  SizedBox(height: 20),

                  Text(
                    "Decrypting images...",

                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            )
          : decryptedImages.isEmpty
          ? emptyState()
          : GridView.builder(
              padding: const EdgeInsets.all(20),

              itemCount: decryptedImages.length,

              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,

                crossAxisSpacing: 12,

                mainAxisSpacing: 12,
              ),

              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (selectionMode) {
                          toggleSelection(index);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ImageViewerScreen(
                                images: decryptedImages,
                                initialIndex: index,
                              ),
                            ),
                          );
                        }
                      },

                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cyan.withOpacity(.3)),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(.2),
                              blurRadius: 10,
                            ),
                          ],
                        ),

                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            decryptedImages[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    if (selectedImages.contains(index))
                      Positioned(
                        right: 8,
                        top: 8,

                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                          ),

                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Container(
            padding: const EdgeInsets.all(25),

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              color: primary.withOpacity(.25),
            ),

            child: const Icon(Icons.image_not_supported, color: cyan, size: 70),
          ),

          const SizedBox(height: 25),

          const Text(
            "No decrypted images",

            style: TextStyle(
              color: Colors.white,

              fontSize: 22,

              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            "Encrypted images will appear here",

            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
