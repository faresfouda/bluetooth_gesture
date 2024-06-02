import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Media Player',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MediaPlayerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MediaPlayerScreen extends StatefulWidget {
  @override
  _MediaPlayerScreenState createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  BluetoothConnection? _connection;
  String _statusText = "Connecting to Bluetooth...";
  int _volume = 5;
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);
  List<String> _songTitles = []; // List to store song titles

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  void _requestPermissions() async {
    var status = await Permission.bluetooth.request();
    if (status.isGranted) {
      _connectBluetooth();
    } else {
      setState(() {
        _statusText = "Bluetooth permission denied";
      });
    }

    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.location.request();
    await Permission.storage.request();
  }

  void _connectBluetooth() async {
    try {
      setState(() {
        _statusText = "Attempting to connect to Bluetooth...";
      });
      print('Attempting to connect to Bluetooth...');
      BluetoothConnection connection = await BluetoothConnection.toAddress('00:21:09:01:08:09'); // Replace with your Bluetooth device address
      setState(() {
        _connection = connection;
        _statusText = "Connected to Bluetooth";
      });
      _listenToBluetooth();
    } catch (e) {
      print('Failed to connect to Bluetooth: $e');
      setState(() {
        _statusText = "Failed to connect to Bluetooth";
      });
    }
  }

  void _listenToBluetooth() {
    _connection?.input?.listen((Uint8List data) {
      String command = String.fromCharCodes(data).trim();
      _handleCommand(command);
    }).onDone(() {
      setState(() {
        _statusText = "Bluetooth disconnected";
      });
    });
  }

  void _handleCommand(String command) {
    print('Received command: $command');  // Debugging statement
    switch (command) {
      case 'Left':
        _previousSong();
        break;
      case 'Right':
        _nextSong();
        break;
      case 'Up':
        _volumeUp();
        break;
      case 'Down':
        _volumeDown();
        break;
      case 'anti-clockwise':
        _pause();
      case 'Clockwise':
        _play();
        break;
      default:
        print('Unknown command: $command');  // Debugging statement
        break;
    }
  }

  void _previousSong() {
    if (_playlist.length > 1) {
      _audioPlayer.seekToPrevious();
      print('Previous song');
    } else {
      print('Playlist has less than 2 songs.');
    }
  }

  void _nextSong() {
    if (_playlist.length > 1) {
      _audioPlayer.seekToNext();
      print('Next song');
    } else {
      print('Playlist has less than 2 songs.');
    }
  }

  void _volumeUp() {
    if (_volume < 10) {
      setState(() {
        _volume += 1;
        _audioPlayer.setVolume(_volume / 10);
        print('Volume up: $_volume');
      });
    }
  }

  void _volumeDown() {
    if (_volume > 0) {
      setState(() {
        _volume -= 1;
        _audioPlayer.setVolume(_volume / 10);
        print('Volume down: $_volume');
      });
    }
  }

  void _pause() {
    _audioPlayer.pause();
  }

  void _play() {
    _audioPlayer.play();
  }

  Future<void> _pickFiles() async {
    if (await Permission.storage.request().isGranted) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'pls', 'mp3'], // Add more if needed
        allowMultiple: true,
      );

      if (result != null) {
        List<AudioSource> newPlaylist = [];
        List<String> newSongTitles = [];

        for (var file in result.files) {
          String path = file.path!;
          if (path.isNotEmpty) {
            newPlaylist.add(AudioSource.uri(Uri.file(path)));
            newSongTitles.add(file.name); // Add file name to the song titles list
          }
        }

        if (newPlaylist.isNotEmpty) {
          _playlist.clear();
          _playlist.addAll(newPlaylist);

          setState(() {
            _songTitles = newSongTitles; // Update song titles in the state
          });

          try {
            await _audioPlayer.setAudioSource(_playlist);
            print('Audio source set, attempting to play...');
            await _audioPlayer.play(); // Ensure play is called after setting the audio source
          } catch (e) {
            print("Error setting audio source: $e");
          }
        }
      }
    } else {
      print("Storage permission denied");
    }
  }

  Future<List<String>> _parsePlaylistFile(File playlistFile) async {
    List<String> audioFilePaths = [];

    try {
      List<String> lines = await playlistFile.readAsLines();

      for (String line in lines) {
        if (line.isNotEmpty && !line.startsWith('#')) {
          // Ignore empty lines and comments
          audioFilePaths.add(line.trim());
        }
      }
    } catch (e) {
      print("Error parsing playlist file: $e");
    }

    return audioFilePaths;
  }

  Future<void> _sendAudioFile(String filePath) async {
    File file = File(filePath);
    Uint8List fileBytes = await file.readAsBytes();
    _sendDataInChunks(fileBytes);
  }

  void _sendDataInChunks(Uint8List data, {int chunkSize = 20}) async {
    for (int i = 0; i < data.length; i += chunkSize) {
      int end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
      Uint8List chunk = data.sublist(i, end);
      _connection?.output.add(chunk);
      await _connection?.output.allSent;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CCE LVL300'),
        actions: [
          IconButton(
            iconSize: 40, // Adjust icon size as needed
            icon: Icon(Icons.folder_open),
            onPressed: _pickFiles,
          ),
          IconButton(
            iconSize: 40,
            icon: Icon(Icons.refresh),
            onPressed: () {
              _connectBluetooth();
              setState(() {}); // Refresh the UI
            },
          ),
        ],
        centerTitle: true,
      ),
      body: Column(
        children: [
          Text(_statusText),
          Expanded(
            child: ListView.builder(
              itemCount: _songTitles.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_songTitles[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              'Created by: Team 7-Segment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              iconSize: 40,
              icon: Icon(Icons.skip_previous),
              onPressed: _previousSong,
            ),
            IconButton(
              iconSize: 40,
              icon: Icon(Icons.play_arrow),
              onPressed: _play,
            ),
            IconButton(
              iconSize: 40,
              icon: Icon(Icons.pause),
              onPressed: _pause,
            ),
            IconButton(
              iconSize: 40,
              icon: Icon(Icons.skip_next),
              onPressed: _nextSong,
            ),
          ],
        ),
      ),
    );
  }
}
