import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:pickfolder_player/models/video_item.dart';
import 'package:pickfolder_player/utils/video_scanner.dart';

class VideoListScreen extends StatefulWidget {
  const VideoListScreen({super.key});

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  List<VideoItem> _videos = [];
  String? _selectedFolderPath;
  bool _isLoading = false;
  bool _shuffleEnabled = false;
  bool _autoplayEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedFolderPath = prefs.getString('selected_folder');
      _shuffleEnabled = prefs.getBool('shuffle_enabled') ?? false;
      _autoplayEnabled = prefs.getBool('autoplay_enabled') ?? true;
    });

    if (_selectedFolderPath != null) {
      await _scanFolder(_selectedFolderPath!);
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedFolderPath != null) {
      await prefs.setString('selected_folder', _selectedFolderPath!);
    }
    await prefs.setBool('shuffle_enabled', _shuffleEnabled);
    await prefs.setBool('autoplay_enabled', _autoplayEnabled);
  }

  Future<void> _pickFolder() async {
    try {
      // Request storage permission
      PermissionStatus status;
      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isGranted) {
          status = PermissionStatus.granted;
        } else {
          status = await Permission.manageExternalStorage.request();
          if (status.isDenied) {
            // Try legacy storage permission
            status = await Permission.storage.request();
          }
        }
        
        if (status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission is required. Please enable it in settings.'),
                duration: Duration(seconds: 4),
              ),
            );
            await openAppSettings();
          }
          return;
        }
        
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission denied')),
            );
          }
          return;
        }
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        print('Selected folder: $selectedDirectory');
        setState(() {
          _selectedFolderPath = selectedDirectory;
        });
        await _savePreferences();
        await _scanFolder(selectedDirectory);
      }
    } catch (e) {
      print('Error picking folder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting folder: $e')),
        );
      }
    }
  }

  Future<void> _scanFolder(String folderPath) async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Scanning folder: $folderPath');
      final videos = await VideoScanner.scanDirectory(folderPath);
      print('Found ${videos.length} videos');
      setState(() {
        _videos = videos;
        if (_shuffleEnabled) {
          _videos.shuffle();
        }
      });
      
      if (videos.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No video files found in this folder')),
        );
      }
    } catch (e) {
      print('Error scanning folder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning folder: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleShuffle() {
    setState(() {
      _shuffleEnabled = !_shuffleEnabled;
      if (_shuffleEnabled) {
        _videos.shuffle();
      } else if (_selectedFolderPath != null) {
        _scanFolder(_selectedFolderPath!);
      }
    });
    _savePreferences();
  }

  void _toggleAutoplay() {
    setState(() {
      _autoplayEnabled = !_autoplayEnabled;
    });
    _savePreferences();
  }

  void _playVideo(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videos: _videos,
          initialIndex: index,
          autoplayEnabled: _autoplayEnabled,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PickFolder Player'),
        actions: [
          IconButton(
            icon: Icon(
              _shuffleEnabled ? Icons.shuffle_on_outlined : Icons.shuffle,
              color: _shuffleEnabled ? Colors.blue : null,
            ),
            onPressed: _toggleShuffle,
            tooltip: 'Shuffle',
          ),
          IconButton(
            icon: Icon(
              _autoplayEnabled ? Icons.playlist_play : Icons.playlist_remove,
              color: _autoplayEnabled ? Colors.blue : null,
            ),
            onPressed: _toggleAutoplay,
            tooltip: 'Autoplay',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Select Folder'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                if (_selectedFolderPath != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Folder: $_selectedFolderPath',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_videos.length} video(s) found',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _videos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_library_outlined,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFolderPath == null
                                  ? 'Select a folder to get started'
                                  : 'No videos found in selected folder',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _videos.length,
                        itemBuilder: (context, index) {
                          final video = _videos[index];
                          return ListTile(
                            leading: const Icon(Icons.play_circle_outline),
                            title: Text(video.name),
                            subtitle: Text(
                              video.formattedSize,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: Text(
                              video.formattedDuration,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onTap: () => _playVideo(index),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// Video Player Screen
class VideoPlayerScreen extends StatefulWidget {
  final List<VideoItem> videos;
  final int initialIndex;
  final bool autoplayEnabled;

  const VideoPlayerScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
    required this.autoplayEnabled,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final videoFile = File(widget.videos[_currentIndex].path);
    _controller = VideoPlayerController.file(videoFile);

    await _controller.initialize();

    _controller.addListener(() {
      if (_controller.value.position >= _controller.value.duration) {
        if (widget.autoplayEnabled &&
            _currentIndex < widget.videos.length - 1) {
          _playNext();
        }
      }

      setState(() {
        _isPlaying = _controller.value.isPlaying;
      });
    });

    if (mounted) {
      setState(() {});
      _controller.play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _playNext() {
    if (_currentIndex < widget.videos.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _controller.dispose();
      _initializeVideo();
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _controller.dispose();
      _initializeVideo();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentVideo = widget.videos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _showControls
          ? AppBar(
              title: Text(
                currentVideo.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              backgroundColor: Colors.black87,
            )
          : null,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(),
            ),
            if (_showControls) ...[
              Center(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 64,
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: _playPause,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black87,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_controller.value.isInitialized)
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.blue,
                            bufferedColor: Colors.grey,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            Text(
                              _controller.value.isInitialized
                                  ? _formatDuration(_controller.value.position)
                                  : '00:00',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const Text(
                              ' / ',
                              style: TextStyle(color: Colors.white70),
                            ),
                            Text(
                              _controller.value.isInitialized
                                  ? _formatDuration(_controller.value.duration)
                                  : '00:00',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.skip_previous),
                              color: _currentIndex > 0
                                  ? Colors.white
                                  : Colors.grey,
                              onPressed:
                                  _currentIndex > 0 ? _playPrevious : null,
                            ),
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                              ),
                              color: Colors.white,
                              onPressed: _playPause,
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next),
                              color: _currentIndex < widget.videos.length - 1
                                  ? Colors.white
                                  : Colors.grey,
                              onPressed:
                                  _currentIndex < widget.videos.length - 1
                                      ? _playNext
                                      : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
