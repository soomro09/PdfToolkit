import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/constants/app_colors.dart';
import '../feature/pdf/views/pdf_result_screen.dart';
import '../models/pdf_annotation_tool.dart';

class PdfEditorScreen extends StatefulWidget {
  final File pdfFile;

  const PdfEditorScreen({super.key, required this.pdfFile});

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  AppPdfFont _currentFont = AppPdfFont.helvetica;
  double _pdfAspectRatio = 1 / 1.414;
  pdfx.PdfController? _pdfController;
  int _pageCount = 0;
  int _currentPage = 0;
  bool _isLoading = true;
  String? _errorMessage;

  final List<EditableTextOverlay> _annotations = [];
  String? _selectedOverlayId;

  // Active styles for new annotations
  Color _currentColor = Colors.black;
  double _currentFontSize = 18.0;
  bool _currentBold = true;
  bool _currentItalic = false;
  bool _currentUnderline = false;

  Size _renderedPageSize = Size.zero;

  // Persistent drawing palette
  static const List<Color> _presetColors = [
    Colors.black,
    Color(0xFFE53935), // Crimson Red
    Color(0xFF1976D2), // Royal Blue
    Color(0xFF388E3C), // Forest Green
    Color(0xFFF57C00), // Amber Orange
    Color(0xFF7B1FA2), // Purple
  ];

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      final docFuture = pdfx.PdfDocument.openFile(widget.pdfFile.path);
      final doc = await docFuture;

      final page = await doc.getPage(1);
      final aspectRatio = page.width / page.height;
      await page.close();

      if (!mounted) return;

      _pdfController = pdfx.PdfController(document: docFuture, initialPage: 1);

      setState(() {
        _pageCount = doc.pagesCount;
        _pdfAspectRatio = aspectRatio;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load document: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _addTextOverlay({String? predefinedText}) async {
    HapticFeedback.lightImpact();
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final double defaultX = _renderedPageSize.width > 0
        ? _renderedPageSize.width / 4
        : 40.0;
    final double defaultY = _renderedPageSize.height > 0
        ? _renderedPageSize.height / 3
        : 80.0;

    final newOverlay = EditableTextOverlay(
      id: newId,
      pageIndex: _currentPage,
      text: predefinedText ?? '',
      position: Offset(defaultX, defaultY),
      fontSize: _currentFontSize,
      color: _currentColor,
      isBold: _currentBold,
      isItalic: _currentItalic,
      isUnderline: _currentUnderline,
      fontFamily: _currentFont,
    );

    setState(() {
      _annotations.add(newOverlay);
      _selectedOverlayId = newId;
    });

    if (predefinedText == null) {
      await _editTextDialog(newOverlay, isNew: true);
    }
  }

  void _addQuickDate() {
    final now = DateTime.now();
    final dateStr =
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
    _addTextOverlay(predefinedText: dateStr);
  }

  Future<void> _editTextDialog(
    EditableTextOverlay overlay, {
    bool isNew = false,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _EditTextDialog(initialText: overlay.text),
    );

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        overlay.text = result.trim();
      });
    } else if (isNew) {
      setState(() {
        _annotations.removeWhere((a) => a.id == overlay.id);
        _selectedOverlayId = null;
      });
    }
  }

  Future<void> _openColorPicker() async {
    Color pickerColor = _currentColor;
    final primaryColor = Theme.of(context).primaryColor;

    final result = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Pick a Color',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hsvWithHue,
            labelTypes: const [],
            pickerAreaBorderRadius: BorderRadius.circular(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, pickerColor),
            child: const Text(
              'Select',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _currentColor = result;
        final selectedOverlay = _annotations
            .cast<EditableTextOverlay?>()
            .firstWhere((a) => a?.id == _selectedOverlayId, orElse: () => null);
        if (selectedOverlay != null) {
          selectedOverlay.color = result;
        }
      });
    }
  }

  Future<void> _saveAndExportPdf() async {
    if (_annotations.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No annotations added.')));
      return;
    }

    final primaryColor = Theme.of(context).primaryColor;

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
                CircularProgressIndicator(color: primaryColor),
                const SizedBox(width: 20),
                const Text(
                  'Baking annotations into PDF...',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final inputBytes = await widget.pdfFile.readAsBytes();
      final doc = PdfDocument(inputBytes: inputBytes);

      for (final annotation in _annotations) {
        if (annotation.pageIndex < doc.pages.count) {
          final page = doc.pages[annotation.pageIndex];

          final double targetWidth = _renderedPageSize.width > 0
              ? _renderedPageSize.width
              : page.size.width;
          final double targetHeight = _renderedPageSize.height > 0
              ? _renderedPageSize.height
              : page.size.height;

          // Auto-detect rotation mismatches
          final double uiAspect = targetWidth / targetHeight;
          final double pdfAspect = page.size.width / page.size.height;

          double actualPdfWidth = page.size.width;
          double actualPdfHeight = page.size.height;

          // If orientation is flipped, swap dimensions
          if ((uiAspect > 1 && pdfAspect < 1) ||
              (uiAspect < 1 && pdfAspect > 1)) {
            actualPdfWidth = page.size.height;
            actualPdfHeight = page.size.width;
          }

          final double scaleX = actualPdfWidth / targetWidth;
          final double scaleY = actualPdfHeight / targetHeight;

          final double scaledFontSize = annotation.fontSize * scaleX;

          final double exactUiX = annotation.position.dx + 20.0;
          final double exactUiY = annotation.position.dy + 20.0;

          final double pdfX = exactUiX * scaleX;
          final double pdfY = exactUiY * scaleY;

          // 🚀 THE FIX: Micro-adjustment. Dialed back from 0.07 to 0.02.
          final double pullRight = (annotation.fontSize * 0.03) * scaleX;
          final double pullUp = (annotation.fontSize * 0.01) * scaleY;

          List<PdfFontStyle> activeStyles = [];
          if (annotation.isBold) activeStyles.add(PdfFontStyle.bold);
          if (annotation.isItalic) activeStyles.add(PdfFontStyle.italic);
          if (annotation.isUnderline) activeStyles.add(PdfFontStyle.underline);

          PdfFontFamily targetFontFamily;
          switch (annotation.fontFamily) {
            case AppPdfFont.helvetica:
              targetFontFamily = PdfFontFamily.helvetica;
              break;
            case AppPdfFont.timesRoman:
              targetFontFamily = PdfFontFamily.timesRoman;
              break;
            case AppPdfFont.courier:
              targetFontFamily = PdfFontFamily.courier;
              break;
          }

          final font = PdfStandardFont(
            targetFontFamily,
            scaledFontSize,
            multiStyle: activeStyles.isNotEmpty
                ? activeStyles
                : [PdfFontStyle.regular],
          );

          final format = PdfStringFormat(
            alignment: PdfTextAlignment.left,
            lineAlignment: PdfVerticalAlignment.top,
          );

          final brush = PdfSolidBrush(
            PdfColor(
              annotation.color.red,
              annotation.color.green,
              annotation.color.blue,
            ),
          );

          page.graphics.drawString(
            annotation.text,
            font,
            brush: brush,
            format: format,
            bounds: Rect.fromLTWH(
              pdfX + pullRight,
              pdfY - pullUp,
              (actualPdfWidth - pdfX).clamp(0.0, double.infinity),
              (actualPdfHeight - pdfY).clamp(0.0, double.infinity),
            ),
          );
        }
      }

      final outputBytes = await doc.save();
      doc.dispose();

      final tempDir = await getTemporaryDirectory();
      final editedFile = File(
        '${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await editedFile.writeAsBytes(outputBytes, flush: true);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfResultScreen(
            resultFiles: [editedFile],
            title: 'Annotated PDF',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildFormatToggle({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? primaryColor : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? primaryColor : AppColors.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    // The visual color for the dashed box and nodes
    final Color handleColor = primaryColor.withOpacity(0.7);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_errorMessage != null || _pdfController == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _errorMessage ?? 'Failed to initialize PDF.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      );
    }

    final currentPageAnnotations = _annotations
        .where((a) => a.pageIndex == _currentPage)
        .toList();
    final selectedOverlay = _annotations
        .cast<EditableTextOverlay?>()
        .firstWhere((a) => a?.id == _selectedOverlayId, orElse: () => null);

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Page ${_currentPage + 1} of $_pageCount',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveAndExportPdf,
            icon: Icon(Icons.check_rounded, color: primaryColor),
            label: Text(
              'Save',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // 🚀 Global Hit-Test Deselection
      body: GestureDetector(
        onTap: () {
          if (_selectedOverlayId != null) {
            setState(() => _selectedOverlayId = null);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: AspectRatio(
                    aspectRatio: _pdfAspectRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _renderedPageSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: pdfx.PdfView(
                                    key: const ValueKey('pdf_viewer_locked'),
                                    controller: _pdfController!,
                                    onPageChanged: (page) {
                                      setState(() {
                                        _currentPage = page - 1;
                                        _selectedOverlayId = null;
                                      });
                                    },
                                  ),
                                ),
                              ),

                              // Render Professional Overlays
                              ...currentPageAnnotations.map((overlay) {
                                final isSelected =
                                    overlay.id == _selectedOverlayId;

                                final textWidget = Text(
                                  overlay.text,
                                  style: overlay.fontFamily.toTextStyle(
                                    fontSize: overlay.fontSize,
                                    color: overlay.color,
                                    isBold: overlay.isBold,
                                    isItalic: overlay.isItalic,
                                    isUnderline: overlay.isUnderline,
                                  ),
                                );

                                if (!isSelected) {
                                  return Positioned(
                                    left: overlay.position.dx,
                                    top: overlay.position.dy,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedOverlayId = overlay.id;
                                          _currentColor = overlay.color;
                                          _currentFontSize = overlay.fontSize;
                                          _currentBold = overlay.isBold;
                                          _currentItalic = overlay.isItalic;
                                          _currentUnderline =
                                              overlay.isUnderline;
                                          _currentFont = overlay.fontFamily;
                                        });
                                      },
                                      onPanUpdate: (details) {
                                        setState(() {
                                          _selectedOverlayId = overlay.id;
                                          final maxX =
                                              (_renderedPageSize.width - 60)
                                                  .clamp(0.0, double.infinity);
                                          final maxY =
                                              (_renderedPageSize.height - 30)
                                                  .clamp(0.0, double.infinity);
                                          final newX =
                                              (overlay.position.dx +
                                                      details.delta.dx)
                                                  .clamp(0.0, maxX);
                                          final newY =
                                              (overlay.position.dy +
                                                      details.delta.dy)
                                                  .clamp(0.0, maxY);
                                          overlay.position = Offset(newX, newY);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        // Matched padding with selected state
                                        child: textWidget,
                                      ),
                                    ),
                                  );
                                }

                                // 🚀 Selected state matching image_fe3a1e.png perfectly
                                return Positioned(
                                  left: overlay.position.dx,
                                  top: overlay.position.dy,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Dashed Box and Draggable Area
                                      GestureDetector(
                                        onPanUpdate: (details) {
                                          setState(() {
                                            final maxX =
                                                (_renderedPageSize.width - 60)
                                                    .clamp(
                                                      0.0,
                                                      double.infinity,
                                                    );
                                            final maxY =
                                                (_renderedPageSize.height - 30)
                                                    .clamp(
                                                      0.0,
                                                      double.infinity,
                                                    );
                                            final newX =
                                                (overlay.position.dx +
                                                        details.delta.dx)
                                                    .clamp(0.0, maxX);
                                            final newY =
                                                (overlay.position.dy +
                                                        details.delta.dy)
                                                    .clamp(0.0, maxY);
                                            overlay.position = Offset(
                                              newX,
                                              newY,
                                            );
                                          });
                                        },
                                        onDoubleTap: () =>
                                            _editTextDialog(overlay),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          // Space for handles to overhang
                                          child: CustomPaint(
                                            painter: DashedRectPainter(
                                              color: handleColor,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              color: Colors.transparent,
                                              // Ensures hit testing works on the whole box
                                              child: textWidget,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ❌ Delete Button (Top Right corner of dashed box)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _annotations.removeWhere(
                                                (a) => a.id == overlay.id,
                                              );
                                              _selectedOverlayId = null;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: handleColor,
                                              shape: BoxShape.circle,
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ↘️ Resize Anchor (Bottom Right corner of dashed box)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onPanUpdate: (details) {
                                            setState(() {
                                              final dx = details.delta.dx;
                                              final dy = details.delta.dy;
                                              final dominantDelta =
                                                  dx.abs() > dy.abs() ? dx : dy;
                                              overlay.fontSize =
                                                  (overlay.fontSize +
                                                          dominantDelta * 0.8)
                                                      .clamp(10.0, 100.0);
                                              _currentFontSize =
                                                  overlay.fontSize;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: handleColor,
                                              shape: BoxShape.circle,
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.open_in_full_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Toolbar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Font Family Segment Selector
                  Container(
                    height: 36,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9ECEF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: AppPdfFont.values.map((font) {
                        final isSelected =
                            (selectedOverlay?.fontFamily ?? _currentFont) ==
                            font;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _currentFont = font;
                                if (selectedOverlay != null) {
                                  selectedOverlay.fontFamily = font;
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  font.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? primaryColor
                                        : AppColors.textSecondary,
                                    fontFamily: font == AppPdfFont.timesRoman
                                        ? 'serif'
                                        : (font == AppPdfFont.courier
                                              ? 'monospace'
                                              : null),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Text Formatting Bar (Bold, Italic, Underline)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFormatToggle(
                        icon: Icons.format_bold_rounded,
                        isActive: selectedOverlay?.isBold ?? _currentBold,
                        onTap: () {
                          setState(() {
                            if (selectedOverlay != null) {
                              selectedOverlay.isBold = !selectedOverlay.isBold;
                              _currentBold = selectedOverlay.isBold;
                            } else {
                              _currentBold = !_currentBold;
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildFormatToggle(
                        icon: Icons.format_italic_rounded,
                        isActive: selectedOverlay?.isItalic ?? _currentItalic,
                        onTap: () {
                          setState(() {
                            if (selectedOverlay != null) {
                              selectedOverlay.isItalic =
                                  !selectedOverlay.isItalic;
                              _currentItalic = selectedOverlay.isItalic;
                            } else {
                              _currentItalic = !_currentItalic;
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildFormatToggle(
                        icon: Icons.format_underlined_rounded,
                        isActive:
                            selectedOverlay?.isUnderline ?? _currentUnderline,
                        onTap: () {
                          setState(() {
                            if (selectedOverlay != null) {
                              selectedOverlay.isUnderline =
                                  !selectedOverlay.isUnderline;
                              _currentUnderline = selectedOverlay.isUnderline;
                            } else {
                              _currentUnderline = !_currentUnderline;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Palette + Rainbow Custom Color Wheel Button
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _openColorPicker,
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const SweepGradient(
                                colors: [
                                  Colors.red,
                                  Colors.orange,
                                  Colors.yellow,
                                  Colors.green,
                                  Colors.blue,
                                  Colors.purple,
                                  Colors.red,
                                ],
                              ),
                              border: Border.all(
                                color: !_presetColors.contains(_currentColor)
                                    ? AppColors.textPrimary
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: !_presetColors.contains(_currentColor)
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : const Icon(
                                    Icons.colorize_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                          ),
                        ),

                        // Default Preset Colors
                        ..._presetColors.map((color) {
                          final isPicked = _currentColor == color;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentColor = color;
                                if (selectedOverlay != null) {
                                  selectedOverlay.color = color;
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isPicked
                                      ? AppColors.textPrimary
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: isPicked
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tool Action Buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _addTextOverlay(),
                          icon: const Icon(Icons.title_rounded, size: 18),
                          label: const Text('Text'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _addQuickDate,
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                          ),
                          label: const Text('Date'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _addTextOverlay(predefinedText: 'X'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Add X',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
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

class _EditTextDialog extends StatefulWidget {
  final String initialText;

  const _EditTextDialog({required this.initialText});

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Edit Text',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Enter text...',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// 🚀 Pure native custom painter for the perfect dashed bounding box
class DashedRectPainter extends CustomPainter {
  final Color color;

  DashedRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Calculate exactly how to break the lines into dashes
    PathMetrics pathMetrics = path.computeMetrics();
    Path dashPath = Path();

    for (PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + 6), // length of dash
          Offset.zero,
        );
        distance += 6 + 4; // dash length + spacing
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
