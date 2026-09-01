import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import 'widgets/custom_app_bar.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final List<List<Offset>> _paths = [];
  List<Offset> _currentPath = [];

  Color _selectedColor = AppColors.textPrimary;
  double _strokeWidth = 3.0;

  final List<Color> _availableColors = [
    AppColors.textPrimary,
    AppColors.primaryBlue,
    const Color(0xFF003366), // Navy
  ];

  void _clearCanvas() {
    HapticFeedback.lightImpact();
    setState(() {
      _paths.clear();
      _currentPath.clear();
    });
  }

  void _undoLastPath() {
    if (_paths.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _paths.removeLast();
      });
    }
  }

  Future<Uint8List?> _captureSignatureBytes() async {
    if (_paths.isEmpty && _currentPath.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const canvasSize = Size(800, 400);

    final paint = Paint()
      ..color = _selectedColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = _strokeWidth * 2 // Scale stroke for high-DPI export
      ..style = PaintingStyle.stroke;

    for (final path in _paths) {
      for (int i = 0; i < path.length - 1; i++) {
        canvas.drawLine(path[i] * 2, path[i + 1] * 2, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  void _saveAndReturn() async {
    final bytes = await _captureSignatureBytes();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please draw a signature before saving.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (mounted) {
      Navigator.of(context).pop(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Add Signature',
        showBackButton: true,
        actions: [
          TextButton(
            onPressed: _saveAndReturn,
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Canvas Drawing Area
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Watermark / Baseline guideline
                        Positioned.fill(
                          child: Align(
                            alignment: const Alignment(0, 0.4),
                            child: Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              color: AppColors.borderSubtle,
                            ),
                          ),
                        ),
                        // Finger Canvas
                        GestureDetector(
                          onPanStart: (details) {
                            setState(() {
                              _currentPath = [details.localPosition];
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              _currentPath.add(details.localPosition);
                            });
                          },
                          onPanEnd: (details) {
                            setState(() {
                              _paths.add(List.from(_currentPath));
                              _currentPath.clear();
                            });
                          },
                          child: CustomPaint(
                            painter: SignaturePainter(
                              paths: _paths,
                              currentPath: _currentPath,
                              color: _selectedColor,
                              strokeWidth: _strokeWidth,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Control Panel Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    // Color Pickers
                    Row(
                      children: _availableColors.map((color) {
                        final isSelected = _selectedColor == color;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedColor = color);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: AppColors.primaryBlue, width: 2.5)
                                  : Border.all(color: AppColors.border),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Spacer(),

                    // Action Buttons (Undo & Clear)
                    IconButton(
                      icon: const Icon(Icons.undo_rounded, color: AppColors.textSecondary),
                      onPressed: _paths.isNotEmpty ? _undoLastPath : null,
                      tooltip: 'Undo',
                    ),
                    TextButton.icon(
                      onPressed: _clearCanvas,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<List<Offset>> paths;
  final List<Offset> currentPath;
  final Color color;
  final double strokeWidth;

  SignaturePainter({
    required this.paths,
    required this.currentPath,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final path in paths) {
      for (int i = 0; i < path.length - 1; i++) {
        canvas.drawLine(path[i], path[i + 1], paint);
      }
    }

    for (int i = 0; i < currentPath.length - 1; i++) {
      canvas.drawLine(currentPath[i], currentPath[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}