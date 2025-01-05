import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'done.dart';

class FingerprintProcessor extends StatefulWidget {
  const FingerprintProcessor({super.key});

  @override
  State<FingerprintProcessor> createState() => _FingerprintProcessorState();
}

class _FingerprintProcessorState extends State<FingerprintProcessor> {
  File? _image;
  final picker = ImagePicker();
  Map<String, String> fingerprints = {};
  List<Map<String, String>> allFingerprints = [];
  bool isLoading = false;

  // API Endpoint for FastAPI running locally (accessible via adb reverse)
  final String apiEndpoint = 'http://127.0.0.1:8000/process-fingerprints/';

  // Pick image from gallery or camera
  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      await _uploadImage();
    } else {
      _showError('No image selected');
    }
  }

  // Upload image to FastAPI endpoint
  Future<void> _uploadImage() async {
    if (_image == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      var uri = Uri.parse(apiEndpoint);
      var request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', _image!.path));

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var data = json.decode(responseBody);
        if (data['status'] == 'success') {
          setState(() {
            fingerprints = Map<String, String>.from(data['images']);
            allFingerprints.add(fingerprints); // Store each set of fingerprints
          });
        } else {
          _showError(data['message'] ?? 'Error processing image');
        }
      } else {
        _showError('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Show all stored fingerprints
  void _viewAllFingerprints() {
    showDialog(
      context: context,
      builder: (context) {
        List<String> keys = [];
        List<String> images = [];
        for (var fingerprintSet in allFingerprints) {
          keys.addAll(fingerprintSet.keys);
          images.addAll(fingerprintSet.values.map((value) => value.split(',')[1]));
        }

        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'All Fingerprints',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: keys.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          Text(
                            keys[index],
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.memory(
                                base64Decode(images[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fingerprint Processor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display selected image
            _image == null
                ? const Text(
              'No image selected.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.file(
                File(_image!.path),
                height: 200,
                width: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),

            // Loading indicator or fingerprint display
            if (isLoading)
              const CircularProgressIndicator()
            else if (fingerprints.isNotEmpty)
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: fingerprints.length,
                  itemBuilder: (context, index) {
                    String key = fingerprints.keys.elementAt(index);
                    String base64Image = fingerprints[key]!.split(',')[1];
                    return Column(
                      children: [
                        Text(
                          key,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.memory(
                              base64Decode(base64Image),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),

            // Buttons for camera, gallery, view all, and done
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _getImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _viewAllFingerprints,
                      icon: const Icon(Icons.view_module),
                      label: const Text('View Fingerprints'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20), // Add space between rows
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to CapturingThumb page
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const done()),
                        );
                      },

                      label: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white, // Set text color to white
                      ),
                      ),
                      style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // Set button color to green
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      ),
                      ),

                  ],
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }
}
