import 'dart:convert';

import 'package:evisa_temp/pages/Facelivelinesschecks.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class DisplayPassportData extends StatefulWidget {
  final String userId;
  final String countryCode;
  final String surName;
  final String givenName;
  final String passportNumber;
  final String birthDate;
  final String gender;
  final String expiryDateString;
  final DateTime expiryDate;
  final String personalNumber;
  final File? image;

  const DisplayPassportData({
    Key? key,
    required this.userId,
    required this.countryCode,
    required this.surName,
    required this.givenName,
    required this.passportNumber,
    required this.birthDate,
    required this.gender,
    required this.expiryDate,
    required this.image,
    required this.expiryDateString,
    required this.personalNumber,
  }) : super(key: key);

  @override
  State<DisplayPassportData> createState() {
    return _DisplayPassportDataState();
  }
}

class _DisplayPassportDataState extends State<DisplayPassportData> {
  Future<bool> storePassportDetails(
      String countryCode,
      String surName,
      String givenName,
      String passportNumber,
      String birthDate,
      String gender,
      String expiryDate,
      String personalNumber) async {
    String id = await widget.userId.toString();
    Map<String, String> setter = {
      'countryCode': countryCode,
      'surName': surName,
      'givenName': givenName,
      'passportNumber': passportNumber,
      'birthDate': birthDate,
      'gender': gender,
      'expiryDateString': expiryDate,
      'personalNumber': personalNumber
    };
    final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/store_passport_details/?userId=$id'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(setter));
    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    }
    return false;
  }

  Future<bool> _uploadPassport(File? file, BuildContext context) async {
    final uri = Uri.parse("http://127.0.0.1:8000/upload_passport/");
    final request = http.MultipartRequest("POST", uri)
      ..files.add(await http.MultipartFile.fromPath('file', file!.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      // return true;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Facelivelinesscheck(userId: widget.userId),
        ),
      );
      return true;
    } else {
      // throw Exception("Could Not Save Passport Photo");
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("No Face Detected"),
            content: Text(
                "Sorry, Passport Photo could not be detected. Please try again."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                  // Implement retry scan logic here
                },
                child: Text("Retry Scan"),
              ),
            ],
          );
        },
      );
      return false;
    }
  }

  void checkExpiry(BuildContext context) {
    DateTime expiryDate = widget.expiryDate;
    if (DateTime.now().add(const Duration(days: 180)).compareTo(expiryDate) ==
        1) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Invalid Passport"),
            content: Text(
                "Sorry, your passport is not valid as it expires in less than 6 months."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                  // Implement retry scan logic here
                },
                child: Text("Retry Scan"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: Text("Cancel"),
              ),
            ],
          );
        },
      );
      // return false;
    } else {
      storePassportDetails(
          widget.countryCode,
          widget.surName,
          widget.givenName,
          widget.passportNumber,
          widget.birthDate,
          widget.gender,
          widget.expiryDateString,
          widget.personalNumber);
      _uploadPassport(widget.image, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Your Details'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Check the details retrieved before continuing",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField('Passport Number', widget.passportNumber),
                  _buildTextField('Nationality', widget.countryCode),
                  _buildTextField('Personal Number', widget.personalNumber),
                  _buildTextField('Date of Birth', widget.birthDate),
                  _buildTextField('Surname', widget.surName),
                  _buildTextField('First Name', widget.givenName),
                  _buildTextField('Expiry Date', widget.expiryDateString),
                  _buildTextField('Birth Date', widget.birthDate),
                  _buildTextField('Gender', widget.gender),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Add functionality for retrying the scan
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.black),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                        ),
                        child: const Text('Retry Scan'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          checkExpiry(context);
                          // Navigate to FaceLivelinessCheck page
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                        ),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                ],
              ),
            )),
      ),
    );
  }

  Widget _buildTextField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: TextEditingController(text: value),
          readOnly: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}
