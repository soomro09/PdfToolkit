import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PdfStorageHelper {

  /// 1. Save directly to Android Public Downloads / iOS Documents 💾
  static Future<File> saveToPublicStorage(File tempPdfFile, String customName) async {
    Directory? storageDir;

    if (Platform.isAndroid) {
      // Save directly to Android Downloads folder
      storageDir = Directory('/storage/emulated/0/Download');
      if (!await storageDir.exists()) {
        storageDir = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      // Save to iOS Documents folder (visible in Files App)
      storageDir = await getApplicationDocumentsDirectory();
    }

    final String newPath = '${storageDir!.path}/$customName.pdf';
    final File savedFile = await tempPdfFile.copy(newPath);

    return savedFile;
  }

  /// 2. Open Native "Save to Files" / Export Picker 📤
  static Future<void> saveWithFilePicker(File pdfFile) async {
    final xFile = XFile(pdfFile.path);
    await Share.shareXFiles(
      [xFile],
      text: 'Here is your PDF document 📄',
    );
  }
}