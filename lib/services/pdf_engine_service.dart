import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_utility_app/feature/pdf_compress/services/pdf_compress_service.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../feature/pdf_compress/models/compression_level.dart';
import '../models/signature_placement_model.dart';

class PdfEngineService {
  static Future<File> mergePdfs(List<File> files) async {
    final inputPaths = files.map((f) => f.path).toList();
    final outputPath = await _generateTempPath('merged');

    final resultPath = await compute(
      _mergeTask,
      _TaskParams(inputPaths: inputPaths, outputPath: outputPath),
    );
    return File(resultPath);
  }

  static Future<List<File>> splitPdf(File file) async {
    final tempDir = (await getTemporaryDirectory()).path;
    final resultPaths = await compute(
      _splitTask,
      _TaskParams(inputPaths: [file.path], outputPath: tempDir),
    );
    return resultPaths.map((p) => File(p)).toList();
  }

  static Future<File> compressPdf(File file, CompressionLevel level) async {
    final outputPath = await _generateTempPath('compressed');
    final resultPath = await compute(
      _compressTask,
      _TaskParams(
        inputPaths: [file.path],
        outputPath: outputPath,
        metadata: {'level': level.index},
      ),
    );
    return File(resultPath);
  }

  static Future<File> protectPdf(File file, String password) async {
    final outputPath = await _generateTempPath('protected');
    final resultPath = await compute(
      _protectTask,
      _TaskParams(
        inputPaths: [file.path],
        outputPath: outputPath,
        metadata: {'password': password},
      ),
    );
    return File(resultPath);
  }

  // 1. The lightweight background task (Must be static)
  static Future<String> _backgroundImagesToPdfTask(
    Map<String, dynamic> args,
  ) async {
    final List<String> imagePaths = args['paths'];
    final String outputPath = args['outputPath'];

    final PdfDocument document = PdfDocument();
    document.pageSettings.setMargins(0);

    for (final path in imagePaths) {
      // The background thread reads the file, saving the main UI thread!
      final bytes = await File(path).readAsBytes();
      final PdfBitmap image = PdfBitmap(bytes);

      final PdfSection section = document.sections!.add();
      section.pageSettings.size = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final PdfPage page = section.pages.add();
      page.graphics.drawImage(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      );
    }

    final List<int> outBytes = await document.save();
    document.dispose();

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(outBytes, flush: true);

    return outputPath;
  }

  // 2. The main method that calls the background task
  static Future<File> imagesToPdf(List<File> imageFiles) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/images_to_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';

    // 🚀 Pass ONLY Strings (file paths) to the isolate, never heavy memory/bytes!
    final paths = imageFiles.map((f) => f.path).toList();

    final resultPath = await compute(_backgroundImagesToPdfTask, {
      'paths': paths,
      'outputPath': outputPath,
    });

    return File(resultPath);
  }

  static Future<String> _generateTempPath(String prefix) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${tempDir.path}/${prefix}_$timestamp.pdf';
  }

  static Future<File> organizePdf(
    File originalFile,
    List<Map<String, int>> pageConfigurations,
  ) async {
    final outputPath = await _generateTempPath('organized');
    final resultPath = await compute(
      _organizeTask,
      _TaskParams(
        inputPaths: [originalFile.path],
        outputPath: outputPath,
        metadata: {'configurations': pageConfigurations},
      ),
    );
    return File(resultPath);
  }

  static Future<File> textToPdf(
    String textContent, {
    String title = 'Document',
  }) async {
    final outputPath = await _generateTempPath('text_doc');
    final resultPath = await compute(
      _textToPdfTask,
      _TaskParams(
        inputPaths: [],
        outputPath: outputPath,
        metadata: {'text': textContent, 'title': title},
      ),
    );
    return File(resultPath);
  }

  static Future<String> pdfToText(File pdfFile) async {
    final inputBytes = await pdfFile.readAsBytes();
    final inputDoc = PdfDocument(inputBytes: inputBytes);
    final extractor = PdfTextExtractor(inputDoc);
    final text = extractor.extractText(); // Extracts text cleanly
    inputDoc.dispose();
    return text;
  }

  // services/pdf_engine_service.dart
  static Future<List<File>> pdfToJpg(
    File pdfFile, {
    List<int>? selectedPages,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(pdfFile.path);
    final totalPages = doc.pagesCount;
    final List<File> exportedImages = [];
    final tempDir = await getTemporaryDirectory();
    final timeStamp = DateTime.now().millisecondsSinceEpoch;

    // If selectedPages is provided, use it; otherwise fallback to 1..totalPages
    final List<int> pagesToProcess =
        selectedPages != null && selectedPages.isNotEmpty
        ? selectedPages
        : List.generate(totalPages, (index) => index + 1);

    for (final pageNumber in pagesToProcess) {
      // pdfx pages are 1-based (1 to totalPages)
      if (pageNumber < 1 || pageNumber > totalPages) continue;

      final page = await doc.getPage(pageNumber);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: pdfx.PdfPageImageFormat.jpeg,
      );
      await page.close();

      if (pageImage != null) {
        final imgFile = File(
          '${tempDir.path}/page_${pageNumber}_$timeStamp.jpg',
        );
        await imgFile.writeAsBytes(pageImage.bytes);
        exportedImages.add(imgFile);
      }
    }

    await doc.close();
    return exportedImages;
  }

  static Future<File> addWatermark(File pdfFile, String watermarkText) async {
    final outputPath = await _generateTempPath('watermarked');
    final resultPath = await compute(
      _watermarkTask,
      _TaskParams(
        inputPaths: [pdfFile.path],
        outputPath: outputPath,
        metadata: {'watermark': watermarkText},
      ),
    );
    return File(resultPath);
  }

  static Future<File?> startDocumentScan() async {
    final options = DocumentScannerOptions(
      documentFormats: const {DocumentFormat.jpeg},
      // 👈 Updated name and wrapped in a list
      mode: ScannerMode.full,
      // Gives full controls, filters, auto/manual capture
      pageLimit: 50,
      // Multi-page scanning support
      isGalleryImport: true, // 👈 Updated parameter name
    );

    final scanner = DocumentScanner(options: options);
    final DocumentScanningResult result = await scanner.scanDocument();

    final List<String>? images = result.images;
    if (images == null || images.isEmpty) {
      return null; // User cancelled the scan
    }

    // Compile the scanned pages into a crisp PDF
    final outputPath = await _generateTempPath('scanned_doc');
    final pdfDoc = PdfDocument();

    try {
      for (final imgPath in images) {
        final imgBytes = await File(imgPath).readAsBytes();
        final bitmap = PdfBitmap(imgBytes);

        final section = pdfDoc.sections!.add();
        section.pageSettings.margins.all = 0;

        // Match section size to scanned photo aspect ratio
        final size = Size(bitmap.width.toDouble(), bitmap.height.toDouble());
        section.pageSettings.size = size;
        section.pageSettings.orientation = size.width > size.height
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait;

        final page = section.pages.add();
        page.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(0, 0, size.width, size.height),
        );
      }

      final pdfBytes = await pdfDoc.save();
      final file = File(outputPath);
      await file.writeAsBytes(pdfBytes, flush: true);
      return file;
    } finally {
      pdfDoc.dispose();
    }
  }

  static Future<File> addCustomWatermark({
    required File pdfFile,
    required bool isImage,
    String watermarkText = '',
    File? imageFile,
    double fontSize = 36.0,
    double imageScale = 0.4,
    double opacity = 0.25,
    double rotationDegrees = -45.0,
  }) async {
    final outputPath = await _generateTempPath('watermarked');
    final resultPath = await compute(
      _watermarkTask,
      _TaskParams(
        inputPaths: [pdfFile.path, if (imageFile != null) imageFile.path],
        outputPath: outputPath,
        metadata: {
          'isImage': isImage,
          'watermark': watermarkText,
          'fontSize': fontSize,
          'imageScale': imageScale,
          'opacity': opacity,
          'rotation': rotationDegrees,
        },
      ),
    );
    return File(resultPath);
  }

  static Future<File> extractPageRange(
    File originalFile,
    List<int> zeroBasedPageIndices,
  ) async {
    final outputPath = await _generateTempPath('extracted_range');
    final resultPath = await compute(
      _extractPagesTask,
      _TaskParams(
        inputPaths: [originalFile.path],
        outputPath: outputPath,
        metadata: {'pages': zeroBasedPageIndices},
      ),
    );
    return File(resultPath);
  }

  static Future<File> unlockPdf(File file, String password) async {
    final outputPath = await _generateTempPath('unlocked');
    final resultPath = await compute(
      _unlockTask,
      _TaskParams(
        inputPaths: [file.path],
        outputPath: outputPath,
        metadata: {'password': password},
      ),
    );
    return File(resultPath);
  }

  static Future<bool> isPdfEncrypted(File file) async {
    try {
      final bytes = await file.readAsBytes();
      // Attempt to open without a password
      final doc = PdfDocument(inputBytes: bytes);
      final bool isEncrypted =
          doc.security.userPassword.isNotEmpty ||
          doc.security.ownerPassword.isNotEmpty;
      doc.dispose();
      return isEncrypted;
    } catch (e) {
      // If opening without a password throws an error, it is password-protected
      return true;
    }
  }

  static Future<File> signPdf({
    required File pdfFile,
    required File signatureImageFile,
    required List<SignaturePlacement> placements,
    required Size renderedPageSize,
  }) async {
    final bytes = await pdfFile.readAsBytes();
    final inputDoc = PdfDocument(inputBytes: bytes);

    final sigBytes = await signatureImageFile.readAsBytes();
    final PdfBitmap signatureBitmap = PdfBitmap(sigBytes);

    for (final placement in placements) {
      final page = inputDoc.pages[placement.pageIndex];
      final double scaleX = page.size.width / renderedPageSize.width;
      final double scaleY = page.size.height / renderedPageSize.height;
      final double pdfX = placement.position.dx * scaleX;
      final double pdfY = placement.position.dy * scaleY;
      final double pdfHeight = placement.size.height * scaleY;
      final double pdfWidth = pdfHeight * placement.aspectRatio;

      page.graphics.drawImage(
        signatureBitmap,
        Rect.fromLTWH(pdfX, pdfY, pdfWidth, pdfHeight),
      );
    }

    final outputDoc = PdfDocument();

    for (int i = 0; i < inputDoc.pages.count; i++) {
      final inputPage = inputDoc.pages[i];
      final template = inputPage.createTemplate();
      final size = inputPage.size;

      final section = outputDoc.sections!.add();
      section.pageSettings.margins.all = 0;
      section.pageSettings.size = size;

      if (size.width > size.height) {
        section.pageSettings.orientation = PdfPageOrientation.landscape;
      } else {
        section.pageSettings.orientation = PdfPageOrientation.portrait;
      }

      final page = section.pages.add();
      const double scale = 0.96;
      final drawWidth = size.width * scale;
      final drawHeight = size.height * scale;
      final offsetX = (size.width - drawWidth) / 2;
      final offsetY = (size.height - drawHeight) / 2;

      page.graphics.drawPdfTemplate(
        template,
        Offset(offsetX, offsetY),
        Size(drawWidth, drawHeight),
      );
    }

    final outputBytes = await outputDoc.save();
    inputDoc.dispose();
    outputDoc.dispose();

    final tempDir = await getTemporaryDirectory();
    final signedFile = File(
      '${tempDir.path}/signed_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    return await signedFile.writeAsBytes(outputBytes, flush: true);
  }
}

// --------------------------------------------------------
// BACKGROUND ISOLATE WORKERS
// (Must remain outside the class to work with compute())
// --------------------------------------------------------

class _TaskParams {
  final List<String> inputPaths;
  final String outputPath;
  final Map<String, dynamic>? metadata;

  _TaskParams({
    required this.inputPaths,
    required this.outputPath,
    this.metadata,
  });
}

Future<String> _unlockTask(_TaskParams params) async {
  final inputBytes = await File(params.inputPaths.first).readAsBytes();
  final password = params.metadata!['password'] as String;

  // 1. Open with the provided password
  final inputDoc = PdfDocument(inputBytes: inputBytes, password: password);

  // 2. Create a clean doc with no security settings
  final outputDoc = PdfDocument();
  try {
    for (int i = 0; i < inputDoc.pages.count; i++) {
      final inputPage = inputDoc.pages[i];
      final template = inputPage.createTemplate();
      final size = inputPage.size;

      final section = outputDoc.sections!.add();
      section.pageSettings.margins.all = 0;
      section.pageSettings.size = size;
      section.pageSettings.orientation = size.width > size.height
          ? PdfPageOrientation.landscape
          : PdfPageOrientation.portrait;

      final page = section.pages.add();

      // Safe 95% scale rule
      const double scale = 0.95;
      final double drawWidth = size.width * scale;
      final double drawHeight = size.height * scale;
      final double offsetX = (size.width - drawWidth) / 2;
      final double offsetY = (size.height - drawHeight) / 2;

      page.graphics.drawPdfTemplate(
        template,
        Offset(offsetX, offsetY),
        Size(drawWidth, drawHeight),
      );
    }

    final bytes = await outputDoc.save();
    await File(params.outputPath).writeAsBytes(bytes, flush: true);
    return params.outputPath;
  } finally {
    inputDoc.dispose();
    outputDoc.dispose();
  }
}

Future<String> _mergeTask(_TaskParams params) async {
  final outputDoc = PdfDocument();
  try {
    for (final path in params.inputPaths) {
      final bytes = await File(path).readAsBytes();
      final inputDoc = PdfDocument(inputBytes: bytes);

      for (int i = 0; i < inputDoc.pages.count; i++) {
        final inputPage = inputDoc.pages[i];
        final template = inputPage.createTemplate();
        final size = inputPage.size;

        final section = outputDoc.sections!.add();
        section.pageSettings.margins.all = 0;
        section.pageSettings.size = size;

        if (size.width > size.height) {
          section.pageSettings.orientation = PdfPageOrientation.landscape;
        } else {
          section.pageSettings.orientation = PdfPageOrientation.portrait;
        }

        final page = section.pages.add();
        const double scale = 0.96;
        final drawWidth = size.width * scale;
        final drawHeight = size.height * scale;
        final offsetX = (size.width - drawWidth) / 2;
        final offsetY = (size.height - drawHeight) / 2;

        page.graphics.drawPdfTemplate(
          template,
          Offset(offsetX, offsetY),
          Size(drawWidth, drawHeight),
        );
      }
      inputDoc.dispose();
    }
    final bytes = await outputDoc.save();
    final outFile = File(params.outputPath);
    await outFile.writeAsBytes(bytes, flush: true);
    return params.outputPath;
  } finally {
    outputDoc.dispose();
  }
}

Future<List<String>> _splitTask(_TaskParams params) async {
  final inputBytes = await File(params.inputPaths.first).readAsBytes();
  final inputDoc = PdfDocument(inputBytes: inputBytes);
  final List<String> generatedPaths = [];

  try {
    for (int i = 0; i < inputDoc.pages.count; i++) {
      final splitDoc = PdfDocument();
      final inputPage = inputDoc.pages[i];
      final template = inputPage.createTemplate();
      final size = inputPage.size;

      final section = splitDoc.sections!.add();
      section.pageSettings.margins.all = 0;
      section.pageSettings.size = size;

      if (size.width > size.height) {
        section.pageSettings.orientation = PdfPageOrientation.landscape;
      } else {
        section.pageSettings.orientation = PdfPageOrientation.portrait;
      }

      final page = section.pages.add();
      const double scale = 0.96;
      final drawWidth = size.width * scale;
      final drawHeight = size.height * scale;
      final offsetX = (size.width - drawWidth) / 2;
      final offsetY = (size.height - drawHeight) / 2;

      page.graphics.drawPdfTemplate(
        template,
        Offset(offsetX, offsetY),
        Size(drawWidth, drawHeight),
      );

      final bytes = await splitDoc.save();
      final pagePath =
          '${params.outputPath}/page_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(pagePath).writeAsBytes(bytes, flush: true);
      generatedPaths.add(pagePath);
      splitDoc.dispose();
    }
    return generatedPaths;
  } finally {
    inputDoc.dispose();
  }
}

Future<String> _compressTask(_TaskParams params) async {
  final originalFile = File(params.inputPaths.first);
  final int originalSize = originalFile.lengthSync();

  final inputBytes = await originalFile.readAsBytes();
  final inputDoc = PdfDocument(inputBytes: inputBytes);
  final outputDoc = PdfDocument();

  try {
    final int levelIndex = params.metadata?['level'] ?? 2;

    switch (levelIndex) {
      case 0:
        outputDoc.compressionLevel = PdfCompressionLevel.none;
        break;
      case 1:
        outputDoc.compressionLevel = PdfCompressionLevel.normal;
        break;
      case 2:
      default:
        outputDoc.compressionLevel = PdfCompressionLevel.best;
        break;
    }

    for (int i = 0; i < inputDoc.pages.count; i++) {
      final inputPage = inputDoc.pages[i];
      final template = inputPage.createTemplate();
      final size = inputPage.size;

      final section = outputDoc.sections!.add();
      section.pageSettings.margins.all = 0;
      section.pageSettings.size = size;

      if (size.width > size.height) {
        section.pageSettings.orientation = PdfPageOrientation.landscape;
      } else {
        section.pageSettings.orientation = PdfPageOrientation.portrait;
      }

      final page = section.pages.add();
      const double scale = 0.96;
      final drawWidth = size.width * scale;
      final drawHeight = size.height * scale;
      final offsetX = (size.width - drawWidth) / 2;
      final offsetY = (size.height - drawHeight) / 2;

      page.graphics.drawPdfTemplate(
        template,
        Offset(offsetX, offsetY),
        Size(drawWidth, drawHeight),
      );
    }

    final bytes = await outputDoc.save();
    final File outputFile = File(params.outputPath);
    await outputFile.writeAsBytes(bytes, flush: true);

    final int newSize = outputFile.lengthSync();

    if (newSize >= originalSize) {
      await originalFile.copy(params.outputPath);
    }

    return params.outputPath;
  } finally {
    inputDoc.dispose();
    outputDoc.dispose();
  }
}

Future<String> _protectTask(_TaskParams params) async {
  final inputBytes = await File(params.inputPaths.first).readAsBytes();
  final inputDoc = PdfDocument(inputBytes: inputBytes);
  final outputDoc = PdfDocument();

  try {
    final password = params.metadata!['password'] as String;
    final security = outputDoc.security;
    security.userPassword = password;
    security.ownerPassword = password;
    security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

    for (int i = 0; i < inputDoc.pages.count; i++) {
      final inputPage = inputDoc.pages[i];
      final template = inputPage.createTemplate();
      final size = inputPage.size;

      final section = outputDoc.sections!.add();
      section.pageSettings.margins.all = 0;
      section.pageSettings.size = size;

      if (size.width > size.height) {
        section.pageSettings.orientation = PdfPageOrientation.landscape;
      } else {
        section.pageSettings.orientation = PdfPageOrientation.portrait;
      }

      final page = section.pages.add();
      const double scale = 0.96;
      final drawWidth = size.width * scale;
      final drawHeight = size.height * scale;
      final offsetX = (size.width - drawWidth) / 2;
      final offsetY = (size.height - drawHeight) / 2;

      page.graphics.drawPdfTemplate(
        template,
        Offset(offsetX, offsetY),
        Size(drawWidth, drawHeight),
      );
    }

    final bytes = await outputDoc.save();
    await File(params.outputPath).writeAsBytes(bytes, flush: true);
    return params.outputPath;
  } finally {
    inputDoc.dispose();
    outputDoc.dispose();
  }
}

Future<String> _imagesToPdfTask(_TaskParams params) async {
  final doc = PdfDocument();
  try {
    for (final path in params.inputPaths) {
      final imageBytes = await File(path).readAsBytes();
      final PdfBitmap bitmap = PdfBitmap(imageBytes);

      final section = doc.sections!.add();
      section.pageSettings.size = Size(
        bitmap.width.toDouble(),
        bitmap.height.toDouble(),
      );
      section.pageSettings.margins.all = 0;

      if (bitmap.width > bitmap.height) {
        section.pageSettings.orientation = PdfPageOrientation.landscape;
      } else {
        section.pageSettings.orientation = PdfPageOrientation.portrait;
      }

      final page = section.pages.add();
      page.graphics.drawImage(
        bitmap,
        Rect.fromLTWH(0, 0, bitmap.width.toDouble(), bitmap.height.toDouble()),
      );
    }
    final bytes = await doc.save();
    await File(params.outputPath).writeAsBytes(bytes, flush: true);
    return params.outputPath;
  } finally {
    doc.dispose();
  }
}

Future<String> _extractPagesTask(_TaskParams params) async {
  final inputBytes = await File(params.inputPaths.first).readAsBytes();
  final sourceDoc = PdfDocument(inputBytes: inputBytes);
  final targetDoc = PdfDocument();

  try {
    final List<int> pagesToExtract =
        (params.metadata!['pages'] as List<dynamic>).cast<int>();

    for (final pageIndex in pagesToExtract) {
      if (pageIndex < sourceDoc.pages.count) {
        final sourcePage = sourceDoc.pages[pageIndex];
        final template = sourcePage.createTemplate();
        final size = sourcePage.size;

        final section = targetDoc.sections!.add();
        section.pageSettings.margins.all = 0;
        section.pageSettings.size = size;
        section.pageSettings.orientation = size.width > size.height
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait;

        final page = section.pages.add();

        // 95% Anti-Clipping Rule
        const double scale = 0.95;
        final double drawWidth = size.width * scale;
        final double drawHeight = size.height * scale;
        final double offsetX = (size.width - drawWidth) / 2;
        final double offsetY = (size.height - drawHeight) / 2;

        page.graphics.drawPdfTemplate(
          template,
          Offset(offsetX, offsetY),
          Size(drawWidth, drawHeight),
        );
      }
    }

    final outputBytes = await targetDoc.save();
    await File(params.outputPath).writeAsBytes(outputBytes, flush: true);
    return params.outputPath;
  } finally {
    sourceDoc.dispose();
    targetDoc.dispose();
  }
}

Future<String> _organizeTask(_TaskParams params) async {
  final inputBytes = await File(params.inputPaths.first).readAsBytes();
  final sourceDoc = PdfDocument(inputBytes: inputBytes);
  final targetDoc = PdfDocument();

  try {
    final configs = params.metadata!['configurations'] as List<dynamic>;

    for (final item in configs) {
      final int pageIndex = item['index'] as int;
      final int rotationAngle = item['rotation'] as int;

      if (pageIndex < sourceDoc.pages.count) {
        final sourcePage = sourceDoc.pages[pageIndex];
        final PdfTemplate template = sourcePage.createTemplate();
        final originalSize = sourcePage.size;

        final targetSection = targetDoc.sections!.add();
        targetSection.pageSettings.margins.all = 0;

        // 1. Give the section the exact unrotated original size
        targetSection.pageSettings.size = originalSize;

        // 2. Set base orientation strictly based on original dimensions
        if (originalSize.width > originalSize.height) {
          targetSection.pageSettings.orientation = PdfPageOrientation.landscape;
        } else {
          targetSection.pageSettings.orientation = PdfPageOrientation.portrait;
        }

        final targetPage = targetSection.pages.add();

        // 3. Apply page-level viewport rotation
        switch (rotationAngle) {
          case 90:
            targetPage.rotation = PdfPageRotateAngle.rotateAngle90;
            break;
          case 180:
            targetPage.rotation = PdfPageRotateAngle.rotateAngle180;
            break;
          case 270:
            targetPage.rotation = PdfPageRotateAngle.rotateAngle270;
            break;
          default:
            targetPage.rotation = PdfPageRotateAngle.rotateAngle0;
            break;
        }

        // 4. 95% Anti-Clipping Rule (Scaled cleanly from center)
        const double scale = 0.95;
        final double drawWidth = originalSize.width * scale;
        final double drawHeight = originalSize.height * scale;
        final double offsetX = (originalSize.width - drawWidth) / 2;
        final double offsetY = (originalSize.height - drawHeight) / 2;

        // 5. Draw template with its true original aspect ratio
        targetPage.graphics.drawPdfTemplate(
          template,
          Offset(offsetX, offsetY),
          Size(drawWidth, drawHeight),
        );
      }
    }

    final outputBytes = await targetDoc.save();
    await File(params.outputPath).writeAsBytes(outputBytes, flush: true);
    return params.outputPath;
  } finally {
    sourceDoc.dispose();
    targetDoc.dispose();
  }
}

Future<String> _textToPdfTask(_TaskParams params) async {
  final doc = PdfDocument();
  try {
    final text = params.metadata!['text'] as String;
    final title = params.metadata!['title'] as String;

    final section = doc.sections!.add();
    section.pageSettings.margins.all = 36;
    final page = section.pages.add();

    final PdfFont titleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      18,
      style: PdfFontStyle.bold,
    );
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

    // Draw Title Header
    page.graphics.drawString(
      title,
      titleFont,
      brush: PdfSolidBrush(PdfColor(211, 47, 47)), // Primary Crimson accent
      bounds: const Rect.fromLTWH(0, 0, 500, 30),
    );

    // Enable multi-page pagination flow for long text! 📑
    final textElement = PdfTextElement(
      text: text,
      font: bodyFont,
      brush: PdfSolidBrush(PdfColor(40, 40, 40)),
    );

    final layoutFormat = PdfLayoutFormat(
      layoutType: PdfLayoutType.paginate,
      breakType: PdfLayoutBreakType.fitPage,
    );

    textElement.draw(
      page: page,
      bounds: Rect.fromLTWH(
        0,
        40,
        page.getClientSize().width,
        page.getClientSize().height - 40,
      ),
      format: layoutFormat,
    );

    final bytes = await doc.save();
    await File(params.outputPath).writeAsBytes(bytes, flush: true);
    return params.outputPath;
  } finally {
    doc.dispose();
  }
}

Future<String> _watermarkTask(_TaskParams params) async {
  final inputBytes = await File(params.inputPaths.first).readAsBytes();
  final inputDoc = PdfDocument(inputBytes: inputBytes);
  final outputDoc = PdfDocument();

  try {
    final bool isImage = params.metadata!['isImage'] as bool;
    final double opacity = (params.metadata!['opacity'] as num).toDouble();
    final double rotation = (params.metadata!['rotation'] as num).toDouble();

    PdfBitmap? watermarkImage;
    if (isImage && params.inputPaths.length > 1) {
      final imgBytes = await File(params.inputPaths[1]).readAsBytes();
      watermarkImage = PdfBitmap(imgBytes);
    }

    final double fontSize = (params.metadata!['fontSize'] as num).toDouble();
    final font = PdfStandardFont(
      PdfFontFamily.helvetica,
      fontSize,
      style: PdfFontStyle.bold,
    );
    final String text = params.metadata!['watermark'] as String;

    for (int i = 0; i < inputDoc.pages.count; i++) {
      final inputPage = inputDoc.pages[i];
      final template = inputPage.createTemplate();
      final size = inputPage.size;

      final section = outputDoc.sections!.add();
      section.pageSettings.margins.all = 0;
      section.pageSettings.size = size;

      if (size.width > size.height) {
        section.pageSettings.orientation = PdfPageOrientation.landscape;
      } else {
        section.pageSettings.orientation = PdfPageOrientation.portrait;
      }

      final page = section.pages.add();

      // 1. Draw original base page content safely
      const double scale = 0.95;
      final double drawWidth = size.width * scale;
      final double drawHeight = size.height * scale;
      final double offsetX = (size.width - drawWidth) / 2;
      final double offsetY = (size.height - drawHeight) / 2;

      page.graphics.drawPdfTemplate(
        template,
        Offset(offsetX, offsetY),
        Size(drawWidth, drawHeight),
      );

      // 2. Draw Transformed Watermark Overlay
      page.graphics.save();
      page.graphics.setTransparency(opacity);
      page.graphics.translateTransform(size.width / 2, size.height / 2);
      page.graphics.rotateTransform(rotation);

      if (isImage && watermarkImage != null) {
        final double imageScale = (params.metadata!['imageScale'] as num)
            .toDouble();
        final double imgW = size.width * imageScale;
        final double imgH =
            imgW * (watermarkImage.height / watermarkImage.width);

        page.graphics.drawImage(
          watermarkImage,
          Rect.fromLTWH(-imgW / 2, -imgH / 2, imgW, imgH),
        );
      } else {
        final sizeF = font.measureString(text);
        page.graphics.drawString(
          text,
          font,
          brush: PdfSolidBrush(PdfColor(130, 130, 130)),
          bounds: Rect.fromLTWH(
            -sizeF.width / 2,
            -sizeF.height / 2,
            sizeF.width,
            sizeF.height,
          ),
        );
      }

      page.graphics.restore();
    }

    final bytes = await outputDoc.save();
    await File(params.outputPath).writeAsBytes(bytes, flush: true);
    return params.outputPath;
  } finally {
    inputDoc.dispose();
    outputDoc.dispose();
  }
}
