import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/compression_level.dart';

class PdfCompressService {
  Future<File> compressPdf({
    required File inputFile,
    required CompressionLevel level,
    String? outputFileName,
  }) async {
    final sourceDoc = await pdfx.PdfDocument.openFile(inputFile.path);
    final totalPages = sourceDoc.pagesCount;

    final PdfDocument compressedDoc = PdfDocument();
    compressedDoc.compressionLevel = PdfCompressionLevel.best;
    compressedDoc.pageSettings.setMargins(0);

    for (int i = 1; i <= totalPages; i++) {
      final page = await sourceDoc.getPage(i);

      final renderedImage = await page.render(
        width: page.width * level.scaleFactor,
        height: page.height * level.scaleFactor,
        format: pdfx.PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
        quality: level.jpegQuality,
      );
      await page.close();

      if (renderedImage != null) {
        final PdfBitmap bitmap = PdfBitmap(renderedImage.bytes);
        final PdfSection section = compressedDoc.sections!.add();
        section.pageSettings.size = Size(page.width, page.height);

        final PdfPage newPage = section.pages.add();
        newPage.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(0, 0, page.width, page.height),
        );
      }
    }

    await sourceDoc.close();

    final List<int> outputBytes = await compressedDoc.save();
    compressedDoc.dispose();

    final tempDir = await getTemporaryDirectory();
    final fileName = (outputFileName != null && outputFileName.trim().isNotEmpty)
        ? (outputFileName.endsWith('.pdf') ? outputFileName : '$outputFileName.pdf')
        : 'compressed_${DateTime.now().millisecondsSinceEpoch}.pdf';

    final outputFile = File('${tempDir.path}/$fileName');
    await outputFile.writeAsBytes(outputBytes, flush: true);

    return outputFile;
  }
}