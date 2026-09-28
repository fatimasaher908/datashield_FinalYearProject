import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/decryption_service.dart';
import '../services/storage_service.dart';
import 'image_viewer_screen.dart';
import 'VideoViewerScreen.dart';

enum MediaType { image, video }

class GalleryMediaItem {
  final String encryptedUri;
  final Uint8List bytes;
  final MediaType type;
  final String fileName;

  // ============================================================
  // VIDEO THUMBNAIL
  // ============================================================

  Uint8List? thumbnailBytes;

  // ============================================================
  // RETAINED DECRYPTED VIDEO
  //
  // The video is decrypted once while generating its thumbnail.
  // This stores the path to that SAME decrypted MP4.
  //
  // VideoViewerScreen will use this path directly instead of
  // decrypting the encrypted video again.
  // ============================================================

  String? tempVideoPath;

  GalleryMediaItem({
    required this.encryptedUri,
    required this.bytes,
    required this.type,
    required this.fileName,
    this.thumbnailBytes,
    this.tempVideoPath,
  });
}

class GalleryScreen extends StatefulWidget {
  final String folderName;
  final String folderUri;
  final Uint8List dek;

  const GalleryScreen({
    super.key,
    required this.folderName,
    required this.folderUri,
    required this.dek,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<GalleryMediaItem> mediaItems = [];

  bool loading = true;
  bool selectionMode = false;

  final Set<int> selectedItems = {};

  static const Color background = Color(0xff160047);
  static const Color primary = Color(0xff6A00FF);
  static const Color cyan = Color(0xff00FFD5);
  static const Color cardColor = Color(0xff220060);

  @override
  void initState() {
    print('');
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    print('GALLERY SCREEN CREATED');
    print('FOLDER NAME: ${widget.folderName}');
    print('FOLDER URI: ${widget.folderUri}');
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

    super.initState();
    loadMedia();
  }

  // ============================================================
  // LOAD ENCRYPTED MEDIA
  // ============================================================

  Future<void> loadMedia() async {
    await _cleanupRetainedVideoFiles();

    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      print('');
      print('==============================================');
      print('        DATASHIELD GALLERY DEBUG');
      print('==============================================');

      // ========================================================
      // 1. GET SAVED PICTURES URI
      // ========================================================

      final picturesUri =
          await StorageService.getPicturesFolderUri();

      print('');
      print('PICTURES URI:');
      print(picturesUri ?? 'NULL');

      // ========================================================
      // 2. GET SAVED DCIM URI
      // ========================================================

      final dcimUri =
          await StorageService.getDcimFolderUri();

      print('');
      print('DCIM URI:');
      print(dcimUri ?? 'NULL');

      // ========================================================
      // 3. VALIDATE URIs
      // ========================================================

      if (picturesUri == null || picturesUri.isEmpty) {
        print('');
        print('!!! PICTURES URI IS MISSING !!!');
      }

      if (dcimUri == null || dcimUri.isEmpty) {
        print('');
        print('!!! DCIM URI IS MISSING !!!');
      }

      if ((picturesUri == null || picturesUri.isEmpty) &&
          (dcimUri == null || dcimUri.isEmpty)) {
        throw Exception(
          'No protected folders are available.',
        );
      }

      // ========================================================
      // 4. GET ENCRYPTED MEDIA FROM BOTH ROOTS
      // ========================================================

      print('');
      print('Calling native getEncryptedMedia()...');

      final encryptedFiles =
          await DecryptionService.getEncryptedMedia(
        picturesUri: picturesUri,
        dcimUri: dcimUri,
      );

      print('');
      print('==============================================');
      print(
        'TOTAL ENCRYPTED FILES FOUND: '
        '${encryptedFiles.length}',
      );
      print('==============================================');

      // ========================================================
      // 5. PRINT EVERY ENCRYPTED FILE
      // ========================================================

      for (int i = 0; i < encryptedFiles.length; i++) {
        print('');
        print('ENCRYPTED FILE [$i]');
        print(encryptedFiles[i]);
      }

      // ========================================================
      // 6. PROCESS EACH MEDIA FILE
      // ========================================================

      final List<GalleryMediaItem> loadedItems = [];

      final Set<String> processedUris = {};

      for (final rawItem in encryptedFiles) {
        print('');
        print('----------------------------------------------');
        print('PROCESSING MEDIA ITEM');
        print(rawItem);
        print('----------------------------------------------');

        // ======================================================
        // VALIDATE MEDIA MAP
        // ======================================================

        if (rawItem is! Map) {
          print('INVALID MEDIA ITEM: $rawItem');
          continue;
        }

        // ======================================================
        // GET ACTUAL URI
        // ======================================================

        final String? uri =
            rawItem['uri']?.toString();

        final String fileName =
            rawItem['name']?.toString() ??
            'encrypted_media.dsenc';

        final String nativeType =
            rawItem['type']?.toString() ??
            'image';

        if (uri == null || uri.isEmpty) {
          print('!!! MEDIA URI IS MISSING !!!');
          continue;
        }

        // ======================================================
        // DUPLICATE CHECK
        // ======================================================

        if (processedUris.contains(uri)) {
          print('');
          print('!!! DUPLICATE FILE SKIPPED !!!');
          print('URI: $uri');
          continue;
        }

        processedUris.add(uri);

        print('');
        print('ACTUAL URI:');
        print(uri);

        print('');
        print('FILE NAME:');
        print(fileName);

        print('');
        print('NATIVE TYPE:');
        print(nativeType);

        // ======================================================
        // DETERMINE MEDIA TYPE
        // ======================================================

        final mediaType =
            _getMediaType(
          fileName,
          nativeType,
        );

        print('');
        print('MEDIA TYPE: ${mediaType.name}');

        // ======================================================
        // VIDEOS
        //
        // IMPORTANT ACCOUNT ISOLATION CHECK:
        //
        // We MUST NOT add a video to the gallery just because
        // a .dsenc file exists.
        //
        // Instead, we try to decrypt it using widget.dek.
        //
        // If this video was encrypted by another account,
        // its AES-GCM authentication will fail and
        // generateVideoThumbnail() will return null.
        //
        // ONLY a video that successfully decrypts with the
        // CURRENT ACCOUNT'S DEK is added to the gallery.
        //
        // The successful decryption also gives us:
        //
        //   1. thumbnailBytes
        //   2. tempVideoPath
        //
        // Therefore the video is decrypted only ONCE.
        // ========================================================

        if (mediaType == MediaType.video) {
          print('');
          print('==============================================');
          print('VIDEO FOUND');
          print('FILE: $fileName');
          print('CHECKING CURRENT ACCOUNT OWNERSHIP');
          print('==============================================');

          print('');
          print(
            'Attempting video decryption using CURRENT '
            'ACCOUNT DEK...',
          );

          final result =
              await DecryptionService.generateVideoThumbnail(
            uri,
            fileName,
            widget.dek,
          );

          if (!mounted) {
            return;
          }

          // ====================================================
          // WRONG ACCOUNT / WRONG DEK
          //
          // AES-GCM authentication fails.
          //
          // Therefore this encrypted video does NOT belong
          // to the current account.
          // ====================================================

          if (result == null) {
            print('');
            print('==============================================');
            print('VIDEO REJECTED');
            print('FILE: $fileName');
            print('REASON: CURRENT ACCOUNT DEK CANNOT DECRYPT IT');
            print('THIS VIDEO BELONGS TO ANOTHER ACCOUNT');
            print('==============================================');

            continue;
          }

          // ====================================================
          // GET THUMBNAIL
          // ====================================================

          final thumbnail =
              result['thumbnailBytes'];

          // ====================================================
          // GET RETAINED DECRYPTED VIDEO
          // ====================================================

          final videoPath =
              result['videoPath'];

          // ====================================================
          // VALIDATE THUMBNAIL
          // ====================================================

          if (thumbnail is! Uint8List) {
            print('');
            print('!!! INVALID VIDEO THUMBNAIL DATA !!!');
            print('FILE: $fileName');

            if (videoPath != null &&
                videoPath.toString().isNotEmpty) {
              try {
                await DecryptionService.deleteTemporaryVideo(
                  videoPath.toString(),
                );
              } catch (e) {
                print(
                  'FAILED TO CLEAN INVALID VIDEO: $e',
                );
              }
            }

            continue;
          }

          // ====================================================
          // VALIDATE RETAINED VIDEO PATH
          // ====================================================

          if (videoPath == null ||
              videoPath.toString().isEmpty) {
            print('');
            print('!!! RETAINED VIDEO PATH IS MISSING !!!');
            print('FILE: $fileName');

            continue;
          }

          final String retainedVideoPath =
              videoPath.toString();

          // ====================================================
          // VIDEO PASSED ACCOUNT OWNERSHIP CHECK
          // ====================================================

          print('');
          print('==============================================');
          print('VIDEO ACCEPTED');
          print('FILE: $fileName');
          print('CURRENT ACCOUNT DEK DECRYPTED VIDEO');
          print('VIDEO BELONGS TO CURRENT ACCOUNT');
          print('==============================================');

          print('');
          print('THUMBNAIL SIZE: ${thumbnail.length} bytes');

          print('');
          print('RETAINED DECRYPTED VIDEO:');
          print(retainedVideoPath);

          // ====================================================
          // ADD VIDEO ONLY AFTER SUCCESSFUL DECRYPTION
          // ====================================================

          loadedItems.add(
            GalleryMediaItem(
              encryptedUri: uri,
              bytes: Uint8List(0),
              type: MediaType.video,
              fileName: fileName,
              thumbnailBytes: thumbnail,
              tempVideoPath: retainedVideoPath,
            ),
          );

          print('');
          print('VIDEO ADDED TO GALLERY.');
          print('----------------------------------------------');

          continue;
        }

        // ======================================================
        // DECRYPT IMAGE
        //
        // THIS IS YOUR ORIGINAL IMAGE LOGIC.
        //
        // DO NOT CHANGE IT.
        // ======================================================

        print('');
        print('Calling decryptImage()...');
        print('URI being sent to native code:');
        print(uri);

        final bytes =
            await DecryptionService.decryptImage(
          uri,
          widget.dek,
        );

        if (bytes == null) {
          print('');
          print('!!! DECRYPTION FAILED !!!');
          print('URI: $uri');
          print('NAME: $fileName');
          continue;
        }

        print('');
        print(
          'DECRYPTION SUCCESSFUL '
          '(${bytes.length} bytes)',
        );

        // ======================================================
        // ADD IMAGE TO GALLERY
        // ======================================================

        loadedItems.add(
          GalleryMediaItem(
            encryptedUri: uri,
            bytes: bytes,
            type: mediaType,
            fileName: fileName,
          ),
        );
      }

      // ========================================================
      // 7. SECOND SAFETY DEDUPLICATION
      // ========================================================

      final Map<String, GalleryMediaItem> uniqueItems = {};

      for (final item in loadedItems) {
        uniqueItems[item.encryptedUri] = item;
      }

      final List<GalleryMediaItem> finalItems =
          uniqueItems.values.toList();

      // ========================================================
      // 8. FINAL RESULT
      // ========================================================

      print('');
      print('==============================================');
      print(
        'MEDIA ITEMS LOADED: '
        '${loadedItems.length}',
      );
      print(
        'UNIQUE GALLERY ITEMS: '
        '${finalItems.length}',
      );
      print('==============================================');

      // ========================================================
      // 9. PRINT FINAL UI ITEMS
      // ========================================================

      print('');
      print('FINAL GALLERY ITEMS:');

      for (int i = 0; i < finalItems.length; i++) {
        print(
          'UI [$i]: '
          '${finalItems[i].fileName}',
        );

        print(
          'TYPE [$i]: '
          '${finalItems[i].type.name}',
        );

        print(
          'URI [$i]: '
          '${finalItems[i].encryptedUri}',
        );
      }

      // ========================================================
      // 10. UPDATE UI
      //
      // IMPORTANT:
      //
      // Video thumbnails are ALREADY generated above.
      // Therefore we do NOT call _generateVideoThumbnails().
      //
      // Every video in mediaItems has already passed the
      // current-account DEK check.
      // ========================================================

      if (!mounted) return;

      setState(() {
        mediaItems = finalItems;
        loading = false;
      });
    } catch (e, stackTrace) {
      print('');
      print('==============================================');
      print('GALLERY ERROR');
      print('==============================================');
      print(e);
      print(stackTrace);

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  // ============================================================
  // DETECT MEDIA TYPE
  // ============================================================

  MediaType _getMediaType(
    String fileName,
    String nativeType,
  ) {
    // Native code already detected the type.
    if (nativeType.toLowerCase() == 'video') {
      return MediaType.video;
    }

    if (nativeType.toLowerCase() == 'image') {
      return MediaType.image;
    }

    // ==========================================================
    // FALLBACK: DETERMINE FROM FILE EXTENSION
    // ==========================================================

    final String originalName =
        fileName.replaceFirst(
      RegExp(
        r'\.dsenc$',
        caseSensitive: false,
      ),
      '',
    );

    final String extension =
        originalName.contains('.')
            ? originalName
                .split('.')
                .last
                .toLowerCase()
            : '';

    const imageExtensions = {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
      'heic',
      'heif',
    };

    const videoExtensions = {
      'mp4',
      'mov',
      'avi',
      'mkv',
      'webm',
      '3gp',
      'm4v',
      '3g2',
      'ts',
    };

    if (videoExtensions.contains(extension)) {
      return MediaType.video;
    }

    if (imageExtensions.contains(extension)) {
      return MediaType.image;
    }

    // Default to image.
    return MediaType.image;
  }

  // ============================================================
  // TOGGLE SELECTION
  // ============================================================

  void toggleSelection(int index) {
    setState(() {
      if (selectedItems.contains(index)) {
        selectedItems.remove(index);
      } else {
        selectedItems.add(index);
      }

      if (selectedItems.isEmpty) {
        selectionMode = false;
      }
    });
  }

  // ============================================================
  // DELETE SELECTED MEDIA
  // ============================================================

  Future<void> _deleteSelectedMedia() async {
    if (selectedItems.isEmpty) return;

    final indexes =
        selectedItems.toList()
          ..sort(
            (a, b) => b.compareTo(a),
          );

    final filesToDelete = <String>[];
    final temporaryVideosToDelete = <String>[];

    for (final index in indexes) {
      if (index >= 0 &&
          index < mediaItems.length) {
        final item = mediaItems[index];

        // ======================================================
        // ENCRYPTED FILE
        // ======================================================

        filesToDelete.add(
          item.encryptedUri,
        );

        // ======================================================
        // RETAINED DECRYPTED VIDEO
        // ======================================================

        if (item.type == MediaType.video &&
            item.tempVideoPath != null &&
            item.tempVideoPath!.isNotEmpty) {
          temporaryVideosToDelete.add(
            item.tempVideoPath!,
          );
        }
      }
    }

    // ==========================================================
    // REMOVE FROM UI FIRST
    // ==========================================================

    setState(() {
      for (final index in indexes) {
        if (index >= 0 &&
            index < mediaItems.length) {
          mediaItems.removeAt(index);
        }
      }

      selectedItems.clear();
      selectionMode = false;
    });

    // ==========================================================
    // DELETE ACTUAL ENCRYPTED FILES
    // ==========================================================

    for (final encryptedUri in filesToDelete) {
      try {
        await DecryptionService.deleteEncryptedImage(
          encryptedUri,
        );

        print(
          'Deleted: $encryptedUri',
        );
      } catch (e) {
        print(
          'DELETE FAILED: $encryptedUri',
        );
        print(e);
      }
    }

    // ==========================================================
    // DELETE RETAINED DECRYPTED VIDEOS
    // ==========================================================

    for (final videoPath in temporaryVideosToDelete) {
      try {
        final deleted =
            await DecryptionService.deleteTemporaryVideo(
          videoPath,
        );

        if (deleted) {
          print(
            'Deleted retained decrypted video: '
            '$videoPath',
          );
        } else {
          print(
            'Retained decrypted video was already missing: '
            '$videoPath',
          );
        }
      } catch (e) {
        print(
          'TEMP VIDEO DELETE FAILED: '
          '$videoPath',
        );
        print(e);
      }
    }
  }

  // ============================================================
  // OPEN IMAGE VIEWER
  // ============================================================

  void _openImageViewer(int selectedIndex) {
    final imageItems =
        mediaItems
            .where(
              (item) =>
                  item.type == MediaType.image,
            )
            .toList();

    if (selectedIndex < 0 ||
        selectedIndex >= mediaItems.length) {
      return;
    }

    final selectedItem =
        mediaItems[selectedIndex];

    final imageIndex =
        imageItems.indexWhere(
      (item) =>
          item.encryptedUri ==
          selectedItem.encryptedUri,
    );

    if (imageIndex == -1) return;

    final images =
        imageItems
            .map(
              (item) => item.bytes,
            )
            .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ImageViewerScreen(
          images: images,
          initialIndex: imageIndex,
        ),
      ),
    );
  }

  // ============================================================
  // OPEN VIDEO VIEWER
  //
  // IMPORTANT:
  //
  // The video was already decrypted during loadMedia().
  // Therefore VideoViewerScreen receives the retained MP4.
  // ============================================================

  void _openVideoViewer(int index) {
    if (index < 0 ||
        index >= mediaItems.length) {
      return;
    }

    final item = mediaItems[index];

    if (item.type != MediaType.video) {
      return;
    }

    print('');
    print('==============================================');
    print('OPENING VIDEO');
    print('FILE: ${item.fileName}');
    print('==============================================');

    print(
      'RETAINED VIDEO PATH: '
      '${item.tempVideoPath ?? 'NULL'}',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VideoViewerScreen(
          encryptedUri: item.encryptedUri,
          fileName: item.fileName,
          encryptionKey: widget.dek,

          // --------------------------------------------------
          // USE THE ALREADY DECRYPTED MP4
          // --------------------------------------------------

          tempVideoPath: item.tempVideoPath,
        ),
      ),
    );
  }

  // ============================================================
  // CLEANUP RETAINED DECRYPTED VIDEOS
  // ============================================================

  Future<void> _cleanupRetainedVideoFiles() async {
    print('');
    print('==============================================');
    print('CLEANING UP RETAINED DECRYPTED VIDEOS');
    print('==============================================');

    final paths = <String>{};

    for (final item in mediaItems) {
      if (item.type != MediaType.video) {
        continue;
      }

      final path = item.tempVideoPath;

      if (path != null && path.isNotEmpty) {
        paths.add(path);
      }
    }

    if (paths.isEmpty) {
      print('No retained decrypted videos to clean.');
      return;
    }

    for (final path in paths) {
      try {
        final deleted =
            await DecryptionService.deleteTemporaryVideo(
          path,
        );

        if (deleted) {
          print('Deleted retained video:');
          print(path);
        } else {
          print('Retained video was already missing:');
          print(path);
        }
      } catch (e) {
        print('FAILED TO DELETE RETAINED VIDEO:');
        print(path);
        print(e);
      }
    }

    print('');
    print('==============================================');
    print('RETAINED VIDEO CLEANUP COMPLETE');
    print('FILES CLEANED: ${paths.length}');
    print('==============================================');
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    print('');
    print('==============================================');
    print('GALLERY SCREEN DISPOSING');
    print('CLEANING RETAINED DECRYPTED VIDEOS');
    print('==============================================');

    _cleanupRetainedVideoFiles();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: Text(
          widget.folderName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),

        actions: [
          // ====================================================
          // ENTER SELECTION MODE
          // ====================================================

          if (!selectionMode)
            IconButton(
              icon: const Icon(
                Icons.library_add_check,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  selectionMode = true;
                });
              },
            ),

          // ====================================================
          // DELETE SELECTED
          // ====================================================

          if (selectionMode &&
              selectedItems.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete,
                color: Colors.red,
              ),
              onPressed:
                  _deleteSelectedMedia,
            ),

          // ====================================================
          // EXIT SELECTION MODE
          // ====================================================

          if (selectionMode &&
              selectedItems.isEmpty)
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  selectionMode = false;
                  selectedItems.clear();
                });
              },
            ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: loading
          ? _loadingState()
          : mediaItems.isEmpty
              ? emptyState()
              : _mediaGrid(),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _loadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: cyan,
          ),

          SizedBox(height: 20),

          Text(
            'Loading protected media...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MEDIA GRID
  // ============================================================

  Widget _mediaGrid() {
    return RefreshIndicator(
      onRefresh: loadMedia,

      child: GridView.builder(
        padding: const EdgeInsets.all(16),

        itemCount: mediaItems.length,

        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),

        itemBuilder: (context, index) {
          final item =
              mediaItems[index];

          final isSelected =
              selectedItems.contains(index);

          return GestureDetector(
            onTap: () {
              if (selectionMode) {
                toggleSelection(index);
                return;
              }

              if (item.type ==
                  MediaType.image) {
                _openImageViewer(index);
              } else {
                _openVideoViewer(index);
              }
            },

            onLongPress: () {
              if (!selectionMode) {
                setState(() {
                  selectionMode = true;
                  selectedItems.add(index);
                });
              }
            },

            child: Container(
              decoration: BoxDecoration(
                color: cardColor,

                borderRadius:
                    BorderRadius.circular(12),

                border: Border.all(
                  color: isSelected
                      ? cyan
                      : cyan.withValues(
                          alpha: 0.3,
                        ),
                  width:
                      isSelected ? 2 : 1,
                ),

                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(
                      alpha: 0.2,
                    ),
                    blurRadius: 8,
                  ),
                ],
              ),

              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(11),

                child: Stack(
                  fit: StackFit.expand,

                  children: [
                    // ==================================================
                    // IMAGE
                    // ==================================================

                    if (item.type ==
                        MediaType.image)
                      Image.memory(
                        item.bytes,
                        fit: BoxFit.cover,

                        errorBuilder:
                            (
                          context,
                          error,
                          stackTrace,
                        ) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 32,
                            ),
                          );
                        },
                      ),

                    // ==================================================
                    // VIDEO THUMBNAIL
                    // ==================================================

                    if (item.type ==
                        MediaType.video)
                      _videoThumbnail(item),

                    // ==================================================
                    // SELECTION OVERLAY
                    // ==================================================

                    if (isSelected)
                      Container(
                        color: Colors.black
                            .withValues(
                          alpha: 0.35,
                        ),
                      ),

                    // ==================================================
                    // VIDEO BADGE
                    // ==================================================

                    if (item.type ==
                        MediaType.video)
                      Positioned(
                        bottom: 6,
                        left: 6,

                        child: Container(
                          padding:
                              const EdgeInsets.all(
                            5,
                          ),

                          decoration:
                              BoxDecoration(
                            color: Colors.black
                                .withValues(
                              alpha: 0.6,
                            ),
                            shape:
                                BoxShape.circle,
                          ),

                          child:
                              const Icon(
                            Icons.play_arrow,
                            color:
                                Colors.white,
                            size: 20,
                          ),
                        ),
                      ),

                    // ==================================================
                    // SELECTION CHECKMARK
                    // ==================================================

                    if (isSelected)
                      Positioned(
                        right: 6,
                        top: 6,

                        child: Container(
                          padding:
                              const EdgeInsets.all(
                            2,
                          ),

                          decoration:
                              const BoxDecoration(
                            shape:
                                BoxShape.circle,
                            color: cyan,
                          ),

                          child:
                              const Icon(
                            Icons.check,
                            color: background,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // VIDEO THUMBNAIL
  // ============================================================

  Widget _videoThumbnail(
    GalleryMediaItem item,
  ) {
    // ==========================================================
    // THUMBNAIL AVAILABLE
    // ==========================================================

    if (item.thumbnailBytes != null) {
      return Image.memory(
        item.thumbnailBytes!,
        fit: BoxFit.cover,

        errorBuilder:
            (
          context,
          error,
          stackTrace,
        ) {
          return _videoPlaceholder();
        },
      );
    }

    // ==========================================================
    // THUMBNAIL STILL BEING GENERATED
    //
    // Normally this should not happen now because videos are
    // processed before being added to mediaItems.
    // ==========================================================

    return Container(
      color: Colors.black26,

      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: cyan,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // VIDEO PLACEHOLDER
  // ============================================================

  Widget _videoPlaceholder() {
    return Container(
      color: Colors.black26,

      child: const Center(
        child: Icon(
          Icons.video_library,
          color: cyan,
          size: 45,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          Container(
            padding:
                const EdgeInsets.all(25),

            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(
                alpha: 0.25,
              ),
            ),

            child: const Icon(
              Icons.image_not_supported,
              color: cyan,
              size: 70,
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            'No protected media',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Encrypted images and videos will appear here',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
