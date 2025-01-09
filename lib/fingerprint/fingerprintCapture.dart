import 'package:evisa_temp/fingerprint/extraction.dart';
import 'package:flutter/material.dart';

// import 'capturingThumb.dart';

class fingerprintCapture extends StatelessWidget {
  const fingerprintCapture({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: const Text(
            'Fingerprint Image Capture',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 25,
            ),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              const Text(
                "Using your phone's back camera, show your finger tips so we can take photos of your fingerprints.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Center(

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image(
                    image: AssetImage(
                    'assets/finger.png',
                  ),
                    ),
                  ),
                ),
              const SizedBox(height: 35),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("1. Hold your left hand steady with the palm facing up. You might find it easier to place your arm or hand against a surface.",
                  style: TextStyle(fontSize: 16, height: 1.8),
                    ),
                    Text(
                      "2. Hold the camera over the tip of your thumb until the photo has been taken.",
                      style: TextStyle(fontSize: 16, height: 1.8),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "3. Next hold the camera over your 4 fingertips until the photo has been taken.",
                      style: TextStyle(fontSize: 16, height: 1.8),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "4. Repeat steps 1-3 with your right hand holding your phone in your left hand.",
                      style: TextStyle(fontSize: 16, height: 1.8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Start Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to CapturingThumb page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FingerprintProcessor()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004d00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Start Fingerprint Capture',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),


            ],
          ),
      ),
    );
  }
}

