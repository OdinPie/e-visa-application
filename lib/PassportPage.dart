import 'dart:io';
import 'dart:math';

import 'package:evisa_temp/DisplayPassportData.dart';
import 'package:evisa_temp/FaceLivelinessCheck.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';

class PassportPage extends StatefulWidget {
  @override
  State<PassportPage> createState() {
    return _PassportPageState();
  }
}

class _PassportPageState extends State<PassportPage> {
  String output = ""; // Holds the extracted text
  File? image;
  ImagePicker? imagePicker;
  bool loading = false;
  bool success = false;
  // Capture image using the camera
  captureImage() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        image = File(pickedFile.path);
        setState(() {
          loading = true;
          processImage();
        });
      }
    } catch (e) {
      print(e);
    }
  }

  // Process the captured image
  processImage() async {
    try {
      String mrzLines = "";
      final inputImage = InputImage.fromFilePath(image!.path);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      for (TextBlock block in recognizedText.blocks) {
        String? mrz = extractMRZ(block.text);
        if (mrz != null) {
          if (block.lines.length == 2) {
            String firstLine = block.lines[0].text.replaceAll(" ", "");
            String countryCode = firstLine.substring(2, 5);
            String surName = firstLine.split('<<')[0].substring(5).toUpperCase();
            String givenName = firstLine.split('<<')[1].replaceAll('<', ' ').toUpperCase();
            String secLine = block.lines[1].text.replaceAll(" ", "");
            String passportNumber = secLine.substring(0, 9);
            String birthDate = secLine.substring(13, 19);
            String gender = secLine.substring(20, 21) == 'F' ? "Female" : "Male";
            String expiryArea = secLine.substring(21, 27);
            String personalNumber = secLine.split('<<')[0].substring(28).replaceAll('<', '-');

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
              builder: (context) => DisplayPassportData(countryCode: countryCode,
                                    surName: surName,
                                    givenName: givenName,
                                    passportNumber: passportNumber,
                                    birthDate: birthDate,
                                    gender: gender,
                                    expiryDate:expiryDate,
                                    expiryDateString:expiryDateString,
                                    personalNumber:personalNumber),
            ),
          );
           
          } else {
            setState(() {
              output =
                  "Could not get 2 lines of mrz. Please try again\n";
              loading = false;
            });
          }
        }
      }
      if (loading) {
        setState(() {
          output =
              "Could not process the passport. Please try again";
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
              children: <Widget>[
                // Back Button and Go Back Text
                ListTile(
                  contentPadding: EdgeInsets.all(0),
                  title: const Text(
                    "Go Back",
                    style: TextStyle(fontSize: 20),
                  ),
                  leading: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
