import 'dart:typed_data';

class PageOrganizeItem {
  final int originalIndex;
  final Uint8List thumbnailBytes;
  int rotationAngle; // 0, 90, 180, 270

  PageOrganizeItem({
    required this.originalIndex,
    required this.thumbnailBytes,
    this.rotationAngle = 0,
  });
}