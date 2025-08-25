import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/controllers/settings_controller.dart';
import '../../../services/security_service.dart';

class AuthScreen extends StatelessWidget {
  final SettingController _settingsController = Get.find<SettingController>();
  
  AuthScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [Colors.grey.shade900, Colors.black]
                : [theme.colorScheme.primary.withValues(alpha : 0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo or icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // App locked text
                Text(
                  'App Locked',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Instruction text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Please authenticate to access your emails',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Unlock button
                ElevatedButton.icon(
                  icon: Icon(_getLockMethodIcon()),
                  label: Text('Unlock with ${_getLockMethodText()}'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _authenticate,
                ),
                
                const SizedBox(height: 24),
                
                // Help text
                TextButton(
                  onPressed: () {
                    // Show help dialog or instructions
                    Get.dialog(
                      AlertDialog(
                        title: const Text('Authentication Help'),
                        content: Text(
                          'This app is locked for your security. To unlock, use your ${_getLockMethodText().toLowerCase()} authentication method.\n\n'
                          'If you\'re having trouble, try closing the app completely and reopening it.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    'Need help?',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  IconData _getLockMethodIcon() {
    switch (_settingsController.lockMethod.value) {
      case 'biometric':
        return Icons.fingerprint_rounded;
      case 'pattern':
        return Icons.pattern_rounded;
      case 'pin':
      default:
        return Icons.pin_rounded;
    }
  }
  
  String _getLockMethodText() {
    switch (_settingsController.lockMethod.value) {
      case 'biometric':
        return 'Biometric';
      case 'pattern':
        return 'Pattern';
      case 'pin':
      default:
        return 'PIN';
    }
  }
  
  Future<void> _authenticate() async {
    final authenticated = await _settingsController.unlockApp();
    if (authenticated) {
      Get.offAllNamed('/home');
    } else {
      Get.snackbar(
        'Authentication Failed',
        'Please try again to access your emails',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 10,
        duration: const Duration(seconds: 3),
      );
    }
  }
}
