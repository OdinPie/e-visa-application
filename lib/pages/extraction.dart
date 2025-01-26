import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'fingerprintApi.dart';

class FingerprintProcessor extends StatefulWidget {
  final String userId;

  const FingerprintProcessor({
    super.key,
    required this.userId,
  });

  @override
  State<FingerprintProcessor> createState() => _FingerprintCaptureState();
}

class _FingerprintCaptureState extends State<FingerprintProcessor> {
  File? _image;
  final picker = ImagePicker();
  Map<String, String> fingerprints = {};
  bool isLoading = false;

  // API Endpoint for FastAPI running locally (accessible via adb reverse)
  final String apiEndpoint = 'http://127.0.0.1:8000/process-fingerprints/';

  // Message helper method with BuildContext parameter
  void _showMessage(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Clear fingerprints from memory with context
  void _clearFingerprints(BuildContext context) {
    setState(() {
      fingerprints.clear();
      _image = null;
    });
    if (!mounted) return;
    _showMessage(context, 'Fingerprints cleared');
  }

  // Image picker with context
  Future<void> _getImage(BuildContext context, ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      await _uploadImage(context);
    } else {
      _showMessage(context, 'No image selected');
    }
  }

  // Upload image with context
  Future<void> _uploadImage(BuildContext context) async {
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
            fingerprints.addAll(Map<String, String>.from(data['images']));
          });
        } else {
          _showMessage(context, data['message'] ?? 'Error processing image');
        }
      } else {
        _showMessage(context, 'Server Error: ${response.statusCode}');
      }
    } catch (e) {
      _showMessage(context, 'Error: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Save'),
          content: const Text('Are you sure you got 10 fingerprints?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fingerprint Capture',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image == null
                ? const Text(
              'No image selected.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.file(
                _image!,
                height: 200,
                width: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),

            if (isLoading)
              const CircularProgressIndicator()
            else if (fingerprints.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
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
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            bool proceed = await _showConfirmationDialog(context);
                            if (proceed) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      FingerprintAPI(fingerprints: fingerprints, userId: widget.userId,),
                                ),
                              );
                            }
                          },
                          child: const Text('Save'),
                        ),
                        ElevatedButton(
                          onPressed: () => _clearFingerprints(context),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _getImage(context, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _getImage(context, ImageSource.gallery),
                  icon: const Icon(Icons.photo),
                  label: const Text('Gallery'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}