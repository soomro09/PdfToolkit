import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/pdf_tool_type.dart';
import '../../../models/signature_placement_model.dart';
import '../../pdf_compress/models/compression_level.dart';
import '../../pdf_compress/services/pdf_compress_service.dart';
import '../../../services/pdf_engine_service.dart';
import '../../../views/page_editor_screen.dart';
import '../../../views/pdf_editor_screen.dart';
import '../../../views/split_screen_range.dart';
import '../../../views/watermark_setting_screen.dart';
import '../../../views/widgets/unlock_password_dialog.dart';
import '../views/pdf_result_screen.dart';
import '../views/pdf_signature_overlay_screen.dart';
import '../views/signature_pad_screen.dart';
import '../views/text_view_screen.dart';
import '../widgets/password_dialog.dart';
import 'pdf_task_controller.dart';

class ToolSelectionController {
  /// Formats file size bytes into readable KB/MB
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Handles picking files from device storage
  static Future<List<File>> pickFiles(
    PdfToolType toolType,
    List<File> currentFiles,
  ) async {
    List<PlatformFile> pickedPlatformFiles;

    if (toolType == PdfToolType.imagesToPdf) {
      pickedPlatformFiles = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: toolType.allowMultiple,
      );
    } else {
      pickedPlatformFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: toolType.allowMultiple,
      );
    }

    if (pickedPlatformFiles.isNotEmpty) {
      return pickedPlatformFiles
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .where((file) => !currentFiles.any((f) => f.path == file.path))
          .toList();
    }
    return [];
  }

  /// Master method to process the selected tool task
  static Future<void> proceedToTask({
    required BuildContext context,
    required WidgetRef ref,
    required PdfToolType toolType,
    required List<File> selectedFiles,
    String? textContent,
    String? documentTitle,
  }) async {
    // Text to PDF validation & processing
    if (toolType == PdfToolType.textToPdf) {
      if (textContent == null || textContent.trim().isEmpty) return;

      _showLoadingDialog(context, toolType: toolType);
      try {
        final res = await PdfEngineService.textToPdf(
          textContent.trim(),
          title: documentTitle ?? 'Document',
        );
        ref.read(pdfTaskControllerProvider.notifier).state = AsyncValue.data([
          res,
        ]);
        _handleResult(context, ref, toolType, selectedFiles);
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to compile PDF: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
      return;
    }

    // Unlock PDF logic (Handles its own security checks)
    if (toolType == PdfToolType.unlockPdf) {
      _showLoadingDialog(
        context,
        message: 'Checking document security...',
        toolType: toolType,
      );

      final isEncrypted = await PdfEngineService.isPdfEncrypted(
        selectedFiles.first,
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (!isEncrypted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This PDF is not password-protected and does not need unlocking.',
            ),
          ),
        );
        return;
      }

      final password = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (context) => const UnlockPasswordDialog(),
      );

      if (password == null || password.trim().isEmpty || !context.mounted) {
        return;
      }

      _showLoadingDialog(
        context,
        message: 'Unlocking document...',
        toolType: toolType,
      );

      try {
        final res = await PdfEngineService.unlockPdf(
          selectedFiles.first,
          password.trim(),
        );

        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PdfResultScreen(resultFiles: [res], title: 'Unlocked PDF'),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to unlock. Please verify your password.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (selectedFiles.length < toolType.minFiles) return;

    // Security check for non-image inputs
    if (toolType != PdfToolType.imagesToPdf) {
      _showLoadingDialog(
        context,
        message: 'Verifying document...',
        toolType: toolType,
      );
      bool containsLockedFile = false;

      for (final file in selectedFiles) {
        final isEncrypted = await PdfEngineService.isPdfEncrypted(file);
        if (isEncrypted) {
          containsLockedFile = true;
          break;
        }
      }

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (containsLockedFile) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Protected PDF detected! Please use the "Unlock PDF" tool first.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
    }

    final notifier = ref.read(pdfTaskControllerProvider.notifier);
    String? protectionPassword;
    File? signatureImage;
    Map<String, dynamic>? placementResult;
    CompressionLevel? selectedCompressionLevel;

    // 1. Route Dedicated Interactive Flow Screens
    if (toolType == PdfToolType.split) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SplitRangeScreen(
            pdfFile: selectedFiles.first,
            isJpgExport: false,
          ),
        ),
      );
      return;
    }

    if (toolType == PdfToolType.pdfToJpg) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SplitRangeScreen(pdfFile: selectedFiles.first, isJpgExport: true),
        ),
      );
      return;
    }

    if (toolType == PdfToolType.organizePdf) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PageEditorScreen(pdfFile: selectedFiles.first),
        ),
      );
      return;
    }

    if (toolType == PdfToolType.watermark) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              WatermarkSettingsScreen(pdfFile: selectedFiles.first),
        ),
      );
      return;
    }

    if (toolType == PdfToolType.editPdf) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfEditorScreen(pdfFile: selectedFiles.first),
        ),
      );
      return;
    }

    if (toolType == PdfToolType.pdfToText) {
      _showLoadingDialog(context, toolType: toolType);
      try {
        final extractedText = await PdfEngineService.pdfToText(
          selectedFiles.first,
        );
        if (!context.mounted) return;
        Navigator.pop(context);

        final fileName = selectedFiles.first.path.split('/').last;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExtractedTextViewScreen(
              text: extractedText,
              documentName: fileName,
            ),
          ),
        );
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Extraction failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
      return;
    }

    // 2. Gather Dialog Inputs
    if (toolType == PdfToolType.compress) {
      selectedCompressionLevel = await _showCompressionDialog(context);
      if (selectedCompressionLevel == null) return;
    }

    if (toolType == PdfToolType.protect) {
      protectionPassword = await showDialog<String>(
        context: context,
        builder: (context) => const PasswordDialog(),
      );
      if (protectionPassword == null) return;
    }

    if (toolType == PdfToolType.sign) {
      signatureImage = await Navigator.push<File>(
        context,
        MaterialPageRoute(builder: (context) => const SignaturePadScreen()),
      );
      if (signatureImage == null || !context.mounted) return;

      placementResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => PdfSignatureOverlayScreen(
            pdfFile: selectedFiles.first,
            signatureImage: signatureImage!,
          ),
        ),
      );
      if (placementResult == null) return;
    }

    // 3. Execute Background Tasks
    if (!context.mounted) return;
    _showLoadingDialog(context, toolType: toolType);

    try {
      switch (toolType) {
        case PdfToolType.merge:
          await notifier.executeMerge(selectedFiles);
          break;
        case PdfToolType.compress:
          await notifier.executeCompress(
            selectedFiles.first,
            selectedCompressionLevel!,
          );
          break;
        case PdfToolType.imagesToPdf:
          // 🚀 Handle Images directly to avoid blocking
          final generatedPdf = await PdfEngineService.imagesToPdf(
            selectedFiles,
          );
          notifier.state = AsyncValue.data([generatedPdf]);
          break;
        case PdfToolType.protect:
          await notifier.executeProtect(
            selectedFiles.first,
            protectionPassword!,
          );
          break;
        case PdfToolType.sign:
          final signedFile = await PdfEngineService.signPdf(
            pdfFile: selectedFiles.first,
            signatureImageFile: signatureImage!,
            placements:
                placementResult!['placements'] as List<SignaturePlacement>,
            renderedPageSize: placementResult['renderedPageSize'] as Size,
          );
          notifier.state = AsyncValue.data([signedFile]);
          break;
        default:
          break;
      }
      _handleResult(context, ref, toolType, selectedFiles);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // --- Private Helpers --- //

  static void _handleResult(
    BuildContext context,
    WidgetRef ref,
    PdfToolType toolType,
    List<File> originalFiles,
  ) {
    if (!context.mounted) return;
    Navigator.pop(context);

    final taskState = ref.read(pdfTaskControllerProvider);
    taskState.whenData((resultFiles) {
      if (resultFiles != null && resultFiles.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfResultScreen(
              resultFiles: resultFiles,
              title: toolType.title,
              originalFile: toolType == PdfToolType.compress
                  ? originalFiles.first
                  : null,
            ),
          ),
        );
      }
    });
  }

  /// Gets the matching icon for the progress dialog based on the tool
  static IconData _getToolIcon(PdfToolType? toolType) {
    if (toolType == null) return Icons.auto_awesome_rounded;
    switch (toolType) {
      case PdfToolType.merge:
        return Icons.call_merge_rounded;
      case PdfToolType.split:
        return Icons.call_split_rounded;
      case PdfToolType.compress:
        return Icons.compress_rounded;
      case PdfToolType.sign:
        return Icons.draw_rounded;
      case PdfToolType.protect:
        return Icons.lock_outline_rounded;
      case PdfToolType.unlockPdf:
        return Icons.lock_open_rounded;
      case PdfToolType.imagesToPdf:
        return Icons.photo_library_outlined;
      case PdfToolType.scanner:
        return Icons.document_scanner_rounded;
      case PdfToolType.textToPdf:
        return Icons.text_snippet_rounded;
      case PdfToolType.pdfToText:
        return Icons.subject_rounded;
      case PdfToolType.pdfToJpg:
        return Icons.image_rounded;
      case PdfToolType.watermark:
        return Icons.water_drop_rounded;
      case PdfToolType.organizePdf:
        return Icons.grid_view_rounded;
      case PdfToolType.editPdf:
        return Icons.edit_note_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  static void _showLoadingDialog(
    BuildContext context, {
    String message = "Processing PDF operation...",
    PdfToolType? toolType,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final activeIcon = _getToolIcon(toolType);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    // 🚀 The icon is now dynamic based on the tool being used!
                    child: Icon(activeIcon, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 🚀 Simulated Loading Progress Bar
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 0.96),
                duration: const Duration(seconds: 6),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: primaryColor.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(value * 100).toInt()}%',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<CompressionLevel?> _showCompressionDialog(
    BuildContext context,
  ) {
    final primaryColor = Theme.of(context).primaryColor;

    return showModalBottomSheet<CompressionLevel>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      // Allows the sheet to size perfectly
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🚀 Modern Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Header
              const Text(
                'Compress Document',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose how much you want to reduce the file size.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // 🗂️ Option Cards
              _buildCompressionCard(
                context: sheetContext,
                title: 'Low Compression',
                subtitle: 'High quality, minor file size reduction',
                icon: Icons.hd_rounded,
                iconColor: Colors.blue.shade600,
                level: CompressionLevel.low,
              ),
              const SizedBox(height: 12),
              _buildCompressionCard(
                context: sheetContext,
                title: 'Medium Compression',
                subtitle: 'Perfect balance of quality and size',
                icon: Icons.balance_rounded,
                iconColor: Colors.green.shade600,
                level: CompressionLevel.medium,
                isRecommended: true,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 12),
              _buildCompressionCard(
                context: sheetContext,
                title: 'Extreme Compression',
                subtitle: 'Noticeable quality loss, smallest size',
                icon: Icons.compress_rounded,
                iconColor: Colors.orange.shade700,
                level: CompressionLevel.high,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 Helper method to build those sleek, modern option cards
  static Widget _buildCompressionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required CompressionLevel level,
    bool isRecommended = false,
    Color? primaryColor,
  }) {
    return Material(
      color: isRecommended
          ? primaryColor?.withOpacity(0.04)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pop(context, level);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRecommended
                  ? (primaryColor ?? iconColor)
                  : AppColors.border,
              width: isRecommended ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Tinted Icon Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),

              // Text Content
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // 🚀 Wrap the title in Flexible so it shrinks gracefully!
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
