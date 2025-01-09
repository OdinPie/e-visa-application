import 'package:evisa_temp/FaceLivelinessCheck.dart';
import 'package:evisa_temp/PassportPage.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // return MaterialApp(debugShowCheckedModeBanner: false, home: Facelivelinesscheck());
    return MaterialApp(debugShowCheckedModeBanner: false, home: PassportPage());
  }
}
