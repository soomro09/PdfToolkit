import 'package:hive_flutter/hive_flutter.dart';
import '../models/pdf_document_model.dart';

class LocalStorageService {
  static const String _recentBoxName = 'recent_pdf_files';

  /// Initializes Hive storage and opens necessary boxes
  Future<void> init() async {
    await Hive.initFlutter();

    // Register custom Hive adapter for PdfDocumentModel if using type adapters,
    // or store as raw JSON maps for high reliability & zero code-gen overhead.
    await Hive.openBox<Map<dynamic, dynamic>>(_recentBoxName);
  }

  Box<Map<dynamic, dynamic>> get _box => Hive.box<Map<dynamic, dynamic>>(_recentBoxName);

  /// Saves or updates a PDF document record in local storage
  Future<void> saveRecentFile(PdfDocumentModel file) async {
    final fileData = {
      'id': file.id,
      'name': file.name,
      'path': file.path,
      'pageCount': file.pageCount,
      'sizeInBytes': file.sizeInBytes,
      'lastAccessed': file.lastAccessed.toIso8601String(),
      'isFavorite': file.isFavorite,
      'thumbnailPath': file.thumbnailPath,
    };
    await _box.put(file.id, fileData);
  }

  /// Fetches all stored recent PDF records ordered by last accessed date
  List<PdfDocumentModel> getRecentFiles() {
    final rawList = _box.values.toList();

    final documents = rawList.map((map) {
      return PdfDocumentModel(
        id: map['id'] as String,
        name: map['name'] as String,
        path: map['path'] as String,
        pageCount: map['pageCount'] as int,
        sizeInBytes: map['sizeInBytes'] as int,
        lastAccessed: DateTime.parse(map['lastAccessed'] as String),
        isFavorite: (map['isFavorite'] as bool?) ?? false,
        thumbnailPath: map['thumbnailPath'] as String?,
      );
    }).toList();

    // Sort descending (most recent first)
    documents.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
    return documents;
  }

  /// Toggles favorite status for a stored document
  Future<void> toggleFavorite(String fileId) async {
    final rawData = _box.get(fileId);
    if (rawData != null) {
      final updatedData = Map<dynamic, dynamic>.from(rawData);
      updatedData['isFavorite'] = !(updatedData['isFavorite'] as bool? ?? false);
      await _box.put(fileId, updatedData);
    }
  }

  /// Removes a file entry from local metadata database
  Future<void> removeRecentFile(String fileId) async {
    await _box.delete(fileId);
  }

  /// Clears all recent files metadata
  Future<void> clearHistory() async {
    await _box.clear();
  }
}