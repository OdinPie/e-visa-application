import 'package:flutter/material.dart';
class capturing4fingers extends StatelessWidget {
  const capturing4fingers({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: FingerprintCaptureScreen(),
      ),
    );
  }
}

class FingerprintCaptureApp extends StatelessWidget {
  const FingerprintCaptureApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: FingerprintCaptureScreen(),
      ),
    );
  }
}

class FingerprintCaptureScreen extends StatelessWidget {
  const FingerprintCaptureScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
       // Aligns content to the left
        children: [
          // Instructional Text
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "Please use a darker background",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "Left 4 Fingers",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Left 4 Fingers Placeholder
          const Padding(
            padding: EdgeInsets.only(right: 200.0), // Starts from the left edge
            child: LeftFourFingersShape(),
          ),

          const SizedBox(height: 40),

          // Capture Button and Label
          const Center(
            child: Column(
              children: [
                Text(
                  "Left 4 fingers",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),

          Center(
            child: GestureDetector(
              onTap: () {
                // Add image capture logic here
                print("Image Capture Triggered");
              },
              child: Column(
                children: [
                  // Camera Icon with Border
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Image Capture",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LeftFourFingersShape extends StatelessWidget {
  const LeftFourFingersShape({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(1000, 250), // Adjust width and height here
      painter: _FingersPainter(),
    );
  }
}

class _FingersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.fill;

    final Path path = Path();

    double fingerWidth = size.width * 10; // Width of each finger
    double fingerHeight = size.height * 0.2; // Height of each finger
    double spacing = size.height * 0.05; // Spacing between fingers
    double radius = 20; // Radius for rounded edges

    // Draw the 4 fingers
    for (int i = 0; i < 4; i++) {
      double top = i * (fingerHeight + spacing);
      double bottom = top + fingerHeight;

      path.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(size.width * 0.5, top, size.width, bottom),
        Radius.circular(radius),
      ));
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
