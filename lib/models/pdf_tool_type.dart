// lib/models/pdf_tool_type.dart

enum PdfToolType {
  merge,
  split,
  compress,
  sign,
  protect,
  imagesToPdf,
  scanner,
  textToPdf,
  pdfToText,
  pdfToJpg,
  watermark,
  organizePdf,
  editPdf,
  unlockPdf,
}

extension PdfToolTypeExtension on PdfToolType {
  String get title {
    switch (this) {
      case PdfToolType.merge:
        return 'Merge PDFs';
      case PdfToolType.split:
        return 'Split PDF';
      case PdfToolType.compress:
        return 'Compress PDF';
      case PdfToolType.sign:
        return 'Sign PDF';
      case PdfToolType.protect:
        return 'Protect PDF';
      case PdfToolType.unlockPdf:
        return 'Unlock PDF';
      case PdfToolType.imagesToPdf:
        return 'Images to PDF';
      case PdfToolType.scanner:
        return 'Document Scanner';
      case PdfToolType.textToPdf:
        return 'Text to PDF';
      case PdfToolType.pdfToText:
        return 'PDF to Text';
      case PdfToolType.pdfToJpg:
        return 'PDF to JPG';
      case PdfToolType.watermark:
        return 'Add Watermark';
      case PdfToolType.organizePdf:
        return 'Organize Pages';
      case PdfToolType.editPdf:
        return 'Edit & Annotate';
    }
  }

  String get description {
    switch (this) {
      case PdfToolType.merge:
        return 'Select 2 or more PDF files to combine into one.';
      case PdfToolType.split:
        return 'Select a PDF document to extract page ranges.';
      case PdfToolType.compress:
        return 'Select a PDF to downsample images & reduce file size.';
      case PdfToolType.sign:
        return 'Select a PDF to add your handwritten signature.';
      case PdfToolType.protect:
        return 'Select a PDF to lock with AES-256 encryption.';
      case PdfToolType.unlockPdf:
        return 'Remove passwords and security restrictions from a protected PDF.';
      case PdfToolType.imagesToPdf:
        return 'Select photos from gallery to build a new PDF.';
      case PdfToolType.scanner:
        return 'Scan physical papers using your camera.';
      case PdfToolType.textToPdf:
        return 'Convert raw text strings or files into a formatted PDF.';
      case PdfToolType.pdfToText:
        return 'Extract all readable text blocks from a PDF.';
      case PdfToolType.pdfToJpg:
        return 'Export PDF pages into high-resolution JPG images.';
      case PdfToolType.watermark:
        return 'Stamp custom text or image watermarks over your PDF.';
      case PdfToolType.organizePdf:
        return 'Rearrange, rotate, or delete pages interactively.';
      case PdfToolType.editPdf:
        return 'Add text boxes, notes, highlights, and annotations to any page.';
    }
  }

  int get minFiles => (this == PdfToolType.merge) ? 2 : 1;

  bool get allowMultiple =>
      this == PdfToolType.merge || this == PdfToolType.imagesToPdf;
}
