import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'services/photo_retrieval_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start Flutter HTTP server
  final server = FlutterHttpServer();
  await server.start();

  // Start Flutter application
  runApp(const DataShieldApp());
}

class DataShieldApp extends StatelessWidget {
  const DataShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    
    );
  }
}
class FlutterHttpServer {
  HttpServer? _server;

  Future<void> start() async {
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      8080,
    );

    print('FLUTTER SERVER: Running on port 8080');

    _handleRequests();
  }

  Future<void> _handleRequests() async {
    await for (final request in _server!) {
      try {
        // GET /files
        if (request.method == 'GET' &&
            request.uri.path == '/files') {
          await _sendFileList(request);
          continue;
        }

        // GET /files/0
        if (request.method == 'GET' &&
            request.uri.path.startsWith('/files/')) {
          final idString =
              request.uri.pathSegments.last;

          final id = int.tryParse(idString);

          if (id == null) {
            request.response.statusCode = 400;
            await request.response.close();
            continue;
          }

          await _sendFile(request, id);
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();

      } catch (e) {
        print('FLUTTER SERVER ERROR: $e');

        request.response.statusCode =
            HttpStatus.internalServerError;

        await request.response.close();
      }
    }
  }

  Future<void> _sendFileList(
    HttpRequest request,
  ) async {
    final files =
        await PhotoRetrievalService.getEncryptedPhotos();

    final response = files.asMap().entries.map((entry) {
      final index = entry.key;
      final file = entry.value;

      return {
        'id': index,
        'name': file.name,
        'size': file.size,
      };
    }).toList();

    request.response.headers.contentType =
        ContentType.json;

    request.response.write(
      jsonEncode(response),
    );

    await request.response.close();
  }
Future<void> _sendFile(
  HttpRequest request,
  int id,
) async {
  final files =
      await PhotoRetrievalService.getEncryptedPhotos();

  if (id < 0 || id >= files.length) {
    request.response.statusCode =
        HttpStatus.notFound;

    await request.response.close();
    return;
  }

  final file = files[id];

  print('========================================');
  print('FLUTTER SERVER: Preparing encrypted file');
  print('FLUTTER SERVER: ID = $id');
  print('FLUTTER SERVER: Name = ${file.name}');

  final bytes =
      await PhotoRetrievalService.getEncryptedBytes(
    file.uri,
  );

  if (bytes == null || bytes.isEmpty) {
    print('FLUTTER SERVER: ERROR - No bytes received');

    request.response.statusCode =
        HttpStatus.internalServerError;

    await request.response.close();
    return;
  }

  // ============================================================
  // DEBUG: CHECK THE ACTUAL ENCRYPTED BYTES
  // ============================================================

  print('FLUTTER SERVER: Sending encrypted file');
  print('FLUTTER SERVER: Size = ${bytes.length} bytes');

  final previewLength =
      bytes.length < 32 ? bytes.length : 32;

  final first32Bytes = bytes
      .sublist(0, previewLength)
      .map(
        (b) => b.toRadixString(16).padLeft(2, '0'),
      )
      .join(' ');

  print(
    'FLUTTER SERVER: First 32 bytes = $first32Bytes',
  );

  // ============================================================
  // SEND ENCRYPTED BYTES
  // ============================================================

  request.response.headers.contentType =
      ContentType('application', 'octet-stream');

  request.response.headers.contentLength =
      bytes.length;

  request.response.headers.add(
    'Content-Disposition',
    'attachment; filename="${file.name}"',
  );

  request.response.add(bytes);

  await request.response.close();

  print(
    'FLUTTER SERVER: Sent '
    '${file.name} (${bytes.length} bytes)',
  );

  print('========================================');
}
}