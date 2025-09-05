import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/features/auth/presentation/screens/login/login.dart';

/// Controller responsible for authentication-related operations
class AuthController extends GetxController {
  final Logger logger = Logger();

  // Observable to track authentication state
  final RxBool isAuthenticated = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Check if user is already authenticated
    final storage = GetStorage();
    final hasCredentials =
        storage.hasData('email') && storage.hasData('password');
    isAuthenticated.value = hasCredentials;

    // Register with other controllers that might need auth state
    ever(isAuthenticated, (_) => _notifyAuthStateChanged());
  }

  /// Notify other controllers about authentication state changes
  void _notifyAuthStateChanged() {
    // This helps with initialization order issues
    // Other controllers can react to auth state changes
    Get.put(MailService.instance, permanent: true);
  }

  /// Logs out the user, clears all data, and navigates to login screen
  ///
  /// This method:
  /// 1. Erases all stored data
  /// 2. Disconnects the mail client
  /// 3. Disposes mail service resources
  /// 4. Deletes the account data
  /// 5. Cancels all background tasks
  /// 6. Navigates to the login screen
  Future<void> logout() async {
    try {
      // Update authentication state first
      isAuthenticated.value = false;

      // Disconnect mail client and dispose resources
      if (MailService.instance.client.isConnected) {
        await MailService.instance.client.disconnect();
      }
      MailService.instance.dispose();

      // Delete account data
      await deleteAccount();

      // Cancel all background tasks
      await Workmanager().cancelAll();

      // Clear all stored data - do this last to ensure other operations complete
      await GetStorage().erase();

      // Navigate to login screen
      Get.offAll(() => const LoginScreen());
    } catch (e) {
      logger.e("Error during logout: $e");
      // Even if there's an error, try to navigate to login
      Get.offAll(() => const LoginScreen());
    }
  }

  /// Deletes the account data
  ///
  /// This is a placeholder method that should be implemented
  /// to delete any account-specific data
  Future<void> deleteAccount() async {
    // Implementation depends on your specific account data storage
    try {
      // Add any account deletion logic here
      // For example, clearing specific storage keys
      final storage = GetStorage();
      await storage.remove('email');
      await storage.remove('password');
      await storage.remove('boxes');
      await storage.remove('mails');

      // You might want to clear database tables as well
      // This would require access to your database implementation
    } catch (e) {
      logger.e("Error deleting account: $e");
    }
  }

  /// Login method with improved error handling and state management
  Future<bool> login(String email, String password) async {
    try {
      // Store credentials
      final storage = GetStorage();
      await storage.write('email', email);
      await storage.write('password', password);

      // Update authentication state
      isAuthenticated.value = true;

      return true;
    } catch (e) {
      logger.e("Error during login: $e");
      return false;
    }
  }

  /// Clears all storage data without logging out
  ///
  /// This method:
  /// 1. Clears all app settings and preferences
  /// 2. Maintains authentication state
  /// 3. Does not disconnect mail client or cancel background tasks
  /// 4. Used primarily for resetting app to default settings
  Future<void> clearStorage() async {
    try {
      logger.i("Clearing app storage data");

      // Get current authentication credentials to preserve them
      final storage = GetStorage();
      final email = storage.read('email');
      final password = storage.read('password');

      // Clear all settings except authentication
      await storage.erase();

      // Restore authentication if needed
      if (email != null && password != null) {
        await storage.write('email', email);
        await storage.write('password', password);
      }

      logger.i("App storage data cleared successfully");
    } catch (e) {
      logger.e("Error clearing storage: $e");
      throw Exception("Failed to clear app data: $e");
    }
  }
}
