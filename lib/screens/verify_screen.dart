import 'package:flutter/material.dart';
import '../utils/preference_helper.dart';

class VerifyScreen extends StatefulWidget {
  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final TextEditingController codeController = TextEditingController();

  void verifyOtp() async {
    final code = codeController.text.trim();
    if (code.isNotEmpty) {
      // TODO: Call API to verify OTP and get token
      const fakeToken = "your_token_from_server";
      await PreferenceHelper.saveToken(fakeToken);
      Navigator.pushReplacementNamed(context, '/mainwebview');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لطفا کد را وارد کنید')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تایید کد')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'کد ارسال شده'),
            ),
            SizedBox(height: 16),
            ElevatedButton(onPressed: verifyOtp, child: Text('ورود')),
          ],
        ),
      ),
    );
  }
}

