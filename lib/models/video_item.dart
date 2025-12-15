class VideoItem {
  final String name;
  final String path;
  final int size;
  final DateTime lastModified;

  VideoItem({
    required this.name,
    required this.path,
    required this.size,
    required this.lastModified,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedDuration {
    // Placeholder - actual duration would require video metadata parsing
    return '';
  }
}
