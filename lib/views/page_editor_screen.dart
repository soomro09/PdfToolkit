import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import '../core/constants/app_colors.dart';
import '../feature/pdf/views/pdf_result_screen.dart';
import '../services/pdf_engine_service.dart';

class PageItem {
  final int originalIndex;
  int rotationAngle;
  Uint8List? thumbnailBytes;

  PageItem({
    required this.originalIndex,
    this.rotationAngle = 0,
    this.thumbnailBytes,
  });
}

class PageEditorScreen extends StatefulWidget {
  final File pdfFile;

  const PageEditorScreen({
    super.key,
    required this.pdfFile,
  });

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  final List<PageItem> _pages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    PdfDocument? doc;
    try {
      final bytes = await widget.pdfFile.readAsBytes();
      doc = await PdfDocument.openData(bytes);

      for (int i = 1; i <= doc.pagesCount; i++) {
        final page = await doc.getPage(i);

        const double targetWidth = 220.0;
        final double scale = targetWidth / (page.width > 0 ? page.width : 595.0);
        final double targetHeight = (page.height > 0 ? page.height : 842.0) * scale;

        final pageImage = await page.render(
          width: targetWidth,
          height: targetHeight,
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );

        await page.close();

        if (mounted) {
          setState(() {
            _pages.add(PageItem(
              originalIndex: i - 1,
              thumbnailBytes: pageImage?.bytes,
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      await doc?.close();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _rotatePage(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _pages[index].rotationAngle = (_pages[index].rotationAngle + 90) % 360;
    });
  }

  void _deletePage(int index) {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document must contain at least 1 page.')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _pages.removeAt(index);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    HapticFeedback.selectionClick();
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
    });
  }

  Future<void> _saveOrganizedPdf() async {
    HapticFeedback.heavyImpact();

    // 1. Gather the new page order and rotations
    final exportData = _pages.map((p) => {
      'index': p.originalIndex,
      'rotation': p.rotationAngle,
    }).toList();

    // 2. Show the loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primaryRed),
                const SizedBox(width: 20),
                const Text(
                  "Rebuilding PDF document...",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 3. Process the PDF in the background
      final organizedFile = await PdfEngineService.organizePdf(
        widget.pdfFile,
        exportData,
      );

      if (!mounted) return;

      // 4. Close the loader
      Navigator.of(context, rootNavigator: true).pop();

      // 5. Navigate to the Result Screen! 🎉
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PdfResultScreen(
            resultFiles: [organizedFile],
            title: 'Organized Document',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to organize PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8), // Sleek modern off-white
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F6F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Organize Pages',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      floatingActionButton: _pages.isEmpty
          ? null
          : FloatingActionButton.extended(
        onPressed: _saveOrganizedPdf,
        backgroundColor: AppColors.primaryRed,
        elevation: 6,
        splashColor: AppColors.primaryRed.withOpacity(0.4),
        icon: const Icon(Icons.check_rounded, color: Colors.white),
        label: const Text(
          'Save PDF',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _isLoading && _pages.isEmpty
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
          : SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text(
                      'Hold & drag to reorder',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _pages.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.7,
                ),
                itemBuilder: (context, index) {
                  final page = _pages[index];

                  return DragTarget<int>(
                    onAcceptWithDetails: (details) => _onReorder(details.data, index),
                    builder: (context, candidateData, rejectedData) {
                      return LongPressDraggable<int>(
                        data: index,
                        feedback: Material(
                          color: Colors.transparent,
                          elevation: 0,
                          child: SizedBox(
                            width: (MediaQuery.of(context).size.width - 64) / 3,
                            height: ((MediaQuery.of(context).size.width - 64) / 3) / 0.7,
                            child: Transform.scale(
                              scale: 1.05,
                              child: _buildThumbnailCard(page, index, isDragging: true),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.2,
                          child: _buildThumbnailCard(page, index),
                        ),
                        child: _buildThumbnailCard(page, index),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailCard(PageItem page, int index, {bool isDragging = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDragging ? AppColors.primaryRed.withOpacity(0.2) : Colors.black.withOpacity(0.06),
            blurRadius: isDragging ? 20 : 12,
            spreadRadius: isDragging ? 2 : 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Rendered PDF Page
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30.0, top: 12, left: 12, right: 12),
                child: RotatedBox(
                  quarterTurns: page.rotationAngle ~/ 90,
                  child: page.thumbnailBytes != null
                      ? Image.memory(
                    page.thumbnailBytes!,
                    fit: BoxFit.contain,
                  )
                      : Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Sleek Page Number Badge
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          // Floating Action Pill (Rotate & Delete)
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA).withOpacity(0.95), // Glassy white pill
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                      onTap: () => _rotatePage(index),
                      child: const Icon(
                        Icons.rotate_right_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(width: 1, height: 16, color: Colors.black12),
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                      onTap: () => _deletePage(index),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.error, // Red delete icon
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}