import '../services/storage_service.dart';

class AuthService {
  // Signup
  Future<bool> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    // Temporary local signup
    await StorageService.saveAccount(true);
    return true;
  }

  // Login
  Future<bool> login({required String email, required String password}) async {
    // Temporary local login
    return true;
  }

  // Check if account exists
  Future<bool> hasAccount() async {
    return await StorageService.hasAccount();
  }

  // Check login status
  Future<bool> isLoggedIn() async {
    return await StorageService.isLoggedIn();
  }

  // Logout
  Future<void> logout() async {
    await StorageService.logout();
  }

  Future<bool> verifyPin(String enteredPin) async {
    String savedPin = await StorageService.getPin();

    return enteredPin == savedPin;
  }
}