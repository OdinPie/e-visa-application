// import 'package:evisa/pages/extraction.dart';
import 'package:evisa_temp/pages/extraction.dart';
import 'package:flutter/material.dart';

class FingerprintCapture extends StatelessWidget {
  final String userId;

  const FingerprintCapture({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView( // Add SingleChildScrollView here
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                "Fingerprint Image Capture",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
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
                  child: const Image(
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
                    Text(
                      "1. Hold your left hand steady with the palm facing up.",
                      style: TextStyle(fontSize: 16, height: 1.8),
                    ),
                    Text(
                      "2. Hold the camera steady and capture left hand image.",
                      style: TextStyle(fontSize: 16, height: 1.8),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "3. Repeat steps 1-3 with your right hand holding your phone in your left hand.",
                      style: TextStyle(fontSize: 16, height: 1.8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Start Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to CapturingThumb page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => FingerprintProcessor(userId: userId)),
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
      ),
    );
  }
}
