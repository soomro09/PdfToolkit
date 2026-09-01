class PdfDocumentModel {
  final String id;
  final String name;
  final String path;
  final int pageCount;
  final int sizeInBytes;
  final DateTime lastAccessed;
  final bool isFavorite;
  final String? thumbnailPath;

  PdfDocumentModel({
    required this.id,
    required this.name,
    required this.path,
    required this.pageCount,
    required this.sizeInBytes,
    required this.lastAccessed,
    this.isFavorite = false,
    this.thumbnailPath,
  });

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  PdfDocumentModel copyWith({
    String? id,
    String? name,
    String? path,
    int? pageCount,
    int? sizeInBytes,
    DateTime? lastAccessed,
    bool? isFavorite,
    String? thumbnailPath,
  }) {
    return PdfDocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      pageCount: pageCount ?? this.pageCount,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      isFavorite: isFavorite ?? this.isFavorite,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  // 👇 JSON Serialization for Local Storage! 💾 👇

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'pageCount': pageCount,
      'sizeInBytes': sizeInBytes,
      'lastAccessed': lastAccessed.toIso8601String(),
      'isFavorite': isFavorite,
      'thumbnailPath': thumbnailPath,
    };
  }

  factory PdfDocumentModel.fromJson(Map<String, dynamic> json) {
    return PdfDocumentModel(
      id: json['id'],
      name: json['name'],
      path: json['path'],
      pageCount: json['pageCount'],
      sizeInBytes: json['sizeInBytes'],
      lastAccessed: DateTime.parse(json['lastAccessed']),
      isFavorite: json['isFavorite'] ?? false, // Defaults to false if missing
      thumbnailPath: json['thumbnailPath'],
    );
  }
}