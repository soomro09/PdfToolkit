import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PageRange {
  final int startPage; // 1-based index
  final int endPage;   // 1-based index

  PageRange({required this.startPage, required this.endPage});
}

class PdfSplitService {
  Future<List<File>> splitPdf({
    required File sourceFile,
    required List<PageRange> ranges,
    required String baseOutputName,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();

    final rangeMaps = ranges
        .map((r) => {'start': r.startPage, 'end': r.endPage})
        .toList();

    final resultPaths = await compute(_executeSplit, {
      'sourcePath': sourceFile.path,
      'outputDir': appDocDir.path,
      'baseName': baseOutputName,
      'ranges': rangeMaps,
    });

    return resultPaths.map((path) => File(path)).toList();
  }

  static Future<List<String>> _executeSplit(Map<String, dynamic> params) async {
    final String sourcePath = params['sourcePath'];
    final String outputDir = params['outputDir'];
    final String baseName = params['baseName'];
    final List<Map<String, int>> ranges =
    List<Map<String, int>>.from(params['ranges']);

    final File sourceFile = File(sourcePath);
    final List<int> sourceBytes = await sourceFile.readAsBytes();

    final PdfDocument sourceDocument = PdfDocument(inputBytes: sourceBytes);
    final List<String> generatedPaths = [];

    try {
      int rangeIndex = 1;
      for (final range in ranges) {
        final int start = range['start']!;
        final int end = range['end']!;

        if (start < 1 || end > sourceDocument.pages.count || start > end) {
          continue;
        }

        final PdfDocument targetDocument = PdfDocument();

        for (int i = start - 1; i < end; i++) {
          final PdfPage sourcePage = sourceDocument.pages[i];

          // ✅ 1. Get the original page size (unrotated for layout)
          final Size pageSize = sourcePage.size;
          final PdfTemplate template = sourcePage.createTemplate();

          // ✅ 2. Create a new section with zero margins to avoid inherited settings
          final PdfSection section = targetDocument.sections!.add();
          section.pageSettings.margins.all = 0;

          // ✅ 3. Set orientation before size
          if (pageSize.width > pageSize.height) {
            section.pageSettings.orientation = PdfPageOrientation.landscape;
          } else {
            section.pageSettings.orientation = PdfPageOrientation.portrait;
          }

          // ✅ 4. Preserve rotation
          section.pageSettings.rotate = sourcePage.rotation;

          // ✅ 5. Set the exact page size (last assignment to prevent swapping)
          section.pageSettings.size = pageSize;

          final PdfPage newPage = section.pages.add();

          // ✅ 6. Draw the template at full size — no scaling, no clipping
          newPage.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            pageSize,
          );
        }

        final String outputPath = '$outputDir/${baseName}_part_$rangeIndex.pdf';
        final List<int> outputBytes = await targetDocument.save();

        final File outputFile = File(outputPath);
        await outputFile.writeAsBytes(outputBytes, flush: true);

        generatedPaths.add(outputPath);
        targetDocument.dispose();
        rangeIndex++;
      }

      return generatedPaths;
    } finally {
      sourceDocument.dispose();
    }
  }
}