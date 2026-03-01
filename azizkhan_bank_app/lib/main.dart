import 'package:azizkhan_bank_app/api/api_service.dart';
import 'package:azizkhan_bank_app/screens/home_screen.dart';
import 'package:azizkhan_bank_app/screens/phone_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: ApiService.accessTokenStorageKey);
    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    } else {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const PhoneScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
