import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // ============================================================
  // METHOD CHANNELS
  // ============================================================

  static const MethodChannel _storageChannel =
      MethodChannel('datashield/storage');

  static const MethodChannel _serviceChannel =
      MethodChannel('datashield/service');

  // ============================================================
  // SECURE STORAGE
  // ============================================================

  static const FlutterSecureStorage _secureStorage =
      FlutterSecureStorage();

  // ============================================================
  // STORAGE KEYS
  // ============================================================

  static const String jwtTokenKey = 'jwt_token';
  static const String userIdKey = 'user_id';
  static const String hasAccountKey = 'hasAccount';
  static const String loggedInKey = 'loggedIn';
  static const String protectedFoldersKey = 'protectedFolders';

  // ============================================================
  // USER ID
  // ============================================================

  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      userIdKey,
      userId,
    );
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(userIdKey);
  }

  // ============================================================
  // JWT TOKEN
  // ============================================================

  static Future<void> saveJwtToken(String token) async {
    await _secureStorage.write(
      key: jwtTokenKey,
      value: token,
    );
  }

  static Future<String?> getJwtToken() async {
    return await _secureStorage.read(
      key: jwtTokenKey,
    );
  }

  static Future<void> deleteJwtToken() async {
    await _secureStorage.delete(
      key: jwtTokenKey,
    );
  }

  // ============================================================
  // MEDIA FOLDERS
  // ============================================================

  /// Requests access to BOTH required media locations:
  ///
  /// 1. Internal storage/Pictures
  /// 2. Internal storage/DCIM
  ///
  /// Android handles the two specific SAF permission dialogs.
  ///
  /// Returns:
  ///
  /// {
  ///   'picturesUri': 'content://...',
  ///   'dcimUri': 'content://...'
  /// }
  ///
  /// No generic folder-selection screen is used.
  static Future<Map<String, String>?> requestMediaFolders() async {
    try {
      final result =
          await _storageChannel.invokeMethod<Map<dynamic, dynamic>>(
        'requestMediaFolders',
      );

      if (result == null) {
        debugPrint(
          'Media folder permission was cancelled.',
        );

        return null;
      }

      final picturesUri =
          result['picturesUri']?.toString();

      final dcimUri =
          result['dcimUri']?.toString();

      if (picturesUri == null ||
          picturesUri.isEmpty ||
          dcimUri == null ||
          dcimUri.isEmpty) {
        debugPrint(
          'Invalid media folder URIs received.',
        );

        return null;
      }

      debugPrint(
        'Pictures URI: $picturesUri',
      );

      debugPrint(
        'DCIM URI: $dcimUri',
      );

      return {
        'picturesUri': picturesUri,
        'dcimUri': dcimUri,
      };
    } on PlatformException catch (e) {
      debugPrint(
        'Failed to request media folders: '
        '${e.code} - ${e.message}',
      );

      return null;
    } catch (e) {
      debugPrint(
        'Unexpected media folder error: $e',
      );

      return null;
    }
  }

  // ============================================================
  // PICTURES FOLDER
  // ============================================================

  /// Opens Android's SAF picker specifically at Pictures.
  ///
  /// Kept for compatibility with older code.
  static Future<String?> requestPicturesFolder() async {
    try {
      final String? uri =
          await _storageChannel.invokeMethod<String>(
        'requestPicturesFolder',
      );

      if (uri != null && uri.isNotEmpty) {
        debugPrint(
          'Pictures folder URI received: $uri',
        );
      }

      return uri;
    } on PlatformException catch (e) {
      debugPrint(
        'Failed to request Pictures folder: '
        '${e.code} - ${e.message}',
      );

      return null;
    } catch (e) {
      debugPrint(
        'Unexpected Pictures folder error: $e',
      );

      return null;
    }
  }

  // ============================================================
  // GET PICTURES URI
  // ============================================================

  static Future<String?> getPicturesFolderUri() async {
    try {
      final String? uri =
          await _storageChannel.invokeMethod<String>(
        'getPicturesFolderUri',
      );

      if (uri != null && uri.isNotEmpty) {
        debugPrint(
          'Saved Pictures URI: $uri',
        );
      }

      return uri;
    } on PlatformException catch (e) {
      debugPrint(
        'Failed to get Pictures URI: '
        '${e.code} - ${e.message}',
      );

      return null;
    } catch (e) {
      debugPrint(
        'Unexpected error getting Pictures URI: $e',
      );

      return null;
    }
  }

  // ============================================================
  // GET DCIM URI
  // ============================================================

  static Future<String?> getDcimFolderUri() async {
    try {
      final String? uri =
          await _storageChannel.invokeMethod<String>(
        'getDcimFolderUri',
      );

      if (uri != null && uri.isNotEmpty) {
        debugPrint(
          'Saved DCIM URI: $uri',
        );
      }

      return uri;
    } on PlatformException catch (e) {
      debugPrint(
        'Failed to get DCIM URI: '
        '${e.code} - ${e.message}',
      );

      return null;
    } catch (e) {
      debugPrint(
        'Unexpected error getting DCIM URI: $e',
      );

      return null;
    }
  }

  // ============================================================
  // GET ALL MEDIA FOLDERS
  // ============================================================

  /// Returns both protected media locations.
  static Future<Map<String, String>> getMediaFolders() async {
    final picturesUri =
        await getPicturesFolderUri();

    final dcimUri =
        await getDcimFolderUri();

    final Map<String, String> folders = {};

    if (picturesUri != null &&
        picturesUri.isNotEmpty) {
      folders['picturesUri'] = picturesUri;
    }

    if (dcimUri != null &&
        dcimUri.isNotEmpty) {
      folders['dcimUri'] = dcimUri;
    }

    return folders;
  }

  // ============================================================
  // OLD FOLDER PICKER
  // ============================================================

  //
  // Kept temporarily for compatibility.
  //
  // It should NOT be used by the signup flow.
  //
  // ============================================================

  static Future<String?> pickFolder() async {
    try {
      final String? uri =
          await _storageChannel.invokeMethod<String>(
        'pickFolder',
      );

      return uri;
    } on PlatformException catch (e) {
      debugPrint(
        'Folder picker error: ${e.message}',
      );

      return null;
    } catch (e) {
      debugPrint(
        'Unexpected folder picker error: $e',
      );

      return null;
    }
  }

  // ============================================================
  // ACCOUNT
  // ============================================================

  static Future<void> saveAccount(bool value) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(
      hasAccountKey,
      value,
    );
  }

  static Future<bool> hasAccount() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getBool(
          hasAccountKey,
        ) ??
        false;
  }

  // ============================================================
  // LOGIN STATUS
  // ============================================================

  static Future<void> saveLoggedIn(bool value) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(
      loggedInKey,
      value,
    );
  }

  static Future<bool> isLoggedIn() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getBool(
          loggedInKey,
        ) ??
        false;
  }

  // ============================================================
  // PROTECTED FOLDERS
  // ============================================================

  //
  // OLD multi-folder architecture.
  //
  // Kept temporarily so existing screens/code do not break.
  //
  // New media protection uses:
  //
  //   Pictures URI
  //   DCIM URI
  //
  // ============================================================

  static Future<void> saveProtectedFolders(
    List<Map<String, String>> folders,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final List<String> data =
        folders.map((folder) {
      final name =
          folder['name'] ?? '';

      final uri =
          folder['uri'] ?? '';

      return '$name|$uri';
    }).toList();

    await prefs.setStringList(
      protectedFoldersKey,
      data,
    );
  }

  static Future<List<Map<String, String>>>
      loadProtectedFolders() async {
    final prefs =
        await SharedPreferences.getInstance();

    final savedFolders =
        prefs.getStringList(
      protectedFoldersKey,
    );

    if (savedFolders == null ||
        savedFolders.isEmpty) {
      return [];
    }

    final List<Map<String, String>>
        folders = [];

    for (final folder in savedFolders) {
      final data =
          folder.split('|');

      if (data.length < 2) {
        continue;
      }

      final name = data[0];

      final uri =
          data.sublist(1).join('|');

      if (uri.isEmpty) {
        continue;
      }

      folders.add({
        'name': name,
        'uri': uri,
      });
    }

    return folders;
  }

  // ============================================================
  // STOP DATASHIELD SERVICE
  // ============================================================

  static Future<void>
      stopDataShieldService() async {
    try {
      await _serviceChannel.invokeMethod(
        'stopService',
      );

      debugPrint(
        'DataShield foreground service stopped.',
      );
    } on PlatformException catch (e) {
      debugPrint(
        'Failed to stop DataShield service: '
        '${e.code}: ${e.message}',
      );
    } catch (e) {
      debugPrint(
        'Failed to stop DataShield service: $e',
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static Future<void> logout() async {
    await stopDataShieldService();

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(
      loggedInKey,
      false,
    );

    await deleteJwtToken();

    debugPrint(
      'DataShield logout completed.',
    );
  }

  // ============================================================
  // CLEAR ALL DATA
  // ============================================================

  static Future<void> clearAll() async {
    await stopDataShieldService();

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.clear();

    await _secureStorage.deleteAll();

    debugPrint(
      'All DataShield local data cleared.',
    );
  }
}