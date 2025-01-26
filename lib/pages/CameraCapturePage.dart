import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class CameraCapturePage extends StatefulWidget {
  @override
  _CameraCapturePageState createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  late CameraController _controller;
  late List<CameraDescription> _cameras;
  bool _isCameraInitialized = false;
  String? _capturedImagePath;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Get available cameras
    _cameras = await availableCameras();

    // Select the first camera (usually the rear camera)
    _controller = CameraController(
      _cameras[0],
      ResolutionPreset.max, // Use high resolution for fingerprint capture
    );

    // Initialize the camera
    await _controller.initialize();

    // Mark camera as initialized
    setState(() {
      _isCameraInitialized = true;
    });
  }

  Future<void> _captureImage() async {
    if (!_controller.value.isInitialized) return;

    try {
      // Capture the image and save it
      final XFile image = await _controller.takePicture();

      setState(() {
        _capturedImagePath = image.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image captured: ${image.path}')),
      );
    } catch (e) {
      print('Error capturing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: $e')),
      );
    }
  }

  @override
  void dispose() {
    // Dispose the camera controller when not needed
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Capture Fingerprint')),
      body: _isCameraInitialized
          ? Column(
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: CameraPreview(_controller),
          ),
          if (_capturedImagePath != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text('Captured Image:'),
                  Image.file(File(_capturedImagePath!)),
                ],
              ),
            ),
        ],
      )
          : Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureImage,
        child: Icon(Icons.camera),
      ),
    );
  }
}