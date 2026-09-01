import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../../../core/constants/app_colors.dart';
import '../../../services/pdf_engine_service.dart';
import '../feature/pdf/views/pdf_result_screen.dart';

class SplitRangeScreen extends StatefulWidget {
  final File pdfFile;
  final bool isJpgExport;

  const SplitRangeScreen({
    super.key,
    required this.pdfFile,
    this.isJpgExport = false,
  });

  @override
  State<SplitRangeScreen> createState() => _SplitRangeScreenState();
}

class _SplitRangeScreenState extends State<SplitRangeScreen> {
  int _totalPages = 1;
  bool _isLoading = true;

  // Range State
  int _fromPage = 1;
  int _toPage = 1;
  final TextEditingController _customRangeController = TextEditingController();
  bool _useCustomString = false;
  bool _mergeIntoSingleFile = true;

  @override
  void initState() {
    super.initState();
    _loadPdfInfo();
  }

  @override
  void dispose() {
    _customRangeController.dispose();
    super.dispose();
  }

  Future<void> _loadPdfInfo() async {
    try {
      final doc = await pdfx.PdfDocument.openFile(widget.pdfFile.path);
      if (mounted) {
        setState(() {
          _totalPages = doc.pagesCount;
          _toPage = _totalPages;
          _customRangeController.text = '1-$_totalPages';
          _isLoading = false;
        });
      }
      await doc.close();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<int> _parsePageIndices() {
    final Set<int> pageIndices = {};

    if (_useCustomString) {
      final text = _customRangeController.text.trim();
      final parts = text.split(',');

      for (var part in parts) {
        part = part.trim();
        if (part.contains('-') && !part.startsWith('-')) {
          final range = part.split('-');
          if (range.length == 2) {
            final start = int.tryParse(range[0].trim());
            final end = int.tryParse(range[1].trim());
            if (start != null && end != null) {
              final min = start < end ? start : end;
              final max = start < end ? end : start;
              for (int i = min; i <= max; i++) {
                if (i >= 1 && i <= _totalPages) {
                  pageIndices.add(i - 1);
                }
              }
            }
          }
        } else {
          final pageNum = int.tryParse(part);
          if (pageNum != null) {
            final resolvedPage = pageNum < 0
                ? _totalPages + pageNum + 1
                : pageNum;
            if (resolvedPage >= 1 && resolvedPage <= _totalPages) {
              pageIndices.add(resolvedPage - 1);
            }
          }
        }
      }
    } else {
      final start = _fromPage < _toPage ? _fromPage : _toPage;
      final end = _fromPage < _toPage ? _toPage : _fromPage;
      for (int i = start; i <= end; i++) {
        pageIndices.add(i - 1);
      }
    }

    final sortedList = pageIndices.toList()..sort();
    return sortedList;
  }

  Future<void> _processTask() async {
    final selectedIndices = _parsePageIndices();

    if (selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a valid page range.')),
      );
      return;
    }

    HapticFeedback.heavyImpact();
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
                Text(
                  widget.isJpgExport
                      ? 'Extracting JPG images...'
                      : 'Extracting PDF pages...',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final List<File> resultFiles = [];

      if (widget.isJpgExport) {
        // Convert 0-based indices [0, 1, 4] -> 1-based page numbers [1, 2, 5]
        final pageNumbers = selectedIndices.map((i) => i + 1).toList();

        final images = await PdfEngineService.pdfToJpg(
          widget.pdfFile,
          selectedPages: pageNumbers, // 👈 Must pass pageNumbers here
        );
        resultFiles.addAll(images);
      } else {
        // Split PDF processing
        if (_mergeIntoSingleFile) {
          final extractedFile = await PdfEngineService.extractPageRange(
            widget.pdfFile,
            selectedIndices,
          );
          resultFiles.add(extractedFile);
        } else {
          for (final index in selectedIndices) {
            final singleFile = await PdfEngineService.extractPageRange(
              widget.pdfFile,
              [index],
            );
            resultFiles.add(singleFile);
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PdfResultScreen(
            resultFiles: resultFiles,
            title: widget.isJpgExport
                ? 'Exported Images (${resultFiles.length})'
                : (_mergeIntoSingleFile
                      ? 'Extracted Range'
                      : 'Split Pages (${resultFiles.length})'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isJpgExport ? 'Convert to JPG' : 'Split PDF',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total pages available: $_totalPages',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Mode Selector
                          Container(
                            height: 50,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9ECEF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildSegmentButton(
                                    label: 'Page Range',
                                    isSelected: !_useCustomString,
                                    primaryColor: primaryColor,
                                    onTap: () => setState(
                                      () => _useCustomString = false,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _buildSegmentButton(
                                    label: 'Custom Expression',
                                    isSelected: _useCustomString,
                                    primaryColor: primaryColor,
                                    onTap: () =>
                                        setState(() => _useCustomString = true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildQuickPresets(primaryColor),
                          const SizedBox(height: 16),

                          // Range Configuration Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: !_useCustomString
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: _buildPageStepper(
                                          label: 'From Page',
                                          value: _fromPage,
                                          onChanged: (val) {
                                            if (val >= 1 && val <= _toPage) {
                                              setState(() => _fromPage = val);
                                            }
                                          },
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          left: 6,
                                          right: 6,
                                          bottom: 14,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_rounded,
                                          color: AppColors.textSecondary,
                                          size: 18,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildPageStepper(
                                          label: 'To Page',
                                          value: _toPage,
                                          onChanged: (val) {
                                            if (val >= _fromPage &&
                                                val <= _totalPages) {
                                              setState(() => _toPage = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: _customRangeController,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Enter Page Selection',
                                          labelStyle: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          hintText:
                                              'e.g. 1, 3, 5-8, $_totalPages',
                                          hintStyle: TextStyle(
                                            color: AppColors.textSecondary
                                                .withOpacity(0.6),
                                            fontWeight: FontWeight.w400,
                                            fontSize: 14,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.format_list_numbered_rounded,
                                            color: primaryColor,
                                            size: 20,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFF8F9FA),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F9FA),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons
                                                      .lightbulb_outline_rounded,
                                                  size: 16,
                                                  color: primaryColor,
                                                ),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'How to format your selection:',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            _buildGuideItem(
                                              symbol: 'Comma ( , ) ',
                                              example: '1, 4, 9 ',
                                              description:
                                                  'Pick separate, individual pages',
                                              primaryColor: primaryColor,
                                            ),
                                            const SizedBox(height: 4),
                                            _buildGuideItem(
                                              symbol: 'Dash ( - ) ',
                                              example: '1-3, 7-10 ',
                                              description:
                                                  'Extract a continuous range of pages',
                                              primaryColor: primaryColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 20),

                          // Merge Toggle (Only shown for Split PDF mode)
                          if (!widget.isJpgExport)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: SwitchListTile(
                                title: const Text(
                                  'Merge into 1 PDF',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Text(
                                  _mergeIntoSingleFile
                                      ? 'Outputs a single document with all extracted pages'
                                      : 'Outputs each page as a separate PDF file',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                value: _mergeIntoSingleFile,
                                activeColor: primaryColor,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) =>
                                    setState(() => _mergeIntoSingleFile = val),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Action Button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _processTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          widget.isJpgExport
                              ? 'Export to JPG'
                              : 'Split Document',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

  Widget _buildQuickPresets(Color primaryColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPresetChip(
            label: 'All Pages',
            primaryColor: primaryColor,
            onTap: () {
              setState(() {
                _useCustomString = false;
                _fromPage = 1;
                _toPage = _totalPages;
              });
            },
          ),
          const SizedBox(width: 8),
          _buildPresetChip(
            label: 'First & Last Page',
            primaryColor: primaryColor,
            onTap: () {
              setState(() {
                _useCustomString = true;
                _customRangeController.text = '1, $_totalPages';
              });
            },
          ),
          const SizedBox(width: 8),
          _buildPresetChip(
            label: 'First 3 & Last 3',
            primaryColor: primaryColor,
            onTap: () {
              setState(() {
                _useCustomString = true;
                if (_totalPages > 6) {
                  _customRangeController.text =
                      '1-3, ${_totalPages - 2}-$_totalPages';
                } else {
                  _customRangeController.text = '1-$_totalPages';
                }
              });
            },
          ),
          const SizedBox(width: 8),
          _buildPresetChip(
            label: 'All Except Last',
            primaryColor: primaryColor,
            onTap: () {
              setState(() {
                _useCustomString = true;
                _customRangeController.text =
                    '1-${_totalPages > 1 ? _totalPages - 1 : 1}';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      backgroundColor: primaryColor.withOpacity(0.08),
      side: BorderSide(color: primaryColor.withOpacity(0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  Widget _buildGuideItem({
    required String symbol,
    required String example,
    required String description,
    required Color primaryColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• $symbol: ',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              children: [
                TextSpan(text: '$description (e.g., '),
                TextSpan(
                  text: example,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const TextSpan(text: ')'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? primaryColor : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageStepper({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(11),
                  ),
                  onTap: () => onChanged(value - 1),
                  child: const SizedBox(
                    width: 38,
                    height: double.infinity,
                    child: Icon(
                      Icons.remove_rounded,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(11),
                  ),
                  onTap: () => onChanged(value + 1),
                  child: const SizedBox(
                    width: 38,
                    height: double.infinity,
                    child: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
