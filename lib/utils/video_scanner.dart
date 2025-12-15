import 'dart:io';
import '../models/video_item.dart';

class VideoScanner {
  static final List<String> _videoExtensions = [
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.wmv',
    '.flv',
    '.webm',
    '.m4v',
    '.3gp',
    '.mpeg',
    '.mpg',
  ];

  static Future<List<VideoItem>> scanDirectory(String path) async {
    final directory = Directory(path);
    final List<VideoItem> videos = [];

    print('Checking if directory exists: $path');
    if (!await directory.exists()) {
      print('Directory does not exist!');
      return videos;
    }

    print('Directory exists, starting scan...');
    try {
      await for (var entity in directory.list(recursive: true)) {
        print('Found entity: ${entity.path}');
        if (entity is File) {
          if (entity.path.contains('.')) {
            final extension = entity.path.toLowerCase().substring(
                  entity.path.lastIndexOf('.'),
                );
            print('File extension: $extension');

            if (_videoExtensions.contains(extension)) {
              print('Video file found: ${entity.path}');
              final stat = await entity.stat();
              videos.add(
                VideoItem(
                  name: entity.path.split(Platform.pathSeparator).last,
                  path: entity.path,
                  size: stat.size,
                  lastModified: stat.modified,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error scanning directory: $e');
      print('Stack trace: ${StackTrace.current}');
    }

    print('Total videos found: ${videos.length}');
    // Sort by name
    videos.sort((a, b) => a.name.compareTo(b.name));

    return videos;
  }
}
