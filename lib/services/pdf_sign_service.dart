import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfSignService {
  /// Stamps a signature PNG image onto a specified PDF page at (x, y) coordinates
  Future<File> embedSignature({
    required File pdfFile,
    required Uint8List signatureImageBytes,
    required int pageIndex,
    required Rect targetBounds,
    required String outputFilePath,
  }) async {
    final pdfBytes = await pdfFile.readAsBytes();

    final resultPath = await compute(_executeSign, {
      'pdfBytes': pdfBytes,
      'signatureBytes': signatureImageBytes,
      'pageIndex': pageIndex,
      'x': targetBounds.left,
      'y': targetBounds.top,
      'width': targetBounds.width,
      'height': targetBounds.height,
      'outputPath': outputFilePath,
    });

    return File(resultPath);
  }

  static Future<String> _executeSign(Map<String, dynamic> params) async {
    final List<int> pdfBytes = params['pdfBytes'];
    final List<int> signatureBytes = params['signatureBytes'];
    final int pageIndex = params['pageIndex'];
    final double x = params['x'];
    final double y = params['y'];
    final double width = params['width'];
    final double height = params['height'];
    final String outputPath = params['outputPath'];

    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);

    try {
      if (pageIndex < 0 || pageIndex >= document.pages.count) {
        throw ArgumentError('Invalid page index: $pageIndex');
      }

      final PdfPage page = document.pages[pageIndex];
      final PdfBitmap signatureBitmap = PdfBitmap(signatureBytes);

      // Draw the transparent signature image overlay onto the page graphics surface
      page.graphics.drawImage(
        signatureBitmap,
        Rect.fromLTWH(x, y, width, height),
      );

      final List<int> signedPdfBytes = await document.save();
      final File outputFile = File(outputPath);
      await outputFile.writeAsBytes(signedPdfBytes, flush: true);

      return outputPath;
    } finally {
      document.dispose();
    }
  }
}