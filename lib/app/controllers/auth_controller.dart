import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/views/authantication/screens/login/login.dart';

/// Controller responsible for authentication-related operations
class AuthController extends GetxController {
  final Logger logger = Logger();
  
  @override
  void onInit() {
    super.onInit();
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
      // Clear all stored data
      await GetStorage().erase();
      
      // Disconnect mail client and dispose resources
      MailService.instance.client.disconnect();
      MailService.instance.dispose();
      
      // Delete account data
      await deleteAccount();
      
      // Cancel all background tasks
      await Workmanager().cancelAll();
      
      // Navigate to login screen
      Get.offAll(() => LoginScreen());
    } catch (e) {
      logger.e("Error during logout: $e");
      // Even if there's an error, try to navigate to login
      Get.offAll(() => LoginScreen());
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
}
