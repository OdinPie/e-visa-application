import 'package:evisa_temp/pages/PassportPage.dart';
import 'package:flutter/material.dart';

class VisaApplicationDetailsPage extends StatefulWidget {
  final Future <String> userId;
  const VisaApplicationDetailsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _VisaApplicationDetailsPageState createState() =>
      _VisaApplicationDetailsPageState();
}

class _VisaApplicationDetailsPageState
    extends State<VisaApplicationDetailsPage> {
  String? selectedVisaType;
  String? selectedEmbassy;
  final List<String> embassies = [
    'US Embassy',
    'UK Embassy',
    'Canada Embassy',
    'Germany Embassy',
    'Australia Embassy',
  ];
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 50),
            Text(
              'Visa Application Details',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Please enter your visa application details. All fields are required to submit the biometric enrollment.',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Visa Type',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Column(
              children: [
                RadioListTile<String>(
                  title: Text('Transit Visa'),
                  value: 'Transit Visa',
                  groupValue: selectedVisaType,
                  onChanged: (value) {
                    setState(() {
                      selectedVisaType = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: Text('On-Arrival Visa'),
                  value: 'On-Arrival Visa',
                  groupValue: selectedVisaType,
                  onChanged: (value) {
                    setState(() {
                      selectedVisaType = value;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Visa Issuing Embassy',
                border: OutlineInputBorder(),
              ),
              value: selectedEmbassy,
              items: embassies.map((embassy) {
                return DropdownMenuItem(
                  value: embassy,
                  child: Text(embassy),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedEmbassy = value;
                });
              },
            ),
            SizedBox(height: 10),
            Text(
              'Please select the embassy that is closest to where you currently live.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 30),
            Center(
              child: GestureDetector(
                onTap: isLoading
                    ? null
                    : () async {
                        if (selectedVisaType != null &&
                            selectedEmbassy != null) {
                          setState(() {
                            isLoading = true;
                          });
                          await Future.delayed(Duration(seconds: 1));
                          setState(() {
                            isLoading = false;
                          });
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      PassportPage(userId: widget.userId),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                const begin =
                                    Offset(0, 1); // From bottom to top
                                const end = Offset.zero;
                                const curve = Curves.easeInOut;

                                var tween = Tween(begin: begin, end: end)
                                    .chain(CurveTween(curve: curve));
                                var offsetAnimation = animation.drive(tween);

                                return SlideTransition(
                                  position: offsetAnimation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Please select visa type and embassy.',
                              ),
                            ),
                          );
                        }
                      },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.green[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
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
