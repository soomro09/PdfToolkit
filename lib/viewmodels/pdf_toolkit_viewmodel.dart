import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../feature/pdf_compress/models/compression_level.dart';
import '../models/pdf_document_model.dart';
import '../feature/pdf_compress/services/pdf_compress_service.dart';
import '../services/pdf_images_to_pdf_service.dart';
import '../services/pdf_merge_service.dart';
import '../services/pdf_security_service.dart';
import '../services/pdf_sign_service.dart';
import '../services/pdf_split_service.dart';
import 'recent_files_viewmodel.dart';

// UI Processing State
abstract class PdfToolkitState {
  const PdfToolkitState();
}

class PdfToolkitIdle extends PdfToolkitState {
  const PdfToolkitIdle();
}

class PdfToolkitProcessing extends PdfToolkitState {
  final String statusMessage;
  const PdfToolkitProcessing(this.statusMessage);
}

class PdfToolkitSuccess extends PdfToolkitState {
  final File resultFile;
  final String message;
  const PdfToolkitSuccess(this.resultFile, this.message);
}

class PdfToolkitError extends PdfToolkitState {
  final String errorMessage;
  const PdfToolkitError(this.errorMessage);
}

// ViewModel Provider
final pdfToolkitViewModelProvider =
StateNotifierProvider<PdfToolkitViewModel, PdfToolkitState>((ref) {
  return PdfToolkitViewModel(
    mergeService: PdfMergeService(),
    splitService: PdfSplitService(),
    compressService: PdfCompressService(),
    signService: PdfSignService(),
    securityService: PdfSecurityService(),
    imagesToPdfService: PdfImagesToPdfService(),
    ref: ref,
  );
});

class PdfToolkitViewModel extends StateNotifier<PdfToolkitState> {
  final PdfMergeService _mergeService;
  final PdfSplitService _splitService;
  final PdfCompressService _compressService;
  final PdfSignService _signService;
  final PdfSecurityService _securityService;
  final PdfImagesToPdfService _imagesToPdfService;
  final Ref _ref;

  PdfToolkitViewModel({
    required PdfMergeService mergeService,
    required PdfSplitService splitService,
    required PdfCompressService compressService,
    required PdfSignService signService,
    required PdfSecurityService securityService,
    required PdfImagesToPdfService imagesToPdfService,
    required Ref ref,
  })  : _mergeService = mergeService,
        _splitService = splitService,
        _compressService = compressService,
        _signService = signService,
        _securityService = securityService,
        _imagesToPdfService = imagesToPdfService,
        _ref = ref,
        super(const PdfToolkitIdle());

  void resetState() {
    state = const PdfToolkitIdle();
  }

  // --- Merge PDFs ---
  Future<void> mergeFiles(List<File> files, String outputName) async {
    state = const PdfToolkitProcessing('Merging PDF documents...');
    try {
      final outputFile = await PdfMergeService.mergePdfs(files, outputName);
      await _registerNewFile(outputFile);
      state = PdfToolkitSuccess(outputFile, 'Successfully merged ${files.length} PDFs');
    } catch (e) {
      state = PdfToolkitError('Failed to merge PDFs: $e');
    }
  }

  // --- Compress PDF ---
  Future<void> compressFile(File file, CompressionLevel level, String outputName) async {
    state = const PdfToolkitProcessing('Compressing PDF file...');
    try {
      final outputFile = await _compressService.compressPdf(
        inputFile: file,
        level: level,
        outputFileName: outputName,
      );
      await _registerNewFile(outputFile);
      state = PdfToolkitSuccess(outputFile, 'PDF compression complete');
    } catch (e) {
      state = PdfToolkitError('Failed to compress PDF: $e');
    }
  }

  // --- Encrypt / Protect PDF ---
  Future<void> encryptFile(File file, String password, String outputName) async {
    state = const PdfToolkitProcessing('Encrypting document with AES-256...');
    try {
      final outputFile = await _securityService.encryptPdf(
        inputFile: file,
        userPassword: password,
        outputFileName: outputName,
      );
      await _registerNewFile(outputFile);
      state = PdfToolkitSuccess(outputFile, 'PDF successfully password protected');
    } catch (e) {
      state = PdfToolkitError('Failed to protect PDF: $e');
    }
  }

  // --- Images to PDF ---
  Future<void> convertImages(List<File> imageFiles, String outputName) async {
    state = const PdfToolkitProcessing('Converting images to PDF layout...');
    try {
      final outputFile = await _imagesToPdfService.convertImagesToPdf(
        imageFiles: imageFiles,
        outputFileName: outputName,
      );
      await _registerNewFile(outputFile);
      state = PdfToolkitSuccess(outputFile, 'Converted ${imageFiles.length} images to PDF');
    } catch (e) {
      state = PdfToolkitError('Failed to convert images: $e');
    }
  }

  // Helper method to index generated PDFs directly into Hive database history
  Future<void> _registerNewFile(File file) async {
    final fileName = file.path.split('/').last;
    final fileLength = await file.length();

    final model = PdfDocumentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: fileName,
      path: file.path,
      pageCount: 1, // Updated upon reader load
      sizeInBytes: fileLength,
      lastAccessed: DateTime.now(),
    );

    await _ref.read(recentFilesViewModelProvider.notifier).addOrUpdateFile(model);
  }
}