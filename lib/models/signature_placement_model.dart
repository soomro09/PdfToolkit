import 'package:flutter/material.dart';

class SignaturePlacement {
  final int pageIndex;
  Offset position;
  Size size;
  final double aspectRatio; // 👈 Add this! (Width / Height)

  SignaturePlacement({
    required this.pageIndex,
    required this.position,
    required this.size,
    required this.aspectRatio,
  });
}
