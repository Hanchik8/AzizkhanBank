import 'package:azizkhan_bank_app/screens/phone_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AzizkhanBankApp());
}

class AzizkhanBankApp extends StatelessWidget {
  const AzizkhanBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Azizkhan Bank',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PhoneScreen(),
    );
  }
}
