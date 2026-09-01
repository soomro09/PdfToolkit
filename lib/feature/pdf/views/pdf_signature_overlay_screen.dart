import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/signature_placement_model.dart';

class PdfSignatureOverlayScreen extends StatefulWidget {
  final File pdfFile;
  final File signatureImage;

  const PdfSignatureOverlayScreen({
    super.key,
    required this.pdfFile,
    required this.signatureImage,
  });

  @override
  State<PdfSignatureOverlayScreen> createState() =>
      _PdfSignatureOverlayScreenState();
}

class _PdfSignatureOverlayScreenState extends State<PdfSignatureOverlayScreen> {
  PdfDocument? _pdfDocument;
  PdfPageImage? _currentPageImage;

  int _currentPageIndex = 0; // 0-based
  int _totalPages = 0;
  bool _isLoadingPage = true;

  double _nativePdfPageWidth = 1.0;
  double _nativePdfPageHeight = 1.0;

  Size _lastRenderedPageSize = Size.zero;
  Size _initialScaleSize = Size.zero;

  final List<SignaturePlacement> _placements = [];

  @override
  void initState() {
    super.initState();
    _loadPdfDocument();
  }

  Future<void> _loadPdfDocument() async {
    try {
      _pdfDocument = await PdfDocument.openFile(widget.pdfFile.path);
      _totalPages = _pdfDocument!.pagesCount;
      await _renderCurrentPage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load PDF: $e')));
      }
    }
  }

  Future<void> _renderCurrentPage() async {
    if (_pdfDocument == null) return;
    setState(() => _isLoadingPage = true);

    final page = await _pdfDocument!.getPage(_currentPageIndex + 1);

    _nativePdfPageWidth = page.width.toDouble();
    _nativePdfPageHeight = page.height.toDouble();

    final pageImage = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: PdfPageImageFormat.jpeg,
    );
    await page.close();

    if (mounted) {
      setState(() {
        _currentPageImage = pageImage;
        _isLoadingPage = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfDocument?.close();
    super.dispose();
  }

  Future<void> _addSignature() async {
    final bytes = await widget.signatureImage.readAsBytes();
    final image = await decodeImageFromList(bytes);

    final double aspectRatio = image.width / image.height;

    const double targetHeight = 50.0;
    final double targetWidth = targetHeight * aspectRatio;

    setState(() {
      _placements.add(
        SignaturePlacement(
          pageIndex: _currentPageIndex,
          position: const Offset(40, 40),
          size: Size(targetWidth, targetHeight),
          aspectRatio: aspectRatio,
        ),
      );
    });
  }

  void _confirmPlacement() {
    if (_placements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one signature 🖊️')),
      );
      return;
    }

    Navigator.pop(context, {
      'placements': _placements,
      'renderedPageSize': _lastRenderedPageSize,
    });
  }

  void _changePage(int delta) {
    final newIndex = _currentPageIndex + delta;
    if (newIndex >= 0 && newIndex < _totalPages) {
      setState(() {
        _currentPageIndex = newIndex;
      });
      _renderCurrentPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Place Signature (${_currentPageIndex + 1}/$_totalPages)'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.check_rounded,
              color: Colors.black,
              size: 28,
            ),
            onPressed: (_currentPageImage != null && !_isLoadingPage)
                ? _confirmPlacement
                : null,
            tooltip: 'Done',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: AppColors.accentRedLight,
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    color: AppColors.primaryRed,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Drag to move • Pinch or drag corner to resize',
                      style: TextStyle(
                        color: AppColors.primaryRedDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isLoadingPage || _currentPageImage == null
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryRed,
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final containerSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            final double pageAspect =
                                _nativePdfPageWidth / _nativePdfPageHeight;
                            final pageRenderSize = _fitPageSize(
                              containerSize,
                              pageAspect,
                            );

                            _lastRenderedPageSize = pageRenderSize;

                            final currentPagePlacements = _placements
                                .where((p) => p.pageIndex == _currentPageIndex)
                                .toList();

                            return Center(
                              child: SizedBox(
                                width: pageRenderSize.width,
                                height: pageRenderSize.height,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: Image.memory(
                                        _currentPageImage!.bytes,
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: currentPagePlacements.map((
                                          p,
                                        ) {
                                          return Positioned(
                                            left: p.position.dx,
                                            top: p.position.dy,
                                            child: GestureDetector(
                                              onScaleStart: (details) {
                                                _initialScaleSize = p.size;
                                              },
                                              onScaleUpdate: (details) {
                                                setState(() {
                                                  double newWidth =
                                                      _initialScaleSize.width *
                                                      details.scale;
                                                  newWidth = newWidth.clamp(
                                                    30.0,
                                                    pageRenderSize.width -
                                                        p.position.dx,
                                                  );
                                                  double newHeight =
                                                      newWidth / p.aspectRatio;
                                                  p.size = Size(
                                                    newWidth,
                                                    newHeight,
                                                  );

                                                  double newX =
                                                      p.position.dx +
                                                      details
                                                          .focalPointDelta
                                                          .dx;
                                                  double newY =
                                                      p.position.dy +
                                                      details
                                                          .focalPointDelta
                                                          .dy;

                                                  newX = newX.clamp(
                                                    0.0,
                                                    pageRenderSize.width -
                                                        p.size.width,
                                                  );
                                                  newY = newY.clamp(
                                                    0.0,
                                                    pageRenderSize.height -
                                                        p.size.height,
                                                  );

                                                  p.position = Offset(
                                                    newX,
                                                    newY,
                                                  );
                                                });
                                              },
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Container(
                                                    width: p.size.width,
                                                    height: p.size.height,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: AppColors
                                                            .primaryRed
                                                            .withOpacity(0.6),
                                                        width: 2,
                                                      ),
                                                      color: AppColors
                                                          .primaryRed
                                                          .withOpacity(0.05),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Image.file(
                                                      widget.signatureImage,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: -10,
                                                    right: -10,
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          _placements.remove(p);
                                                        });
                                                      },
                                                      child: const CircleAvatar(
                                                        radius: 12,
                                                        backgroundColor:
                                                            Colors.red,
                                                        child: Icon(
                                                          Icons.close,
                                                          size: 14,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: -10,
                                                    right: -10,
                                                    child: GestureDetector(
                                                      onPanUpdate: (details) {
                                                        setState(() {
                                                          double newWidth =
                                                              p.size.width +
                                                              details.delta.dx;
                                                          newWidth = newWidth
                                                              .clamp(
                                                                30.0,
                                                                pageRenderSize
                                                                        .width -
                                                                    p
                                                                        .position
                                                                        .dx,
                                                              );
                                                          double newHeight =
                                                              newWidth /
                                                              p.aspectRatio;
                                                          p.size = Size(
                                                            newWidth,
                                                            newHeight,
                                                          );
                                                        });
                                                      },
                                                      child: CircleAvatar(
                                                        radius: 12,
                                                        backgroundColor:
                                                            AppColors
                                                                .primaryRed,
                                                        child: const Icon(
                                                          Icons
                                                              .open_in_full_rounded,
                                                          size: 12,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 32),
                    onPressed: _currentPageIndex > 0
                        ? () => _changePage(-1)
                        : null,
                  ),
                  Text(
                    'Page ${_currentPageIndex + 1} of $_totalPages',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 32),
                    onPressed: _currentPageIndex < _totalPages - 1
                        ? () => _changePage(1)
                        : null,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _isLoadingPage ? null : _addSignature,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Signature to Current Page'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Size _fitPageSize(Size containerSize, double pageAspect) {
    final containerAspect = containerSize.width / containerSize.height;
    if (containerAspect > pageAspect) {
      return Size(containerSize.height * pageAspect, containerSize.height);
    } else {
      return Size(containerSize.width, containerSize.width / pageAspect);
    }
  }
}
