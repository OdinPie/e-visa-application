import 'package:flutter/material.dart';
import 'package:evisa_temp/FaceLivelinessCheck.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class DisplayPassportData extends StatefulWidget {
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

Future<bool> _sendToApi(File? file, BuildContext context) async {
  final uri = Uri.parse("http://127.0.0.1:8000/upload_passport/");
  final request = http.MultipartRequest("POST", uri)
    ..files.add(await http.MultipartFile.fromPath('file', file!.path));

  final response = await request.send();

  if (response.statusCode == 200) {
    // return true;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Facelivelinesscheck(),
        ),
      );
      return true;
  } else {
    throw Exception("Could Not Save Passport Photo");
  }
}

class _DisplayPassportDataState extends State<DisplayPassportData> {
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
      _sendToApi(widget.image,context);
      
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
                  _buildTextField('Date of Birth', widget.birthDate),
                  _buildTextField('Surname', widget.surName),
                  _buildTextField('First Name', widget.givenName),
                  _buildTextField('Expiry Date', widget.expiryDateString),
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
