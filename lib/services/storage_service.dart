import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {

  static const MethodChannel _channel =
      MethodChannel('datashield/storage');


  // ==========================
  // Android Folder Picker
  // ==========================

  static Future<String?> pickFolder() async {
    try {
      final String? uri =
          await _channel.invokeMethod<String>('pickFolder');

      return uri;

    } on PlatformException catch (e) {
      print("Error: ${e.message}");
      return null;
    }
  }



  // ==========================
  // Account Management
  // ==========================

  static const String hasAccountKey = 'hasAccount';
  static const String loggedInKey = 'loggedIn';
  static const String pinKey = 'pin';


  static Future<void> saveAccount(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      hasAccountKey,
      value,
    );
  }


  static Future<bool> hasAccount() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(hasAccountKey) ?? false;
  }



  // ==========================
  // Login Status
  // ==========================

  static Future<void> saveLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      loggedInKey,
      value,
    );
  }


  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(loggedInKey) ?? false;
  }



  // ==========================
  // PIN Storage
  // ==========================

  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      pinKey,
      pin,
    );
  }


  static Future<String> getPin() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(pinKey) ?? "";
  }



  // ==========================
  // Protected Folders
  // ==========================


  static Future<void> saveProtectedFolders(
      List<Map<String,String>> folders
  ) async {

    final prefs = await SharedPreferences.getInstance();


    List<String> data = folders.map((folder){

      return "${folder['name']}|${folder['uri']}";

    }).toList();


    await prefs.setStringList(
      "protectedFolders",
      data,
    );
  }



  static Future<List<Map<String,String>>> loadProtectedFolders() async {

    final prefs = await SharedPreferences.getInstance();


    final savedFolders =
        prefs.getStringList("protectedFolders");


    if(savedFolders == null){
      return [];
    }


    return savedFolders.map((folder){

      final data = folder.split("|");


      return {
        "name": data[0],
        "uri": data[1],
      };


    }).toList();

  }



  // ==========================
  // Logout / Clear Data
  // ==========================

  static Future<void> logout() async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      loggedInKey,
      false,
    );
  }



  static Future<void> clearAll() async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();
  }

}