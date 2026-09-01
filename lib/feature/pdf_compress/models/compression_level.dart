enum CompressionLevel {
  low(
    title: 'Low Compression',
    subtitle: 'Best visual quality, larger file size (~20% reduction)',
    badge: 'High Quality',
    scaleFactor: 1.8,
    jpegQuality: 75,
  ),
  medium(
    title: 'Recommended',
    subtitle: 'Balanced clarity and file size (~50% reduction)',
    badge: 'Popular',
    scaleFactor: 1.3,
    jpegQuality: 50,
  ),
  high(
    title: 'Extreme Compression',
    subtitle: 'Smallest possible size, lower image clarity (~75% reduction)',
    badge: 'Max Savings',
    scaleFactor: 1.0,
    jpegQuality: 30,
  );

  final String title;
  final String subtitle;
  final String badge;
  final double scaleFactor;
  final int jpegQuality;

  const CompressionLevel({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.scaleFactor,
    required this.jpegQuality,
  });
}