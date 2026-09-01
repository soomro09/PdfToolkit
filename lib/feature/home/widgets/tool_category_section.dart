import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/pdf_tool_type.dart';
import '../../../views/widgets/action_tool_card.dart';
import '../controllers/home_controller.dart';

class ToolCategorySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<PdfToolType> tools;

  const ToolCategorySection({
    super.key,
    required this.title,
    required this.icon,
    required this.tools,
  });

  @override
  Widget build(BuildContext context) {
    // 🚀 Ask the Theme for the active color dynamically!
    final activeColor = Theme.of(context).primaryColor;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      sliver: SliverMainAxisGroup(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  // 🎨 Now it uses the active theme color!
                  Icon(icon, size: 16, color: activeColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Grid
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio:
                  2.15, // 🚀 The magic number for sleek, modern proportions!
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final tool = tools[index];
              return _buildAnimatedToolCard(context, tool, index);
            }, childCount: tools.length),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedToolCard(
    BuildContext context,
    PdfToolType type,
    int index,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index * 30)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: ActionToolCard(
        title: type.title,
        subtitle: _getProfessionalSubtitle(type),
        icon: _getStaticToolIcon(type),
        onTap: () {
          HapticFeedback.lightImpact();
          HomeScreenController.handleToolSelection(context, type);
        },
      ),
    );
  }

  String _getProfessionalSubtitle(PdfToolType tool) {
    switch (tool) {
      case PdfToolType.merge:
        return 'Combine files';
      case PdfToolType.split:
        return 'Extract pages';
      case PdfToolType.organizePdf:
        return 'Rearrange pages';
      case PdfToolType.compress:
        return 'Reduce size';
      case PdfToolType.scanner:
        return 'Scan with camera';
      case PdfToolType.textToPdf:
        return 'Compile text strings';
      case PdfToolType.pdfToText:
        return 'Extract readable text';
      case PdfToolType.pdfToJpg:
        return 'Export images';
      case PdfToolType.imagesToPdf:
        return 'From photo gallery';
      case PdfToolType.sign:
        return 'Add signature';
      case PdfToolType.protect:
        return 'AES encryption';
      case PdfToolType.unlockPdf:
        return 'Remove password';
      case PdfToolType.watermark:
        return 'Stamp custom text';
      case PdfToolType.editPdf:
        return 'Annotate & markup';
    }
  }

  IconData _getStaticToolIcon(PdfToolType tool) {
    switch (tool) {
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
    }
  }
}
