import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/pdf_engine_service.dart';
import '../../pdf_compress/models/compression_level.dart';
import '../../pdf_compress/services/pdf_compress_service.dart';

final pdfTaskControllerProvider = AsyncNotifierProvider<PdfTaskController, List<File>?>(PdfTaskController.new);

class PdfTaskController extends AsyncNotifier<List<File>?> {
  @override
  Future<List<File>?> build() async => null;

  Future<void> executeMerge(List<File> files) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await PdfEngineService.mergePdfs(files);
      return [result];
    });
  }

  Future<void> executeSplit(File file) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await PdfEngineService.splitPdf(file);
    });
  }

  Future<void> executeCompress(File file, CompressionLevel level) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await PdfEngineService.compressPdf(file, level);
      return [result];
    });
  }

  Future<void> executeProtect(File file, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await PdfEngineService.protectPdf(file, password);
      return [result];
    });
  }

  Future<void> executeImagesToPdf(List<File> images) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await PdfEngineService.imagesToPdf(images);
      return [result];
    });
  }
}