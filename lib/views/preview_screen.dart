import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants/app_colors.dart';
import 'widgets/custom_app_bar.dart';

class PreviewScreen extends StatefulWidget {
  final File pdfFile;
  final String title;

  const PreviewScreen({
    super.key,
    required this.pdfFile,
    this.title = 'Document Preview',
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late PdfControllerPinch _pdfController;
  int _totalPages = 0;
  int _currentPage = 1;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initPdfController();
  }

  Future<void> _initPdfController() async {
    try {
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.pdfFile.path),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading preview: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  void _shareDocument() async {
    HapticFeedback.lightImpact();
    final XFile file = XFile(widget.pdfFile.path);
    await Share.shareXFiles([
      file,
    ], text: 'Sharing PDF: ${widget.pdfFile.path.split('/').last}');
  }

  // Save PDF directly to local public Downloads 💾
  Future<void> _saveToDeviceStorage() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      Directory? targetDir;

      if (Platform.isAndroid) {
        targetDir = Directory('/storage/emulated/0/Download');
        if (!await targetDir.exists()) {
          targetDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        targetDir = await getApplicationDocumentsDirectory();
      }

      if (targetDir == null) {
        throw Exception('Could not access storage directory');
      }

      final originalName = widget.pdfFile.path.split('/').last;
      final cleanName = originalName.contains('.')
          ? originalName.substring(0, originalName.lastIndexOf('.'))
          : originalName;

      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = '${targetDir.path}/${cleanName}_$timeStamp.pdf';

      final File savedFile = await widget.pdfFile.copy(savedPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved to Downloads! 📁\n${savedFile.path.split('/').last}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: _shareDocument,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to save file: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: widget.title,
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.download_rounded,
              color: Colors.white,
              size: 26,
            ),
            onPressed: _isSaving ? null : _saveToDeviceStorage,
            tooltip: 'Save to Device',
          ),
          IconButton(
            icon: const Icon(
              Icons.share_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: _shareDocument,
            tooltip: 'Share Document',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: Column(
                children: [
                  // Document Render Area with Pinch-to-Zoom & Pan 📄
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: PdfViewPinch(
                          controller: _pdfController,
                          onDocumentLoaded: (document) {
                            setState(() {
                              _totalPages = document.pagesCount;
                            });
                          },
                          onPageChanged: (page) {
                            setState(() {
                              _currentPage = page;
                            });
                          },
                        ),
                      ),
                    ),
                  ),

                  // Page Control Bar 🧭
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    color: AppColors.surface,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          color: _currentPage > 1
                              ? primaryColor
                              : AppColors.textMuted,
                          onPressed: _currentPage > 1
                              ? () => _pdfController.previousPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                )
                              : null,
                        ),
                        Text(
                          'Page $_currentPage of $_totalPages',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          color: _currentPage < _totalPages
                              ? primaryColor
                              : AppColors.textMuted,
                          onPressed: _currentPage < _totalPages
                              ? () => _pdfController.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),

                  // Bottom Action Dock 🛠️
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Primary Save Button
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveToDeviceStorage,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.download_rounded, size: 22),
                          label: Text(
                            _isSaving
                                ? 'Saving to Device...'
                                : 'Save File to Downloads',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Secondary Share Button
                        OutlinedButton.icon(
                          onPressed: _shareDocument,
                          icon: const Icon(Icons.share_rounded, size: 20),
                          label: const Text(
                            'Share / Export via Apps',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor),
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
