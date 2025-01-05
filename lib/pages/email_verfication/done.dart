import 'package:flutter/material.dart';

class done extends StatelessWidget {
  const done({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Biometric Data Enrollment Sent',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'You should receive an email confirming your enrollment submission with an update on your enrollment shortly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      height: 1.5,
                    ),
              ),
              SizedBox(height: 16),
              Text(
                'Thank you for using the biometric Enrollment Application of Ministry of Foreign Affairs.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                  child: Image(
                    image: AssetImage(
                      'assets/pngtree-simple-style-correct-symbol-icon-material-image_2291415-Photoroom.png',
                    ),
                    height: 200,
                    width: 200,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Action when button is clicked
                      print("Done");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004d00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),


            ],
          ),
        )
      )
    );
  }
}
