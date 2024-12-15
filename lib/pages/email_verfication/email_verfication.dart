import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmailVerificationPage extends StatelessWidget {
   EmailVerificationPage({super.key});
  final _auth = FirebaseAuth.instance;
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      body: SafeArea(

          child: Container(
            margin: EdgeInsets.all(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(height: 60,),
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text("Email Verification", style: TextStyle(
                            color: Colors.black,
                            fontSize: 40
                        ),),
                        SizedBox(height: 20,),
                        Text("For security reasons we need to verify your email.", style: TextStyle(
                            fontSize: 18
                        ),),

                        SizedBox(height: 20,),
                        Text("We will send you a verification email with instructions to verify your email address. Kindly use this mobile phone to access your email and click on the verification link. The biometric enrollment application process will not continue If the email is verified using a different device. ", style: TextStyle(
                            fontSize: 18
                        ),),

                        SizedBox(height: 30,),
                        Container(

                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, .2),
                                  blurRadius: 20,
                                  offset: Offset(0,10)
                              )]
                          ),
                          child: Column(
                            children: <Widget>[
                              Container(
                                padding: EdgeInsets.all(10),
                                child: TextField(
                                  decoration: InputDecoration(
                                      hintText: "Enter Email Here",
                                      hintStyle: TextStyle(color: Colors.grey),
                                      border: InputBorder.none
                                  ),
                                ),
                              ),

                            ],
                          ),
                        ),
                        SizedBox(height: 50,),

                        Center(
                          child: ElevatedButton(
                              onPressed: ()async{
                              await _sendEmailVerificationLink("hemlockboibitan@gmail.com");
                              },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,

                              padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                            ),
                            child: Text("SEND EMAIL",style: TextStyle(
                                color: Colors.white,
                                // fontSize: 16,
                                fontWeight: FontWeight.bold
                            ),)
                            ,
                          ),
                        )

                      ],
                    ),
                  ),

                ],
              ),
            )

          ),
      )
    );
  }
  _sendEmailVerificationLink(String email) async {
    try{
      // sign in anonymously
      UserCredential userCredential = await _auth.signInAnonymously();
      await userCredential.user?.verifyBeforeUpdateEmail(email);

      // send verification mail

      await userCredential.user?.sendEmailVerification();

      print("Email has been sent!");

      await _checkEmailVerified(userCredential.user!);
    }catch(e){
      print(e);
    }
  }

  _checkEmailVerified(User user) async{
    await user.reload();

    if(user.emailVerified){
      print("Email Verified");
    }else{
      print("Email not verified");
    }
  }
}





