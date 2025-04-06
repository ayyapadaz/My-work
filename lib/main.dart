import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MusicPlayerPage(),
    );
  }
}

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key});

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<File> _audioFiles = [];
  bool _isPlaying = false;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    try {
      // Request audio permission for Android 13+
      var audioPermission = await Permission.audio.request();
      print('Audio permission status: $audioPermission');
      
      // Request storage permission for older Android versions
      var storagePermission = await Permission.storage.request();
      print('Storage permission status: $storagePermission');
      
      if (audioPermission.isGranted || storagePermission.isGranted) {
        await _loadAudioFiles();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Permissions denied. Please grant storage/audio access in settings.';
        });
        // Open app settings to let user grant permission
        openAppSettings();
      }
    } catch (e) {
      print('Error requesting permissions: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error requesting permissions: $e';
      });
    }
  }

  Future<void> _loadAudioFiles() async {
    try {
      // Get multiple possible storage locations
      final externalDir = await getExternalStorageDirectory();
      final downloadsDir = Directory('/storage/emulated/0/Download');
      final musicDir = Directory('/storage/emulated/0/Music');
      
      print('External directory: ${externalDir?.path}');
      print('Downloads directory: ${downloadsDir.path}');
      print('Music directory: ${musicDir.path}');

      List<File> allFiles = [];
      
      // Check each directory
      if (externalDir != null && await externalDir.exists()) {
        allFiles.addAll(await _findAudioFiles(externalDir));
      }
      
      if (await downloadsDir.exists()) {
        allFiles.addAll(await _findAudioFiles(downloadsDir));
      }
      
      if (await musicDir.exists()) {
        allFiles.addAll(await _findAudioFiles(musicDir));
      }

      print('Found ${allFiles.length} audio files');
      
      setState(() {
        _audioFiles = allFiles;
        _isLoading = false;
        if (_audioFiles.isEmpty) {
          _errorMessage = 'No audio files found in common directories';
        }
      });
    } catch (e) {
      print('Error loading audio files: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading audio files: $e';
      });
    }
  }

  Future<List<File>> _findAudioFiles(Directory directory) async {
    List<File> audioFiles = [];
    try {
      print('Scanning directory: ${directory.path}');
      await for (var entity in directory.list(recursive: true)) {
        if (entity is File) {
          String path = entity.path.toLowerCase();
          if (path.endsWith('.mp3') || path.endsWith('.wav') || path.endsWith('.m4a')) {
            print('Found audio file: $path');
            audioFiles.add(entity);
          }
        }
      }
    } catch (e) {
      print('Error scanning directory ${directory.path}: $e');
    }
    return audioFiles;
  }

  Future<void> _playAudio(File file) async {
    try {
      await _audioPlayer.setFilePath(file.path);
      await _audioPlayer.play();
      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      print('Error playing audio: $e');
      setState(() {
        _errorMessage = 'Error playing audio: $e';
      });
    }
  }

  Future<void> _pauseAudio() async {
    await _audioPlayer.pause();
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Player'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _audioFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No audio files found'),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ElevatedButton(
                        onPressed: _requestPermissions,
                        child: const Text('Grant Permissions'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _audioFiles.length,
                  itemBuilder: (context, index) {
                    final file = _audioFiles[index];
                    return ListTile(
                      title: Text(file.path.split('/').last),
                      subtitle: Text(file.path),
                      trailing: IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: () {
                          if (_isPlaying) {
                            _pauseAudio();
                          } else {
                            _playAudio(file);
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
