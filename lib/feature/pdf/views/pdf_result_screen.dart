import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/pdf_document_model.dart';
import '../controllers/recent_file_controller.dart';

class PdfResultScreen extends ConsumerStatefulWidget {
  final List<File> resultFiles;
  final String title;
  final File? originalFile;

  const PdfResultScreen({
    super.key,
    required this.resultFiles,
    required this.title,
    this.originalFile,
  });

  @override
  ConsumerState<PdfResultScreen> createState() => _PdfResultScreenState();
}

class _PdfResultScreenState extends ConsumerState<PdfResultScreen> {
  PdfControllerPinch? _pdfController;
  int _focusedIndex = 0;
  bool _isProtected = false;
  bool _isSaving = false;
  late String _currentCustomName;
  late bool _isImageResult;

  @override
  void initState() {
    super.initState();
    // 🚀 Detect if the result files are images instead of PDFs!
    _isImageResult =
        widget.resultFiles.isNotEmpty &&
        (widget.resultFiles.first.path.toLowerCase().endsWith('.jpg') ||
            widget.resultFiles.first.path.toLowerCase().endsWith('.jpeg') ||
            widget.resultFiles.first.path.toLowerCase().endsWith('.png'));

    // Clean initial title (strip extension if present)
    _currentCustomName = widget.title.endsWith('.pdf')
        ? widget.title.substring(0, widget.title.length - 4)
        : widget.title;

    _isProtected = widget.title.toLowerCase().contains('protect');

    // Only init the PDF viewer if it's actually a PDF!
    if (!_isProtected && !_isImageResult) {
      _initController();
    }
  }

  void _initController() {
    if (widget.resultFiles.isNotEmpty) {
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.resultFiles[_focusedIndex].path),
      );
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _showRenameDialog() async {
    HapticFeedback.selectionClick();
    final primaryColor = Theme.of(context).primaryColor;
    final controller = TextEditingController(text: _currentCustomName);

    final extension = _isImageResult ? '' : '.pdf';

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: primaryColor),
            const SizedBox(width: 8),
            const Text(
              'Rename Document',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter file name',
            suffixText: extension,
            suffixStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                Navigator.pop(context, trimmed);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      setState(() {
        _currentCustomName = newName;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _shareFiles() async {
    HapticFeedback.lightImpact();
    final xFiles = widget.resultFiles.map((f) => XFile(f.path)).toList();
    await Share.shareXFiles(xFiles, text: 'Processed with PDF Pro 📄');
  }

  Future<void> _saveAllToDeviceStorage() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      Directory? targetDir;

      if (Platform.isAndroid) {
        // Fallback for image saving vs document saving
        if (_isImageResult) {
          targetDir = Directory('/storage/emulated/0/Pictures/PDFPro');
          if (!await targetDir.exists())
            await targetDir.create(recursive: true);
        } else {
          targetDir = Directory('/storage/emulated/0/Download');
          if (!await targetDir.exists())
            targetDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        targetDir = await getApplicationDocumentsDirectory();
      }

      if (targetDir == null)
        throw Exception('Could not access storage directory');

      int savedCount = 0;
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _isImageResult ? '.jpg' : '.pdf';

      for (int i = 0; i < widget.resultFiles.length; i++) {
        final file = widget.resultFiles[i];
        final suffix = widget.resultFiles.length > 1 ? '_part_${i + 1}' : '';
        final cleanBaseName = _currentCustomName.replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_',
        );
        final savedPath =
            '${targetDir.path}/${cleanBaseName}${suffix}_$timeStamp$extension';

        final savedFile = await file.copy(savedPath);
        savedCount++;

        // Only add PDFs to recent history (Skip tracking individual JPGs in recents to avoid clutter)
        if (!_isImageResult) {
          try {
            int pages = 1;
            if (widget.title.toLowerCase().contains('split')) {
              pages = 1;
            } else if (_pdfController != null) {
              pages = _pdfController!.pagesCount ?? 1;
            }

            final displayName = widget.resultFiles.length > 1
                ? '${_currentCustomName}_part_${i + 1}.pdf'
                : '$_currentCustomName.pdf';

            final newModel = PdfDocumentModel(
              id: '${DateTime.now().millisecondsSinceEpoch}_$i',
              name: displayName,
              path: savedFile.path,
              pageCount: pages,
              sizeInBytes: savedFile.lengthSync(),
              lastAccessed: DateTime.now(),
            );
            ref.read(recentFilesProvider.notifier).addFile(newModel);
          } catch (e) {
            debugPrint("Failed to add to recents: $e");
          }
        }
      }

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
                    'Saved $savedCount file(s) as "$_currentCustomName$extension"! 📁',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: _shareFiles,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to save: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildCompressionStats(Color primaryColor) {
    final oldSize = widget.originalFile!.lengthSync();
    final newSize = widget.resultFiles.first.lengthSync();
    final savedBytes = oldSize - newSize;
    final bool wasReduced = savedBytes > 0;
    final percent = oldSize > 0 && wasReduced
        ? (savedBytes / oldSize * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: wasReduced ? Colors.green.shade200 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Original Size
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ORIGINAL',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatBytes(oldSize),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              // 2. Compact Center Indicator (Badge & Arrow on one line)
              if (wasReduced)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        '-$percent%',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.green.shade400, size: 18),
                  ],
                )
              else
                Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),

              // 3. Result Size
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'COMPRESSED',
                    style: TextStyle(
                      color: wasReduced ? Colors.green.shade600 : primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatBytes(newSize),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: wasReduced ? Colors.green.shade700 : primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 4. Tight fallback text
          if (!wasReduced) ...[
            const SizedBox(height: 8),
            Text(
              'Document is already optimally compressed.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final extension = _isImageResult ? '' : '.pdf';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _showRenameDialog,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '$_currentCustomName$extension',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.edit_rounded, size: 16, color: primaryColor),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 26),
            onPressed: _isSaving ? null : _saveAllToDeviceStorage,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 24),
            onPressed: _shareFiles,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isProtected
                      ? _buildProtectedPlaceholder(primaryColor)
                      : _isImageResult
                      ? InteractiveViewer(
                          maxScale: 4.0,
                          child: Center(
                            child: Image.file(
                              widget.resultFiles[_focusedIndex],
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      : PdfViewPinch(
                          key: ValueKey(_focusedIndex),
                          controller: _pdfController!,
                          scrollDirection: Axis.vertical,
                          padding: 16.0,
                          onDocumentError: (_) =>
                              setState(() => _isProtected = true),
                        ),
                ),
              ),
            ),
            if (widget.originalFile != null &&
                widget.title.toLowerCase().contains('compress'))
              _buildCompressionStats(primaryColor),

            // 🚀 Horizontal list for multiple output files (JPGs or Split PDFs)
            if (widget.resultFiles.length > 1) ...[
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.resultFiles.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _focusedIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _focusedIndex = index;
                          if (!_isProtected && !_isImageResult) {
                            _pdfController?.dispose();
                            _initController();
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Center(
                          child: Text(
                            _isImageResult
                                ? 'Page ${index + 1}'
                                : 'Part ${index + 1}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveAllToDeviceStorage,
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
                          ? 'Saving...'
                          : widget.resultFiles.length > 1
                          ? 'Save All to Device'
                          : 'Save File to Device',
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
                  OutlinedButton.icon(
                    onPressed: _shareFiles,
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: const Text(
                      'Share / Export',
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

  Widget _buildProtectedPlaceholder(Color primaryColor) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_rounded, size: 56, color: primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'PDF Protected Successfully! 🔒',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Your document is encrypted with password protection and ready to share or save.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
