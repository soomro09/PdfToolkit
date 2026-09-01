import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/pdf_engine_service.dart';
import '../feature/pdf/views/pdf_result_screen.dart';

enum WatermarkType { text, image }

class WatermarkSettingsScreen extends StatefulWidget {
  final File pdfFile;

  const WatermarkSettingsScreen({super.key, required this.pdfFile});

  @override
  State<WatermarkSettingsScreen> createState() =>
      _WatermarkSettingsScreenState();
}

class _WatermarkSettingsScreenState extends State<WatermarkSettingsScreen> {
  WatermarkType _selectedType = WatermarkType.text;
  final TextEditingController _textController = TextEditingController(
    text: 'CONFIDENTIAL',
  );
  final FocusNode _textFocusNode = FocusNode(); // 👈 Add this FocusNode

  @override
  void initState() {
    super.initState();
    // Select all text when focus is gained
    _textFocusNode.addListener(() {
      if (_textFocusNode.hasFocus) {
        _selectAllText();
      }
    });
  }

  void _selectAllText() {
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _textController.text.length,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose(); // 👈 Don't forget to dispose
    super.dispose();
  }

  File? _selectedImageFile;

  // Appearance controls
  double _fontSize = 36.0;
  double _imageScale = 0.4;
  double _opacity = 0.25;
  double _rotation = -45.0;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _applyWatermark() async {
    if (_selectedType == WatermarkType.text &&
        _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter watermark text.')),
      );
      return;
    }

    if (_selectedType == WatermarkType.image && _selectedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick an image stamp.')),
      );
      return;
    }

    HapticFeedback.heavyImpact();

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
                  'Applying watermark...',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final watermarkedFile = await PdfEngineService.addCustomWatermark(
        pdfFile: widget.pdfFile,
        isImage: _selectedType == WatermarkType.image,
        watermarkText: _textController.text.trim(),
        imageFile: _selectedImageFile,
        fontSize: _fontSize,
        imageScale: _imageScale,
        opacity: _opacity,
        rotationDegrees: _rotation,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PdfResultScreen(
            resultFiles: [watermarkedFile],
            title: 'Watermarked PDF',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply watermark: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: SafeArea(
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
                    const Text(
                      'Watermark Settings',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Customize your watermark stamp',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Segmented Mode Switcher
                    // 🔀 Professional Animated Segmented Control
                    Container(
                      height: 52,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9ECEF),
                        // Neutral modern track background
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double segmentWidth =
                              (constraints.maxWidth - 4) / 2;
                          final bool isText =
                              _selectedType == WatermarkType.text;

                          return Stack(
                            children: [
                              // 🏃 Smooth Sliding Active Pill Indicator
                              AnimatedAlign(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeInOutCubic,
                                alignment: isText
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                child: Container(
                                  width: segmentWidth,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 🔘 Interactive Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSegmentOption(
                                      type: WatermarkType.text,
                                      icon: Icons.text_fields_rounded,
                                      label: 'Text',
                                      isSelected: isText,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildSegmentOption(
                                      type: WatermarkType.image,
                                      icon: Icons.image_rounded,
                                      label: 'Image',
                                      isSelected: !isText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Content Input Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _selectedType == WatermarkType.text
                          ? TextField(
                              controller: _textController,
                              focusNode: _textFocusNode,
                              onTap: _selectAllText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Watermark Text',
                                labelStyle: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                                prefixIcon: Icon(
                                  Icons.text_format_rounded,
                                  color: AppColors.primaryRed,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.primaryRed,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            )
                          : InkWell(
                              onTap: _pickImage,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      _selectedImageFile != null
                                          ? Icons.check_circle_rounded
                                          : Icons.add_photo_alternate_rounded,
                                      color: _selectedImageFile != null
                                          ? Colors.green
                                          : AppColors.primaryRed,
                                      size: 36,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedImageFile != null
                                          ? _selectedImageFile!.path
                                                .split('/')
                                                .last
                                          : 'Select Logo or Stamp Image',
                                      style: TextStyle(
                                        color: _selectedImageFile != null
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Appearance Controls Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Appearance',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Size / Scale Slider
                          if (_selectedType == WatermarkType.text) ...[
                            _buildSliderHeader(
                              'Font Size',
                              '${_fontSize.toInt()} pt',
                            ),
                            Slider(
                              value: _fontSize,
                              min: 16,
                              max: 96,
                              activeColor: AppColors.primaryRed,
                              inactiveColor: AppColors.primaryRed.withOpacity(
                                0.15,
                              ),
                              onChanged: (val) =>
                                  setState(() => _fontSize = val),
                            ),
                          ] else ...[
                            _buildSliderHeader(
                              'Image Scale',
                              '${(_imageScale * 100).toInt()}%',
                            ),
                            Slider(
                              value: _imageScale,
                              min: 0.1,
                              max: 0.9,
                              activeColor: AppColors.primaryRed,
                              inactiveColor: AppColors.primaryRed.withOpacity(
                                0.15,
                              ),
                              onChanged: (val) =>
                                  setState(() => _imageScale = val),
                            ),
                          ],

                          // Opacity Slider
                          _buildSliderHeader(
                            'Opacity',
                            '${(_opacity * 100).toInt()}%',
                          ),
                          Slider(
                            value: _opacity,
                            min: 0.05,
                            max: 1.0,
                            activeColor: AppColors.primaryRed,
                            inactiveColor: AppColors.primaryRed.withOpacity(
                              0.15,
                            ),
                            onChanged: (val) => setState(() => _opacity = val),
                          ),

                          // Rotation Slider
                          _buildSliderHeader(
                            'Rotation (Degrees)',
                            '${_rotation.toInt()}°',
                          ),
                          Slider(
                            value: _rotation,
                            min: -180,
                            max: 180,
                            activeColor: AppColors.primaryRed,
                            inactiveColor: AppColors.primaryRed.withOpacity(
                              0.15,
                            ),
                            onChanged: (val) => setState(() => _rotation = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _applyWatermark,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Add Watermark',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderHeader(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentOption({
    required WatermarkType type,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primaryRed.withOpacity(0.08),
        highlightColor: Colors.transparent,
        onTap: () {
          if (_selectedType != type) {
            HapticFeedback.selectionClick();
            setState(() => _selectedType = type);
          }
        },
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? AppColors.primaryRed
                  : AppColors.textSecondary,
              letterSpacing: -0.2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    icon,
                    key: ValueKey<bool>(isSelected),
                    size: 19,
                    color: isSelected
                        ? AppColors.primaryRed
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
