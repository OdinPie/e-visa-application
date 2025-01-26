import 'package:evisa_temp/pages/email_verfication.dart';
import 'package:flutter/material.dart';

class ThirdPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // title: Text('Before You Start'),
        // centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: SingleChildScrollView(
        // padding: const EdgeInsets.all(16.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 60),
            Text(
              'Before you start',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'During the enrollment process you will provide your information using your mobile phone.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              'YOU SHOULD',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text(
              '* Enroll only one visa application at a time',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),

            // Self Enrollment Requirements Section
            Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELF ENROLLMENT REQUIREMENTS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 22),
                  // _requirementsItem(Icons.document_scanner, 'Passport validity should be more than 6 months',),

                  _requirementsItem(Icons.confirmation_number, 'E-number of your visa'),
                  _requirementsItem(Icons.email, 'Your valid email address'),
                  _requirementsItem(Icons.credit_card, 'Valid credit card or voucher'),
                  _requirementsItem(Icons.timer, 'The enrollment must be completed in a single session and should take around 10 minutes to complete'),
                ],
              ),
            ),
            // Spacer(),
            SizedBox(height: 40), // Adjust height as needed


            // Continue Button
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF004d00),
                  padding: EdgeInsets.symmetric(horizontal: 60, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  // Navigate to the next page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EmailVerificationPage()),
                  );
                },
                child: Text(
                  'CONTINUE',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to create requirement items
  Widget _requirementsItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 28),
          SizedBox(width: 13),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}