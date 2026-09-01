import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/pdf_document_model.dart';

final recentFilesProvider = StateNotifierProvider<RecentFilesController, List<PdfDocumentModel>>((ref) {
  return RecentFilesController();
});

class RecentFilesController extends StateNotifier<List<PdfDocumentModel>> {
  RecentFilesController() : super([]) {
    _loadRecentFiles();
  }

  static const String _storageKey = 'recent_pdf_files';

  Future<void> _loadRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);

    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      state = decoded.map((item) => PdfDocumentModel.fromJson(item)).toList();
    }
  }

  Future<void> addFile(PdfDocumentModel file) async {
    // Remove if it already exists to prevent duplicates, then add to the top
    final currentFiles = state.where((f) => f.path != file.path).toList();
    currentFiles.insert(0, file);

    // Keep only the 10 most recent files so storage doesn't bloat
    if (currentFiles.length > 10) {
      currentFiles.removeLast();
    }

    state = currentFiles;
    await _saveToStorage(currentFiles);
  }

  Future<void> removeFile(String id) async {
    final currentFiles = state.where((f) => f.id != id).toList();
    state = currentFiles;
    await _saveToStorage(currentFiles);
  }

  Future<void> _saveToStorage(List<PdfDocumentModel> files) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(files.map((f) => f.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}