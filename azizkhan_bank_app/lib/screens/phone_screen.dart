import 'package:azizkhan_bank_app/api/api_service.dart';
import 'package:azizkhan_bank_app/screens/otp_screen.dart';
import 'package:azizkhan_bank_app/ui/bank_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

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
      duration: const Duration(milliseconds: 750),
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
    _phoneController.dispose();
    _phoneFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Введите номер телефона.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.sendOtp(phone);
      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => OtpScreen(phoneNumber: phone),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 380),
        ),
      );
    } on DioException catch (error) {
      setState(
        () => _errorMessage = ApiService.resolveDioMessage(
          error,
          fallback: 'Не удалось отправить код.',
        ),
      );
    } catch (error) {
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                    _buildHeroCard(),
                    const SizedBox(height: 20),
                    _buildFormCard(),
                    const SizedBox(height: 16),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return BankSurfaceCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BankColors.heroStart, BankColors.heroEnd],
      ),
      borderColor: Colors.white.withValues(alpha: 0.08),
      radius: 34,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Azizkhan Bank',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Мобильный банк для переводов, просмотра счетов и безопасной истории операций.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.76),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              BankStatusPill(
                label: 'Вход по OTP',
                icon: Icons.sms_outlined,
                backgroundColor: Color(0x24FFFFFF),
                foregroundColor: Colors.white,
              ),
              BankStatusPill(
                label: 'Защита устройства',
                icon: Icons.shield_outlined,
                backgroundColor: Color(0x24FFFFFF),
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return BankSurfaceCard(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BankSectionHeader(
            title: 'Вход по номеру телефона',
            subtitle: 'Мы отправим одноразовый код для подтверждения входа.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _phoneController,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
            ],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              labelText: 'Номер телефона',
              hintText: '+996 700 123 456',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
            onSubmitted: (_) => _sendOtp(),
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
            onPressed: _isLoading ? null : _sendOtp,
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
                      Text('Получить код'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        'Нажимая «Получить код», вы подтверждаете согласие с условиями обслуживания и обработкой данных.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: BankColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}
