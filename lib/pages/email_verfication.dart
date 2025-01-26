// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'check_inbox_page.dart';

class EmailVerificationPage extends StatefulWidget {
  @override
  // _EmailVerificationPageState createState() {
  State<EmailVerificationPage> createState() {
    return _EmailVerificationPageState();
  }
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  TextEditingController controller = TextEditingController();
  bool validate = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
      child: Container(
          margin: EdgeInsets.all(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: 60,
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        "Email Verification",
                        style: TextStyle(color: Colors.black, fontSize: 40),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Text(
                        "For security reasons we need to verify your email.",
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Text(
                        "We will send you a verification email with instructions to verify your email address. Kindly use this mobile phone to access your email and click on the verification link. The biometric enrollment application process will not continue If the email is verified using a different device. ",
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(
                        height: 30,
                      ),
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, .2),
                                  blurRadius: 20,
                                  offset: Offset(0, 10))
                            ]),
                        child: Column(
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.all(10),
                              child: TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                    errorText: validate
                                        ? "Please Enter a Valid Email Address"
                                        : null,
                                    hintText: "Enter Email Here",
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 50,
                      ),
                      Center(
                        child: ElevatedButton(
                          onPressed: () => {
                            setState(() {
                              validate = controller.text.isEmpty ||
                                  !RegExp(r'^[\w-\.]+@[a-zA-Z]+\.[a-zA-Z]{2,}$')
                                      .hasMatch(controller.text);
                            }),
                            if (!validate)
                              {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => CheckInbox(
                                            email: controller.text))),
                                sendEmail(controller.text),
                              }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(
                                horizontal: 50, vertical: 15),
                          ),
                          child: Text(
                            "SEND EMAIL",
                            style: TextStyle(
                                color: Colors.white,
                                // fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
    ));
  }
}

void sendEmail(String email) async {
  final response = await http.post(Uri.parse('http://127.0.0.1:8000/send-otp/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{'email': email}));

  if (response.statusCode == 200) {
    print(response.body);
  } else {
    print("kaj hocche na");

    throw Exception(response.statusCode);
  }
}
