import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

import 'VisaDetails.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:url_launcher/url_launcher_string.dart';

class CheckInbox extends StatefulWidget {
  final String email;
  const CheckInbox({Key? key, required this.email}) : super(key: key);
  // const CheckInbox({super.key});

  @override
  State<CheckInbox> createState() {
    return _CheckInboxState();
  }
}

class _CheckInboxState extends State<CheckInbox> {
  TextEditingController controller = TextEditingController();
  bool validate = true;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          validate = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> validateOTP(String givenOtp, String email) async {
    const String apiurl = "http://127.0.0.1:8000/get-otp/";
    final Uri uri = Uri.parse('$apiurl?email=$email');

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final otp = data['otp'];
        if (otp == givenOtp) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VisaApplicationDetailsPage(),
            ),
          );
        } else {
          setState(() {
            validate = false;
          });
          return;
        }
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Container(
        margin: EdgeInsets.all(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 10,
              ),
              ListTile(
                  contentPadding: EdgeInsets.all(0),
                  title: Text(
                    "Go Back",
                    style: TextStyle(fontSize: 20),
                  ),
                  leading: GestureDetector(
                      onTap: () => {Navigator.pop(context)},
                      child: CircleAvatar(
                        backgroundColor: Colors.teal[50],
                        child: Icon(Icons.arrow_back, color: Colors.teal[900]),
                      ))),
              SizedBox(
                height: 10,
              ),
              Text(
                'Check your Inbox',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(
                height: 20,
              ),
              Text(
                "We have sent you an email with an OTP and instruction to verify your email address. You have only 5 minutes to verify it. If the email address is not verified after that time, you will need to ask for another verification email to be sent. \nPlease go to your mailbox and follow the instructions.",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(
                height: 25,
              ),
              Text(
                widget.email,
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
              Center(
                child: Lottie.network(
                    'https://lottie.host/e7725950-4e0d-44b6-9543-c25638280fd0/xErvTQvAHW.json',
                    width: 150),
              ),
              SizedBox(
                height: 20,
              ),
              Center(
                child: Column(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: TextField(
                        focusNode: _focusNode,
                        controller: controller,
                        decoration: InputDecoration(
                            errorText: validate ? null : "Invalid OTP",
                            hintText: "Enter OTP Here",
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 20,
              ),
              RichText(
                  text: TextSpan(children: [
                TextSpan(
                  text:
                      "If you can not find the email try checking your mail junk folder.\n\nDid not receive the email?",
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
                TextSpan(
                    text: "Resend Email",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        Navigator.pop(context);
                      })
              ])),
              SizedBox(
                height: 40, // Creates space
              ),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    validateOTP(controller.text, widget.email);
                    // Add your navigation logic here
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.green[900], // Button background color
                    padding: const EdgeInsets.symmetric(
                        horizontal: 60, vertical: 12),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              )
            ],
          ),
        ),
      )),
    );
  }
}
