import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../views/widgets/custom_app_bar.dart';

class ExtractedTextViewScreen extends StatelessWidget {
  final String text;
  final String documentName;

  const ExtractedTextViewScreen({
    super.key,
    required this.text,
    required this.documentName,
  });

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Text copied to clipboard! 📋'),
        backgroundColor: AppColors.primaryRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareText() {
    HapticFeedback.lightImpact();
    Share.share(text, subject: 'Extracted text from $documentName');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Extracted Text',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top action pill bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      documentName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, color: AppColors.primaryRed),
                    tooltip: 'Copy all',
                    onPressed: () => _copyToClipboard(context),
                  ),
                  IconButton(
                    icon: Icon(Icons.share_rounded, color: AppColors.primaryRed),
                    tooltip: 'Share',
                    onPressed: _shareText,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Text Content Card
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: text.trim().isEmpty
                    ? Center(
                  child: Text(
                    'No readable text found in this PDF.\n(It might contain scanned raster images)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                )
                    : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: SelectableText(
                    text,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}