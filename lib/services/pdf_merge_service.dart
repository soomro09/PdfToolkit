import 'dart:io';
import 'dart:math' as math; // 👈 We need this for the dimension logic!
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfMergeService {
  /// Merges PDFs with mixed horizontal and vertical pages! 📄🔄
  static Future<File> mergePdfs(List<File> files, String outputName) async {
    if (files.length < 2) {
      throw ArgumentError('At least 2 PDF files are required to merge.');
    }

    final List<String> inputPaths = files.map((f) => f.path).toList();
    final String tempOutputDir = (await getTemporaryDirectory()).path;
    final String outputPath = '$tempOutputDir/$outputName.pdf';

    final String resultPath = await compute(
      _performMergeTask,
      _MergeParams(inputPaths: inputPaths, outputPath: outputPath),
    );

    return File(resultPath);
  }

  static Future<String> _performMergeTask(_MergeParams params) async {
    final PdfDocument outputDocument = PdfDocument();

    try {
      for (final path in params.inputPaths) {
        final File file = File(path);
        if (!file.existsSync()) continue;

        final Uint8List bytes = await file.readAsBytes();
        final PdfDocument inputDocument = PdfDocument(inputBytes: bytes);

        // According to Syncfusion's official Flutter docs, createTemplate is
        // the required method to combine pages.
        for (int i = 0; i < inputDocument.pages.count; i++) {
          final PdfPage inputPage = inputDocument.pages[i];
          final PdfTemplate template = inputPage.createTemplate();

          final Size tSize = template.size;

          // 1. Create a dedicated section for EVERY page
          final PdfSection section = outputDocument.sections!.add();
          section.pageSettings.margins.all = 0;

          // 2. 🧠 THE MAGIC: Always calculate a strict Portrait size (Short x Long)
          final double shortSide = math.min(tSize.width, tSize.height);
          final double longSide = math.max(tSize.width, tSize.height);

          // Give Syncfusion the portrait dimensions...
          section.pageSettings.size = Size(shortSide, longSide);

          // 3. ...And let the orientation flag flip the canvas for horizontal pages! 🔄
          if (tSize.width > tSize.height) {
            section.pageSettings.orientation = PdfPageOrientation.landscape;
          } else {
            section.pageSettings.orientation = PdfPageOrientation.portrait;
          }

          // 4. Draw perfectly!
          final PdfPage newPage = section.pages.add();
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }

        inputDocument.dispose();
      }

      final List<int> outputBytes = await outputDocument.save();
      final File outputFile = File(params.outputPath);
      await outputFile.writeAsBytes(outputBytes, flush: true);

      return params.outputPath;
    } finally {
      outputDocument.dispose();
    }
  }
}

class _MergeParams {
  final List<String> inputPaths;
  final String outputPath;

  _MergeParams({required this.inputPaths, required this.outputPath});
}