import 'package:flutter/material.dart';
import 'services/photo_retrieval_service.dart';

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  Future<void> testEncryptedMedia() async {
    debugPrint('========== STARTING TEST ==========');

    final files =
        await PhotoRetrievalService.getEncryptedPhotos();

    debugPrint('Total encrypted files: ${files.length}');

    for (final file in files) {
      debugPrint(
        '${file.name} | ${file.size} | ${file.uri}',
      );
    }

    debugPrint('========== TEST FINISHED ==========');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DataShield Test'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: testEncryptedMedia,
          child: const Text('Find Encrypted Files'),
        ),
      ),
    );
  }
}