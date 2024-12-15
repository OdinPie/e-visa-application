import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier{
  final _auth = FirebaseAuth.instance;

  Future <void> sendEmailVerificationLink(String email) async {
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

  Future <void> _checkEmailVerified(User user) async{
    await user.reload();

    if(user.emailVerified){
      print("Email Verified");
    }else{
      print("Email not verified");
    }
  }
}