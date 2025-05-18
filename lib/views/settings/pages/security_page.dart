import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isSecurityEnabled = false;
  String _lockMethod = 'PIN';
  List<String> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheckBiometrics = await auth.canCheckBiometrics;
      final isDeviceSupported = await auth.isDeviceSupported();

      if (canCheckBiometrics && isDeviceSupported) {
        final availableBiometrics = await auth.getAvailableBiometrics();
        setState(() {
          _availableBiometrics = availableBiometrics
              .map((biometric) => _formatBiometricName(biometric))
              .toList();
        });
      }
    } catch (e) {
      print('Error checking biometrics: $e');
    }
  }

  String _formatBiometricName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
      default:
        return 'Biometric';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Security',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.primary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with explanation
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Protect your emails with additional security measures',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // App lock section
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text(
              'App Lock',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          // App lock card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.dividerColor.withOpacity(0.1),
              ),
            ),
            child: Column(
              children: [
                // Enable security switch
                SwitchListTile(
                  title: const Text('Enable Security'),
                  subtitle: Text(
                    'Lock the app when not in use',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  value: _isSecurityEnabled,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (value) {
                    setState(() {
                      _isSecurityEnabled = value;
                    });
                  },
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock, color: Colors.red),
                  ),
                ),

                if (_isSecurityEnabled) ...[
                  Divider(height: 1, indent: 70, color: theme.dividerColor.withOpacity(0.1)),

                  // Lock method selection
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fingerprint, color: Colors.blue),
                    ),
                    title: const Text('Lock Method'),
                    subtitle: Text(
                      'Choose how to unlock the app',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _lockMethod,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ],
                    ),
                    onTap: () {
                      _showLockMethodPicker(context);
                    },
                  ),

                  Divider(height: 1, indent: 70, color: theme.dividerColor.withOpacity(0.1)),

                  // Auto-lock timing
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.timer, color: Colors.purple),
                    ),
                    title: const Text('Auto-Lock'),
                    subtitle: Text(
                      'Lock app after period of inactivity',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Immediately',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ],
                    ),
                    onTap: () {
                      // Show auto-lock timing options
                    },
                  ),
                ],
              ],
            ),
          ),

          // Privacy section
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'Privacy',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          // Privacy card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.dividerColor.withOpacity(0.1),
              ),
            ),
            child: Column(
              children: [
                // Hide notification content
                SwitchListTile(
                  title: const Text('Hide Notification Content'),
                  subtitle: Text(
                    'Show "New Email" instead of message preview',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  value: false,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (value) {
                    // Toggle notification privacy
                  },
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.notifications_off, color: Colors.orange),
                  ),
                ),

                Divider(height: 1, indent: 70, color: theme.dividerColor.withOpacity(0.1)),

                // Block remote images
                SwitchListTile(
                  title: const Text('Block Remote Images'),
                  subtitle: Text(
                    'Prevent loading images from external sources',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  value: false,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (value) {
                    // Toggle remote image blocking
                  },
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image_not_supported, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),

          // Security info
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Your security settings only apply to this device',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLockMethodPicker(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Choose Lock Method',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),

              // PIN option
              ListTile(
                leading: Icon(
                  Icons.pin_outlined,
                  color: _lockMethod == 'PIN' ? theme.colorScheme.primary : null,
                ),
                title: const Text('PIN'),
                trailing: _lockMethod == 'PIN' ? Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                ) : null,
                onTap: () {
                  setState(() {
                    _lockMethod = 'PIN';
                  });
                  Navigator.pop(context);
                },
              ),

              // Show biometric options if available
              for (final biometric in _availableBiometrics)
                ListTile(
                  leading: Icon(
                    biometric.contains('Face') ? Icons.face : Icons.fingerprint,
                    color: _lockMethod == biometric ? theme.colorScheme.primary : null,
                  ),
                  title: Text(biometric),
                  trailing: _lockMethod == biometric ? Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                  ) : null,
                  onTap: () {
                    setState(() {
                      _lockMethod = biometric;
                    });
                    Navigator.pop(context);
                  },
                ),

              // Pattern option
              ListTile(
                leading: Icon(
                  Icons.pattern,
                  color: _lockMethod == 'Pattern' ? theme.colorScheme.primary : null,
                ),
                title: const Text('Pattern'),
                trailing: _lockMethod == 'Pattern' ? Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                ) : null,
                onTap: () {
                  setState(() {
                    _lockMethod = 'Pattern';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
