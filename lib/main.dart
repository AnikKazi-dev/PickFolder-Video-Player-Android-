import 'package:flutter/material.dart';
import 'screens/video_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PickFolderPlayerApp());
}

class PickFolderPlayerApp extends StatelessWidget {
  const PickFolderPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PickFolder Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const VideoListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
