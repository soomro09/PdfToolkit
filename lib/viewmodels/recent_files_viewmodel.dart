import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/pdf_document_model.dart';
import '../services/local_storage_service.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final recentFilesViewModelProvider =
StateNotifierProvider<RecentFilesViewModel, List<PdfDocumentModel>>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return RecentFilesViewModel(storageService);
});

class RecentFilesViewModel extends StateNotifier<List<PdfDocumentModel>> {
  final LocalStorageService _storageService;

  RecentFilesViewModel(this._storageService) : super([]) {
    loadRecentFiles();
  }

  void loadRecentFiles() {
    state = _storageService.getRecentFiles();
  }

  Future<void> addOrUpdateFile(PdfDocumentModel file) async {
    await _storageService.saveRecentFile(file);
    loadRecentFiles();
  }

  Future<void> toggleFavorite(String fileId) async {
    await _storageService.toggleFavorite(fileId);
    loadRecentFiles();
  }

  Future<void> deleteFileRecord(String fileId) async {
    await _storageService.removeRecentFile(fileId);
    loadRecentFiles();
  }

  Future<void> clearAll() async {
    await _storageService.clearHistory();
    state = [];
  }
}