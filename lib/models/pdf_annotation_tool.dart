// models/pdf_annotation_tool.dart
import 'package:flutter/material.dart';

enum AppPdfFont {
  helvetica,
  timesRoman,
  courier,
}

extension AppPdfFontExtension on AppPdfFont {
  String get displayName {
    switch (this) {
      case AppPdfFont.helvetica:
        return 'Modern';
      case AppPdfFont.timesRoman:
        return 'Formal';
      case AppPdfFont.courier:
        return 'Mono';
    }
  }

  TextStyle toTextStyle({
    required double fontSize,
    required Color color,
    required bool isBold,
    required bool isItalic,
    required bool isUnderline,
  }) {
    String? family;
    switch (this) {
      case AppPdfFont.helvetica:
        family = null; // System sans-serif default
        break;
      case AppPdfFont.timesRoman:
        family = 'serif';
        break;
      case AppPdfFont.courier:
        family = 'monospace';
        break;
    }

    return TextStyle(
      fontFamily: family,
      fontSize: fontSize,
      color: color,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
    );
  }
}

class EditableTextOverlay {
  final String id;
  final int pageIndex;
  String text;
  Offset position;
  double fontSize;
  Color color;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  AppPdfFont fontFamily;

  EditableTextOverlay({
    required this.id,
    required this.pageIndex,
    required this.text,
    required this.position,
    required this.fontSize,
    required this.color,
    this.isBold = true,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontFamily = AppPdfFont.helvetica,
  });
}