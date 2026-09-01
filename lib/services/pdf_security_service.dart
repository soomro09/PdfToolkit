import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfSecurityService {
  /// Protects a PDF document with password security (AES 256-bit encryption).
  Future<File> encryptPdf({
    required File inputFile,
    required String userPassword,
    String? ownerPassword,
    required String outputFileName,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final outputPath = '${appDocDir.path}/$outputFileName.pdf';

    final resultPath = await compute(_executeEncryption, {
      'inputPath': inputFile.path,
      'outputPath': outputPath,
      'userPassword': userPassword,
      'ownerPassword': ownerPassword ?? userPassword,
    });

    return File(resultPath);
  }

  /// Removes password protection from an encrypted PDF using its valid password.
  Future<File> decryptPdf({
    required File inputFile,
    required String currentPassword,
    required String outputFileName,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final outputPath = '${appDocDir.path}/$outputFileName.pdf';

    final resultPath = await compute(_executeDecryption, {
      'inputPath': inputFile.path,
      'outputPath': outputPath,
      'password': currentPassword,
    });

    return File(resultPath);
  }

  static Future<String> _executeEncryption(Map<String, dynamic> params) async {
    final String inputPath = params['inputPath'];
    final String outputPath = params['outputPath'];
    final String userPassword = params['userPassword'];
    final String ownerPassword = params['ownerPassword'];

    final File inputFile = File(inputPath);
    final List<int> inputBytes = await inputFile.readAsBytes();

    final PdfDocument document = PdfDocument(inputBytes: inputBytes);

    try {
      // Configure AES-256 Bit Security Encryption settings
      final PdfSecurity security = document.security;
      security.userPassword = userPassword;
      security.ownerPassword = ownerPassword;
      security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

      // Permissions is a LIST of allowed flags — add what you want to permit.
      // Anything NOT added here is restricted by default.
      security.permissions.addAll([
        PdfPermissionsFlags.print,
        PdfPermissionsFlags.fullQualityPrint,
        PdfPermissionsFlags.copyContent,
        // editContent and editAnnotations intentionally omitted = restricted
      ]);

      final List<int> protectedBytes = await document.save();
      final File outputFile = File(outputPath);
      await outputFile.writeAsBytes(protectedBytes, flush: true);

      return outputPath;
    } finally {
      document.dispose();
    }
  }

  static Future<String> _executeDecryption(Map<String, dynamic> params) async {
    final String inputPath = params['inputPath'];
    final String outputPath = params['outputPath'];
    final String password = params['password'];

    final File inputFile = File(inputPath);
    final List<int> inputBytes = await inputFile.readAsBytes();

    // Pass password to unlock document instance
    final PdfDocument document = PdfDocument(
      inputBytes: inputBytes,
      password: password,
    );

    try {
      // Clear security configuration to export plain PDF
      document.security.userPassword = '';
      document.security.ownerPassword = '';

      final List<int> plainBytes = await document.save();
      final File outputFile = File(outputPath);
      await outputFile.writeAsBytes(plainBytes, flush: true);

      return outputPath;
    } finally {
      document.dispose();
    }
  }
}
