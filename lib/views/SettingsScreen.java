import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/providers/theme_provider.dart';
import 'widgets/custom_app_bar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomAppBar(
        title: 'Settings',
        actions: [],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Appearance Section
                _buildSectionHeader('Appearance', Icons.palette_outlined),
                Card(
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Theme mode selector
                      ListTile(
                        leading: const Icon(Icons.brightness_6_outlined),
                        title: const Text('Theme Mode'),
                        subtitle: Text(themeMode.toString().split('.').last.toUpperCase()),
                        trailing: PopupMenuButton<AppThemeMode>(
                          initialValue: themeMode,
                          onSelected: (mode) => themeNotifier.setThemeMode(mode),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: AppThemeMode.system,
                              child: Text('System Default'),
                            ),
                            const PopupMenuItem(
                              value: AppThemeMode.light,
                              child: Text('Light'),
                            ),
                            const PopupMenuItem(
                              value: AppThemeMode.dark,
                              child: Text('Dark'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Dark mode switch
                      SwitchListTile(
                        secondary: const Icon(Icons.dark_mode_outlined),
                        title: const Text('Dark Mode'),
                        subtitle: const Text('Enable dark theme'),
                        value: themeMode == AppThemeMode.dark,
                        onChanged: (value) {
                          themeNotifier.setThemeMode(
                            value ? AppThemeMode.dark : AppThemeMode.light,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // General Section
                _buildSectionHeader('General', Icons.settings_outlined),
                Card(
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Notifications toggle
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text('Notifications'),
                        subtitle: const Text('Get updates when tasks complete'),
                        value: settings.notificationsEnabled,
                        onChanged: notifier.toggleNotifications,
                      ),
                      const Divider(height: 1),
                      // Default output directory
                      ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: const Text('Default Output Directory'),
                        subtitle: Text(settings.defaultOutputDirectory),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showDirectoryPicker(notifier),
                      ),
                      const Divider(height: 1),
                      // Compression level
                      ListTile(
                        leading: const Icon(Icons.compress_outlined),
                        title: const Text('Default Compression Level'),
                        subtitle: Text(_compressionLabel(settings.compressionLevel)),
                        trailing: DropdownButton<int>(
                          value: settings.compressionLevel,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Low')),
                            DropdownMenuItem(value: 1, child: Text('Medium')),
                            DropdownMenuItem(value: 2, child: Text('High')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              notifier.setCompressionLevel(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Security Section
                _buildSectionHeader('Security', Icons.security_outlined),
                Card(
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Biometric Lock'),
                    subtitle: const Text('Require fingerprint to open app'),
                    value: settings.biometricLock,
                    onChanged: notifier.toggleBiometricLock,
                  ),
                ),
                const SizedBox(height: 24),

                // About Section
                _buildSectionHeader('About', Icons.info_outline),
                Card(
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('App Version'),
                        subtitle: Text('1.0.0'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Open privacy policy
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.rate_review_outlined),
                        title: const Text('Rate Us'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Open rating
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  String _compressionLabel(int level) {
    switch (level) {
      case 0:
        return 'Low (faster)';
      case 1:
        return 'Medium (balanced)';
      case 2:
        return 'High (smaller size)';
      default:
        return 'Medium';
    }
  }

  void _showDirectoryPicker(SettingsNotifier notifier) {
    // Simple dialog to choose a directory (mock)
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Output Directory'),
          content: const Text('Choose where to save processed PDFs.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                notifier.setDefaultOutputDirectory('Custom Folder');
                Navigator.pop(context);
              },
              child: const Text('Use Custom'),
            ),
          ],
        );
      },
    );
  }
}