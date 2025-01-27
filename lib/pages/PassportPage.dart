import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:evisa_temp/pages/DisplayPassportData.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';

class PassportPage extends StatefulWidget {
  final Future<String> userId;
  const PassportPage({Key? key, required this.userId}) : super(key: key);
  @override
  State<PassportPage> createState() {
    return _PassportPageState();
  }
}

class _PassportPageState extends State<PassportPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool isScanning = false;
  String output = ""; // Holds the extracted text
  File? image;
  ImagePicker? imagePicker;
  bool loading = false;
  bool success = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2), // Animation duration
    );

    // Scale animation
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    // Fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward(); // Start the animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Capture image using the camera
  captureImage() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        image = File(pickedFile.path);

        await sendImageToApi(image!);
        setState(() {
          loading = true;
          // processImage(image);
        });
      }
    } catch (e) {
      setState(() {
        output = "Could not capture";
        loading = false;
        // processImage(image);
      });
      print(e);
    }
  }

  Future<void> sendImageToApi(File imageFile) async {
    try {
      // API endpoint
      final uri = Uri.parse("http://127.0.0.1:8000/ocr_check/");

      // Create a multipart request
      var request = http.MultipartRequest("POST", uri)
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            imageFile.path,
          ),
        );

      // Send the request
      var response = await request.send();

      // Process the response
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final result = jsonDecode(responseData);
        processImage(result[0], result[1], image);
        print("API Response: $result");
      } else {
        final responseData = await response.stream.bytesToString();
        final result = jsonDecode(responseData);
        setState(() {
          output = "Could not process. Please try again\n";
          loading = false;
        });
        print("Error from API: ${result['detail']}");
      }
    } catch (e) {
      setState(() {
        output = "Could not process. Please try again\n";
        loading = false;
      });
      print("Error sending image to API: $e");
    }
  }

  // Process the captured image
  processImage(String firstline, String secondline, File? image) async {
    try {
      if (firstline.isNotEmpty && secondline.isNotEmpty) {
        // String firstLine = result.current_line;
        String countryCode = firstline.substring(2, 5);
        String surName = firstline
            .split('<<')[0]
            .substring(5)
            .replaceAll('<', ' ')
            .toUpperCase();
        String givenName =
            firstline.split('<<')[1].replaceAll('<', ' ').toUpperCase();
        // String secLine = block.lines[1].text.replaceAll(" ", "");
        String passportNumber = secondline.substring(0, 9);
        String birthDate = secondline.substring(13, 19);
        String gender = secondline.substring(20, 21) == 'F' ? "Female" : "Male";
        String expiryArea = secondline.substring(21, 27);
        String personalNumber =
            secondline.split('<<')[0].substring(28).replaceAll('<', '-');

        if (DateTime.now()
                .year
                .toString()
                .substring(2)
                .compareTo(birthDate.substring(0, 2)) ==
            -1) {
          birthDate =
              "19${birthDate.substring(0, 2)}-${birthDate.substring(2, 4)}-${birthDate.substring(4)}";
        } else {
          birthDate =
              "20${birthDate.substring(0, 2)}-${birthDate.substring(2, 4)}-${birthDate.substring(4)}";
        }

        expiryArea =
            "20${expiryArea.substring(0, 2)}-${expiryArea.substring(2, 4)}-${expiryArea.substring(4)}";
        DateTime expiryDate = DateTime.parse(expiryArea);
        String expiryDateString = expiryDate.toString().substring(0, 10);
        loading = false;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DisplayPassportData(
                userId: widget.userId,
                countryCode: countryCode,
                surName: surName,
                givenName: givenName,
                passportNumber: passportNumber,
                birthDate: birthDate,
                gender: gender,
                image: image,
                expiryDate: expiryDate,
                expiryDateString: expiryDateString,
                personalNumber: personalNumber),
          ),
        );
      } else {
        setState(() {
          output = "Could not get 2 lines of mrz. Please try again\n";
          loading = false;
        });
      }
      // }
      // }
      if (loading) {
        setState(() {
          output = "Could not process the passport. Please try again";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        output = e.toString();
        loading = false; // Update the output with extracted text
      });
    }
  }

  String? extractMRZ(String extractedText) {
    // final mrzRegex = RegExp(r'P<[A-Z0-9< ]+\n[A-Z0-9< ]+$');
    final mrzRegex = RegExp(r'^P(<|k|K)');
    final mrz = mrzRegex.firstMatch(extractedText);
    return mrz?.group(0)?.replaceAll(" ", '').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button and Go Back Text
                const SizedBox(height: 40),
                const Text(
                  "Passport Scan",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Using your phone’s back camera, scan your passport.",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Image.asset(
                        'assets/passport_scan.png', // Replace with your actual image path
                        height: 250,
                        width: 250,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 50),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FOR THE BEST RESULT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '• Hold the document straight and steady.',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '• Take in a well-lit place without direct light or shadows on your face.',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '• Ensure there is no glare or shadows on the passport.',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 50),

                // Display the extracted text
                output.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          output,
                          style: const TextStyle(fontSize: 16),
                        ),
                      )
                    : loading
                        ? const Text(
                            "Image is Processing",
                            style:
                                TextStyle(fontSize: 16, color: Colors.black54),
                          )
                        : const Text(
                            "No text extracted yet. Please scan a passport.",
                            style:
                                TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                const SizedBox(height: 30),
                Center(
                  child: ElevatedButton(
                    onPressed: captureImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 15),
                    ),
                    child: const Text(
                      "Scan Passport",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
