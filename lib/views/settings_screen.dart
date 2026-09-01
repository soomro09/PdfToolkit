import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import 'widgets/custom_app_bar.dart';

// 🎨 Provider for storing and switching the app accent color globally
// final accentColorProvider = StateProvider<Color>((ref) => AppColors.primaryRed);

// ⏱️ Provider for auto-delete history preference (0 = Never, 7 = 7 Days, 30 = 30 Days)
final autoDeleteDaysProvider = StateProvider<int>((ref) => 0);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _cacheSizeStr = 'Calculating...';
  bool _isLoadingCache = true;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  // 📊 Calculate exact temp directory size in MB
  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalBytes = 0;

      if (tempDir.existsSync()) {
        final List<FileSystemEntity> entities = tempDir.listSync(
          recursive: true,
          followLinks: false,
        );
        for (var entity in entities) {
          if (entity is File) {
            totalBytes += await entity.length();
          }
        }
      }

      double mb = totalBytes / (1024 * 1024);
      if (!mounted) return;
      setState(() {
        _cacheSizeStr = mb < 1
            ? '${(totalBytes / 1024).toStringAsFixed(1)} KB used'
            : '${mb.toStringAsFixed(1)} MB used';
        _isLoadingCache = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cacheSizeStr = 'Size unavailable';
        _isLoadingCache = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAccent = ref.watch(accentColorProvider);
    final autoDeleteDays = ref.watch(autoDeleteDaysProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Settings', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💾 Storage & Performance Section
            _buildSectionHeader('Storage & Performance'),
            _buildSettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.cleaning_services_rounded,
                  iconColor: Colors.blue.shade600,
                  title: 'Clear Temporary Cache',
                  subtitle: _isLoadingCache
                      ? 'Calculating size...'
                      : _cacheSizeStr,
                  onTap: () => _handleClearCache(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 🔒 Privacy & Data Section
            _buildSectionHeader('Privacy & Data'),
            _buildSettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.history_toggle_off_rounded,
                  iconColor: Colors.orange.shade700,
                  title: 'Auto-Delete History',
                  subtitle: autoDeleteDays == 0
                      ? 'Keep history permanently'
                      : 'Automatically wipe after $autoDeleteDays days',
                  trailing: DropdownButton<int>(
                    value: autoDeleteDays,
                    underline: const SizedBox(),
                    dropdownColor: AppColors.surface,
                    items: const [
                      DropdownMenuItem(
                        value: 0,
                        child: Text('Never', style: TextStyle(fontSize: 13)),
                      ),
                      DropdownMenuItem(
                        value: 7,
                        child: Text('7 Days', style: TextStyle(fontSize: 13)),
                      ),
                      DropdownMenuItem(
                        value: 30,
                        child: Text('30 Days', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(autoDeleteDaysProvider.notifier).state = val;
                        HapticFeedback.selectionClick();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 🎨 Appearance Section
            _buildSectionHeader('Appearance'),
            _buildSettingsGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: currentAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.palette_rounded,
                          size: 20,
                          color: currentAccent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accent Color',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Customize your app style',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDivider(),
                // Color Picker Circles Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildColorOption(
                        ref,
                        const Color(0xFFD32F2F),
                        'Crimson',
                      ),
                      _buildColorOption(ref, const Color(0xFF1976D2), 'Blue'),
                      _buildColorOption(
                        ref,
                        const Color(0xFF388E3C),
                        'Emerald',
                      ),
                      _buildColorOption(ref, const Color(0xFF7B1FA2), 'Purple'),
                      _buildColorOption(ref, const Color(0xFFE65100), 'Amber'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ℹ️ About Section
            // _buildSectionHeader('About & Support'),
            // _buildSettingsGroup(
            //   children: [
            //     _SettingsTile(
            //       icon: Icons.star_rounded,
            //       iconColor: Colors.amber.shade500,
            //       title: 'Rate the App',
            //       onTap: () {
            //         HapticFeedback.lightImpact();
            //         _showMessageDialog(
            //           context,
            //           'Rate App',
            //           'Opens the Play Store / App Store! 🚀',
            //         );
            //       },
            //     ),
            //     _buildDivider(),
            //     _SettingsTile(
            //       icon: Icons.share_rounded,
            //       iconColor: Colors.green.shade500,
            //       title: 'Share with Friends',
            //       onTap: () {
            //         HapticFeedback.lightImpact();
            //         _showMessageDialog(
            //           context,
            //           'Share',
            //           'Triggers the native share dialog! 📲',
            //         );
            //       },
            //     ),
            //     _buildDivider(),
            //     _SettingsTile(
            //       icon: Icons.privacy_tip_rounded,
            //       iconColor: Colors.grey.shade700,
            //       title: 'Privacy Policy',
            //       onTap: () {
            //         HapticFeedback.lightImpact();
            //         _showMessageDialog(
            //           context,
            //           'Privacy Policy',
            //           'Secure local device processing. No cloud uploads! 🔐',
            //         );
            //       },
            //     ),
            //   ],
            // ),
            const SizedBox(height: 40),

            // App Version Footer
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: currentAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: currentAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'PDF Utility Pro',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border,
      indent: 56,
    );
  }

  // 🎨 Color option widget for theme picker
  Widget _buildColorOption(WidgetRef ref, Color color, String label) {
    final selectedColor = ref.watch(accentColorProvider);
    final isSelected = selectedColor == color;

    return GestureDetector(
      onTap: () {
        ref.read(accentColorProvider.notifier).state = color;
        HapticFeedback.selectionClick();
      },
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.textPrimary : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 🧹 Fully operational Cache Clearer
  Future<void> _handleClearCache(BuildContext context) async {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primaryRed),
              const SizedBox(width: 20),
              const Text(
                'Clearing cache...',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );

    bool success = false;
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final List<FileSystemEntity> files = tempDir.listSync();
        for (final file in files) {
          file.deleteSync(recursive: true);
        }
      }
      success = true;
    } catch (e) {
      debugPrint('Cache clear error: $e');
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    // Recalculate cache size display after cleaning
    await _calculateCacheSize();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                success
                    ? 'Temporary cache cleared successfully!'
                    : 'Failed to clear some cache files.',
              ),
            ),
          ],
        ),
        backgroundColor: success ? Colors.green.shade600 : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showMessageDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// 🎨 Custom Settings Tile Widget
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
