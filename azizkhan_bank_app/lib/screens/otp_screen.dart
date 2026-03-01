import 'package:azizkhan_bank_app/api/api_service.dart';
import 'package:azizkhan_bank_app/crypto/crypto_service.dart';
import 'package:azizkhan_bank_app/screens/home_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Uuid _uuid = const Uuid();

  late final ApiService _apiService = ApiService(secureStorage: _secureStorage);
  late final CryptoService _cryptoService = CryptoService(
    secureStorage: _secureStorage,
  );

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtpAndBindDevice() async {
    final otpCode = _otpController.text.trim();
    if (otpCode.isEmpty) {
      setState(() {
        _errorMessage = 'Enter OTP code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final registrationToken = await _apiService.verifyOtp(
        widget.phoneNumber,
        otpCode,
      );

      final generatedKeyPair = await _cryptoService.generateKeyPair();
      await _cryptoService.savePrivateKey(generatedKeyPair.privateKeyPem);
      await _cryptoService.savePublicKey(generatedKeyPair.publicKeyPem);

      final deviceId = _uuid.v4();
      final authTokens = await _apiService.bindDevice(
        registrationToken: registrationToken,
        deviceId: deviceId,
        publicKey: generatedKeyPair.publicKeyPem,
      );

      await _apiService.saveAuthTokens(authTokens);

      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on DioException catch (error) {
      setState(() {
        _errorMessage = _resolveDioMessage(error);
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _resolveDioMessage(DioException error) {
    final payload = error.response?.data;
    if (payload is Map<String, dynamic>) {
      final message = payload['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return error.message ?? 'Request failed';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP Verification')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Phone: ${widget.phoneNumber}'),
              const SizedBox(height: 12),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'OTP code',
                  hintText: '123456',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtpAndBindDevice,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify and Bind Device'),
              ),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
