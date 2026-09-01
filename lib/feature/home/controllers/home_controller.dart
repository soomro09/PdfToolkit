import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_utility_app/feature/pdf/controllers/recent_file_controller.dart';
import 'package:pdf_utility_app/views/tool_selection_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/pdf_document_model.dart';
import '../../../models/pdf_tool_type.dart';
import '../../../services/pdf_engine_service.dart';
import '../../pdf/views/pdf_result_screen.dart';

class HomeScreenController {
  /// Handles the action when a tool card is tapped
  static Future<void> handleToolSelection(
    BuildContext context,
    PdfToolType toolType,
  ) async {
    if (toolType == PdfToolType.scanner) {
      await _handleScannerLaunch(context);
    } else {
      // Both TextToPdf and other tools navigate to ToolSelectionScreen
      _navigateToToolSelection(context, toolType);
    }
  }

  /// Handles opening a recent file and checking if it still exists
  static void openRecentFile(
    BuildContext context,
    WidgetRef ref,
    PdfDocumentModel fileModel,
  ) {
    final file = File(fileModel.path);

    if (!file.existsSync()) {
      ref.read(recentFilesProvider.notifier).removeFile(fileModel.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('File no longer exists on local device storage.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PdfResultScreen(resultFiles: [file], title: fileModel.name),
      ),
    );
  }

  /// Shows a text box dialog and converts text directly to PDF
  static Future<void> _handleTextToPdfInput(BuildContext context) async {
    final titleController = TextEditingController(text: 'My Document');
    final textController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.text_snippet_rounded, color: AppColors.primaryRed),
            const SizedBox(width: 8),
            const Text(
              'Create PDF from Text',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Document Title',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.primaryRed,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textController,
                  maxLines: 8,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Type or paste your text here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.primaryRed,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Generate PDF'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primaryRed),
                const SizedBox(width: 20),
                const Text(
                  "Compiling PDF...",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );

      final docTitle = titleController.text.trim().isEmpty
          ? 'Document'
          : titleController.text.trim();

      try {
        final pdfFile = await PdfEngineService.textToPdf(
          textController.text.trim(),
          title: docTitle,
        );

        if (!context.mounted) return;
        Navigator.pop(context); // Dismiss loading dialog

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PdfResultScreen(resultFiles: [pdfFile], title: docTitle),
          ),
        );
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Dismiss loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to compile PDF: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }

    titleController.dispose();
    textController.dispose();
  }

  /// 🚀 The magic fix! This now triggers ML Kit instead of ImagePicker
  static Future<void> _handleScannerLaunch(BuildContext context) async {
    try {
      final scannedFile = await PdfEngineService.startDocumentScan();

      if (scannedFile != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfResultScreen(
              resultFiles: [scannedFile],
              title: 'Scanned Document',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document scanner error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Smooth animated routing to the Tool Selection Screen
  static void _navigateToToolSelection(
    BuildContext context,
    PdfToolType toolType,
  ) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ToolSelectionScreen(toolType: toolType),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slide =
              Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return SlideTransition(
            position: slide,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }
}
