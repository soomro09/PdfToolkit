// lib/models/signature_placement_model.dart
import 'package:flutter/material.dart';

class SignaturePlacement {
  final int pageIndex;
  Offset position;
  Size size;

  SignaturePlacement({
    required this.pageIndex,
    required this.position,
    required this.size,
  });
}