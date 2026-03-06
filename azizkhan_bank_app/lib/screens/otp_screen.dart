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

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Uuid _uuid = const Uuid();

  late final ApiService _apiService = ApiService(secureStorage: _secureStorage);
  late final CryptoService _cryptoService = CryptoService(
    secureStorage: _secureStorage,
  );

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtpAndBindDevice() async {
    final otpCode = _otpController.text.trim();
    if (otpCode.isEmpty) {
      setState(() => _errorMessage = 'Введите код подтверждения');
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
      await _secureStorage.write(
        key: ApiService.deviceIdStorageKey,
        value: deviceId,
      );

      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
        (route) => false,
      );
    } on DioException catch (error) {
      setState(() => _errorMessage = ApiService.resolveDioMessage(error));
    } catch (error) {
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _maskedPhone() {
    final phone = widget.phoneNumber;
    if (phone.length < 7) return phone;
    return '${phone.substring(0, phone.length - 4)}****';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _buildHeader(),
                const SizedBox(height: 40),
                _buildOtpField(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorMessage(),
                ],
                const SizedBox(height: 24),
                _buildVerifyButton(),
                const SizedBox(height: 20),
                _buildResendHint(),
                const Spacer(),
                _buildSecurityNote(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.lock_outline,
            color: Color(0xFF1565C0),
            size: 28,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Подтверждение',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.55),
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Код отправлен на номер\n'),
              TextSpan(
                text: _maskedPhone(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpField() {
    return TextField(
      controller: _otpController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 12,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '------',
        hintStyle: TextStyle(
          fontSize: 28,
          letterSpacing: 12,
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      onSubmitted: (_) => _verifyOtpAndBindDevice(),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF5350).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF5350).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF5350), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFEF5350),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _verifyOtpAndBindDevice,
      child: _isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined, size: 20),
                SizedBox(width: 8),
                Text('Подтвердить'),
              ],
            ),
    );
  }

  Future<void> _resendOtp() async {
    try {
      await _apiService.sendOtp(widget.phoneNumber);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Код отправлен повторно'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось отправить код'),
          backgroundColor: Color(0xFFEF5350),
        ),
      );
    }
  }

  Widget _buildResendHint() {
    return Center(
      child: TextButton(
        onPressed: _resendOtp,
        child: const Text('Отправить код повторно'),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD4A843).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD4A843).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield_outlined,
            color: const Color(0xFFD4A843).withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Устройство будет привязано к вашему аккаунту для безопасных операций',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
