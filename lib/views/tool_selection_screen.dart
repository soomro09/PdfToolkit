import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../feature/pdf/controllers/tool_selection_controller.dart';
import '../models/pdf_tool_type.dart';
import 'widgets/custom_app_bar.dart';

class ToolSelectionScreen extends ConsumerStatefulWidget {
  final PdfToolType toolType;

  const ToolSelectionScreen({super.key, required this.toolType});

  @override
  ConsumerState<ToolSelectionScreen> createState() =>
      _ToolSelectionScreenState();
}

class _ToolSelectionScreenState extends ConsumerState<ToolSelectionScreen> {
  final List<File> _selectedFiles = [];
  bool _isPicking = false;

  late final TextEditingController _titleController;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'My Document');
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    setState(() => _isPicking = true);
    HapticFeedback.selectionClick();
    try {
      final pickedFiles = await ToolSelectionController.pickFiles(
        widget.toolType,
        _selectedFiles,
      );
      if (pickedFiles.isNotEmpty) {
        setState(() {
          if (widget.toolType.allowMultiple) {
            _selectedFiles.addAll(pickedFiles);
          } else {
            _selectedFiles.clear();
            _selectedFiles.addAll(pickedFiles);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File selection error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removeFile(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedFiles.removeAt(index));
  }

  void _onReorder(int oldIndex, int newIndex) {
    HapticFeedback.selectionClick();
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final file = _selectedFiles.removeAt(oldIndex);
      _selectedFiles.insert(newIndex, file);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTextMode = widget.toolType == PdfToolType.textToPdf;
    final canProceed = isTextMode
        ? _textController.text.trim().isNotEmpty
        : _selectedFiles.length >= widget.toolType.minFiles;

    // 🚀 Grab active theme colors
    final primaryColor = Theme.of(context).primaryColor;
    final primaryDark = HSLColor.fromColor(primaryColor)
        .withLightness(
          (HSLColor.fromColor(primaryColor).lightness - 0.15).clamp(0.0, 1.0),
        )
        .toColor();
    final primaryLight = primaryColor.withOpacity(0.12);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: widget.toolType.title, showBackButton: true),
      body: SafeArea(
        child: Column(
          children: [
            // ℹ️ Info Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryLight, // 👈 Dynamic Color
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: primaryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.toolType.description,
                      style: TextStyle(
                        color: primaryDark, // 👈 Dynamic Color
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: isTextMode
                  ? _buildTextInputView(primaryColor)
                  : (_selectedFiles.isEmpty
                        ? _buildEmptyState(primaryColor)
                        : _buildSelectedFilesList(primaryColor, primaryLight)),
            ),

            // 🕹️ Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  if (!isTextMode &&
                      widget.toolType.allowMultiple &&
                      _selectedFiles.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: _isPicking ? null : _pickFiles,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add More'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        // 👈 Dynamic Color
                        side: BorderSide(color: primaryColor),
                        // 👈 Dynamic Color
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canProceed
                          ? () => ToolSelectionController.proceedToTask(
                              context: context,
                              ref: ref,
                              toolType: widget.toolType,
                              selectedFiles: _selectedFiles,
                              textContent: _textController.text.trim(),
                              documentTitle:
                                  _titleController.text.trim().isEmpty
                                  ? 'Document'
                                  : _titleController.text.trim(),
                            )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        // 👈 Dynamic Color
                        disabledBackgroundColor: AppColors.border,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        isTextMode
                            ? 'Generate PDF'
                            : 'Continue (${_selectedFiles.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
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

  Widget _buildTextInputView(Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Document Title',
              filled: true,
              fillColor: AppColors.surface,
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _textController,
            maxLines: 12,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Type or paste your text here...',
              filled: true,
              fillColor: AppColors.surface,
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                widget.toolType == PdfToolType.imagesToPdf
                    ? Icons.add_photo_alternate_outlined
                    : Icons.note_add_outlined,
                color: primaryColor, // 👈 Dynamic Color
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Files Selected',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap below to browse and add files from your device storage.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isPicking ? null : _pickFiles,
              icon: _isPicking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.folder_open_rounded, size: 20),
              label: Text(_isPicking ? 'Opening Storage...' : 'Browse Storage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                // 👈 Dynamic Color
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFilesList(Color primaryColor, Color primaryLight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.toolType.allowMultiple)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Drag handle to reorder processing sequence',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _selectedFiles.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              final name = file.path.split('/').last;
              final size = file.existsSync()
                  ? ToolSelectionController.formatBytes(file.lengthSync())
                  : 'Unknown';

              return Container(
                key: ValueKey(file.path),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 38,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    // 👈 Dynamic Color
                    child: Icon(
                      widget.toolType == PdfToolType.imagesToPdf
                          ? Icons.image_rounded
                          : Icons.picture_as_pdf_rounded,
                      color: primaryColor, // 👈 Dynamic Color
                      size: 22,
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    size,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.textMuted,
                        onPressed: () => _removeFile(index),
                        tooltip: 'Remove',
                      ),
                      if (widget.toolType.allowMultiple)
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(
                            Icons.drag_handle_rounded,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
