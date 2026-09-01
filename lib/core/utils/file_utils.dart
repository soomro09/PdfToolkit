import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  /// Converts raw byte integers into human-readable strings (KB, MB, GB)
  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes > 0) ? (bytes.toString().length - 1) ~/ 3 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double num = bytes / (1 << (i * 10));
    return '${num.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Generates a timestamped filename for processed files
  static String generateOutputFileName(String prefix, [String extension = 'pdf']) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_$timestamp.$extension';
  }

  /// Extracts clean file name without path directory
  static String getFileName(String path) {
    return path.split('/').last;
  }

  /// Extracts file name without extension
  static String getFileNameWithoutExtension(String path) {
    final fileName = getFileName(path);
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex == -1) return fileName;
    return fileName.substring(0, lastDotIndex);
  }

  /// Returns target directory for saving generated PDF files
  static Future<Directory> getAppOutputDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${appDocDir.path}/PDF_Toolkit');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  /// Checks if file path exists on storage
  static Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  /// Deletes local file safely
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }
}