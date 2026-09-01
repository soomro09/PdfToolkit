import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum PageFitMode {
  fitToPage,   // Scales image to fill printable page bounds while maintaining aspect ratio
  originalSize, // Keeps raw image aspect/resolution, resizing page box around it
}

class PdfImagesToPdfService {
  /// Converts a ordered list of image files (JPG/PNG) into a single PDF document.
  /// Processing is executed in a compute isolate to prevent UI frame drops.
  Future<File> convertImagesToPdf({
    required List<File> imageFiles,
    required String outputFileName,
    PageFitMode fitMode = PageFitMode.fitToPage,
    PdfPageOrientation orientation = PdfPageOrientation.portrait,
  }) async {
    final imagePaths = imageFiles.map((f) => f.path).toList();
    final appDocDir = await getApplicationDocumentsDirectory();
    final outputPath = '${appDocDir.path}/$outputFileName.pdf';

    final resultPath = await compute(_executeImageToPdfConversion, {
      'imagePaths': imagePaths,
      'outputPath': outputPath,
      'fitMode': fitMode.index,
      'isPortrait': orientation == PdfPageOrientation.portrait,
    });

    return File(resultPath);
  }

  static Future<String> _executeImageToPdfConversion(Map<String, dynamic> params) async {
    final List<String> imagePaths = List<String>.from(params['imagePaths']);
    final String outputPath = params['outputPath'];
    final PageFitMode fitMode = PageFitMode.values[params['fitMode'] as int];
    final bool isPortrait = params['isPortrait'] as bool;

    final PdfDocument document = PdfDocument();

    try {
      // Default standard page configuration (A4 dimensions)
      document.pageSettings.size = PdfPageSize.a4;
      document.pageSettings.orientation = isPortrait
          ? PdfPageOrientation.portrait
          : PdfPageOrientation.landscape;
      document.pageSettings.margins.all = 0; // Edge-to-edge layout boundary

      for (final path in imagePaths) {
        final File file = File(path);
        if (!file.existsSync()) continue;

        final List<int> imageBytes = await file.readAsBytes();
        final PdfBitmap bitmap = PdfBitmap(imageBytes);

        final PdfPage page = document.pages.add();
        final Size pageSize = page.getClientSize();

        if (fitMode == PageFitMode.fitToPage) {
          // Calculate fitted aspect ratio bounding box within page dimensions
          final double imageWidth = bitmap.width.toDouble();
          final double imageHeight = bitmap.height.toDouble();

          final double widthRatio = pageSize.width / imageWidth;
          final double heightRatio = pageSize.height / imageHeight;
          final double scale = widthRatio < heightRatio ? widthRatio : heightRatio;

          final double scaledWidth = imageWidth * scale;
          final double scaledHeight = imageHeight * scale;

          final double x = (pageSize.width - scaledWidth) / 2;
          final double y = (pageSize.height - scaledHeight) / 2;

          page.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(x, y, scaledWidth, scaledHeight),
          );
        } else {
          // Draw image to fill page surface directly
          page.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
          );
        }
      }

      final List<int> pdfBytes = await document.save();
      final File outputFile = File(outputPath);
      await outputFile.writeAsBytes(pdfBytes, flush: true);

      return outputPath;
    } finally {
      document.dispose();
    }
  }
}