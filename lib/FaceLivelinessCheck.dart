import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:evisa_temp/fingerprint/fingerprintCapture.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class Facelivelinesscheck extends StatefulWidget {
  @override
  _FacelivelinesscheckState createState() => _FacelivelinesscheckState();
}

class _FacelivelinesscheckState extends State<Facelivelinesscheck> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _currentCommand = "Look Forward";
  List<String> _commands = [
    "Look Forward",
    "Look Left",
    "Look Right",
    "smile",
    "head still, eyes left",
    "head still, eyes right"
  ];
  int _commandIndex = 0;
  String _statusMessage = "Initializing...";
  bool _isVerified = false;
  Timer? _apiCheckTimer;
  List<File> _clickedImages = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      _cameraController = CameraController(cameras[1], ResolutionPreset.medium);
      await _cameraController.initialize();
      setState(() {
        _isCameraInitialized = true;
        _statusMessage = "Follow the command: $_currentCommand";
      });

      // Start periodic API checks
      _startApiCheck();
    } catch (e) {
      setState(() {
        _statusMessage = "Camera initialization failed. Please restart.";
      });
    }
  }

  void _startApiCheck() {
    _apiCheckTimer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
      if (_isProcessing) return;
      _isProcessing = true;

      try {
        final image = await _captureImage();
        if (image != null) {
          final result = await _sendToApi(image, _currentCommand);

          if (result) {
            setState(() {
              _statusMessage = "Hold still...";
            });

            await Future.delayed(Duration(seconds: 3));
            final capturedImage = await _captureImage();
            if (capturedImage != null) {
              _clickedImages.add(capturedImage);
            }

            _commandIndex++;
            if (_commandIndex < _commands.length) {
              setState(() {
                _currentCommand = _commands[_commandIndex];
                _statusMessage = "Follow the command: $_currentCommand";
              });
            } else {
              _stopApiCheck();
              _showImagesPage();
            }
          } else {
            setState(() {
              _statusMessage = "Please follow the command: $_currentCommand";
            });
          }
        }
      } catch (e) {
        setState(() {
          _statusMessage = "Error: $e";
        });
      } finally {
        _isProcessing = false;
      }
    });
  }

  void _showImagesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text("Review Clicked Images"),
            backgroundColor: Colors.blueAccent,
          ),
          body: Column(
            children: [
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _clickedImages.length,
                  itemBuilder: (context, index) {
                    return Image.file(_clickedImages[index]);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Retry
                    },
                    child: Text("Retry"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => fingerprintCapture(),
                        ),
                      );
                    },
                    child: Text("Confirm"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<File?> _captureImage() async {
    try {
      final XFile file = await _cameraController.takePicture();
      return File(file.path);
    } catch (e) {
      print("Error capturing image: $e");
      return null;
    }
  }

  Future<bool> _sendToApi(File file, String command) async {
    final uri = Uri.parse("http://127.0.0.1:8000/detect-emotion/");
    final request = http.MultipartRequest("POST", uri)
      ..fields['emotion'] = command
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);
      return json['result'] == true;
    } else {
      throw Exception("Could Not Find Face");
    }
  }

  void _stopApiCheck() {
    _apiCheckTimer?.cancel();
    _apiCheckTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Face Liveliness Check"),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isCameraInitialized
          ? Stack(
              children: [
                Positioned.fill(
                  child: CameraPreview(_cameraController),
                ),
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        color: Colors.black54,
                        child: Text(
                          "Follow the instructions on screen",
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        color: Colors.black54,
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 18,
                            color: _isVerified ? Colors.green : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: CircularProgressIndicator(
                color: Colors.blueAccent,
              ),
            ),
    );
  }

  @override
  void dispose() {
    _stopApiCheck();
    _cameraController.dispose();
    super.dispose();
  }
}
