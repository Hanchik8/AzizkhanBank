import 'package:azizkhan_bank_app/api/api_service.dart';
import 'package:azizkhan_bank_app/crypto/crypto_service.dart';
import 'package:azizkhan_bank_app/screens/home_screen.dart';
import 'package:azizkhan_bank_app/ui/bank_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final Animation<Offset> _slideAnimation;

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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
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
      setState(() => _errorMessage = 'Введите код подтверждения.');
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
          transitionDuration: const Duration(milliseconds: 450),
        ),
        (route) => false,
      );
    } on DioException catch (error) {
      setState(
        () => _errorMessage = ApiService.resolveDioMessage(
          error,
          fallback: 'Не удалось подтвердить код.',
        ),
      );
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

  Future<void> _resendOtp() async {
    try {
      await _apiService.sendOtp(widget.phoneNumber);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Код отправлен повторно.'),
          backgroundColor: BankColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось отправить код повторно.'),
          backgroundColor: BankColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BankBackdrop(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 20),
                    _buildCodeCard(),
                    const SizedBox(height: 16),
                    _buildSecurityNote(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        BankSoftIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Подтверждение входа',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BankColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Подтвердите номер телефона одноразовым кодом.',
                style: TextStyle(
                  fontSize: 13,
                  color: BankColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCodeCard() {
    return BankSurfaceCard(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Код из SMS',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: BankColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Мы отправили код на номер ${_maskedPhone()}.',
            style: const TextStyle(
              fontSize: 14,
              color: BankColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 10,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: TextStyle(
                letterSpacing: 10,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: BankColors.textTertiary.withValues(alpha: 0.7),
              ),
            ),
            onSubmitted: (_) => _verifyOtpAndBindDevice(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: BankColors.dangerSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: BankColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: BankColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
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
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _resendOtp,
              child: const Text('Отправить код повторно'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return BankSurfaceCard(
      radius: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: BankColors.warningSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: BankColors.warning,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Привязка устройства',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BankColors.textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'После проверки кодом устройство будет связано с аккаунтом для безопасных операций.',
                  style: TextStyle(
                    fontSize: 13,
                    color: BankColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
