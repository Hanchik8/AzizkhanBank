import 'package:azizkhan_bank_app/api/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final Uuid _uuid = const Uuid();
  final TextEditingController _fromAccountIdController = TextEditingController();
  final TextEditingController _toAccountIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

  String _currency = 'KGS';
  bool _isLoading = false;
  bool _transferSuccess = false;

  static const List<String> _currencies = <String>['KGS', 'USD', 'EUR', 'RUB'];

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
    _fromAccountIdController.dispose();
    _toAccountIdController.dispose();
    _amountController.dispose();
    _animController.dispose();
    super.dispose();
  }

  num? _parsedAmount() {
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    return num.tryParse(amountText);
  }

  String _feeText() {
    final amount = _parsedAmount();
    if (amount == null || amount <= 0) return '0.00';
    return (amount * 0.01).toStringAsFixed(2);
  }

  String _totalText() {
    final amount = _parsedAmount();
    if (amount == null || amount <= 0) return '0.00';
    return (amount * 1.01).toStringAsFixed(2);
  }

  String _currencySymbol(String currency) {
    switch (currency) {
      case 'USD': return '\$';
      case 'EUR': return '\u20AC';
      case 'RUB': return '\u20BD';
      case 'KGS': return 'C';
      default: return currency;
    }
  }

  Future<void> _submitTransfer() async {
    final fromAccountId = _fromAccountIdController.text.trim();
    final toAccountId = _toAccountIdController.text.trim();
    final amount = _parsedAmount();

    if (fromAccountId.isEmpty) {
      _showSnack('Введите ID вашего счёта', isError: true);
      return;
    }
    if (int.tryParse(fromAccountId) == null) {
      _showSnack('ID счёта должен быть числом', isError: true);
      return;
    }
    if (toAccountId.isEmpty) {
      _showSnack('Введите ID счёта получателя', isError: true);
      return;
    }
    if (int.tryParse(toAccountId) == null) {
      _showSnack('ID получателя должен быть числом', isError: true);
      return;
    }
    if (amount == null || amount <= 0) {
      _showSnack('Введите корректную сумму', isError: true);
      return;
    }

    final idempotencyKey = _uuid.v4();

    setState(() => _isLoading = true);

    try {
      await _apiService.createTransfer(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        currency: _currency,
        idempotencyKey: idempotencyKey,
      );
      if (!mounted) return;

      setState(() => _transferSuccess = true);

      _showSnack('Перевод выполнен успешно', isError: false);
      _fromAccountIdController.clear();
      _toAccountIdController.clear();
      _amountController.clear();

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _transferSuccess = false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        _showSnack('Дневной лимит переводов превышен', isError: true);
      } else {
        _showSnack(ApiService.resolveDioMessage(e, fallback: 'Ошибка перевода'), isError: true);
      }
    } catch (error) {
      _showSnack(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF5350) : const Color(0xFF4CAF50),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Перевод'),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _buildAmountSection(),
                const SizedBox(height: 24),
                _buildAccountFields(),
                const SizedBox(height: 24),
                _buildFeeSection(),
                const SizedBox(height: 32),
                _buildSendButton(),
                const SizedBox(height: 24),
                _buildSecurityNote(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Сумма перевода',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currency,
                dropdownColor: const Color(0xFF162038),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                items: _currencies.map((c) => DropdownMenuItem(
                  value: c,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('$c  ${_currencySymbol(c)}'),
                  ),
                )).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _currency = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Реквизиты',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _fromAccountIdController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Со счёта',
            hintText: 'ID вашего счёта',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _toAccountIdController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'На счёт',
            hintText: 'ID счёта получателя',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
      ],
    );
  }

  Widget _buildFeeSection() {
    final amount = _parsedAmount();
    final hasAmount = amount != null && amount > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF162038),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          _buildFeeRow('Сумма', hasAmount ? '${amount!.toStringAsFixed(2)} ${_currencySymbol(_currency)}' : '-'),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 20),
          _buildFeeRow('Комиссия (1%)', hasAmount ? '${_feeText()} ${_currencySymbol(_currency)}' : '-'),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 20),
          _buildFeeRow(
            'Итого к списанию',
            hasAmount ? '${_totalText()} ${_currencySymbol(_currency)}' : '-',
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: isBold ? 0.85 : 0.5),
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: isBold ? const Color(0xFFD4A843) : Colors.white,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitTransfer,
        style: ElevatedButton.styleFrom(
          backgroundColor: _transferSuccess ? const Color(0xFF4CAF50) : null,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : _transferSuccess
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 20),
                      SizedBox(width: 8),
                      Text('Выполнено'),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Отправить перевод'),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outlined, size: 14, color: Colors.white.withValues(alpha: 0.3)),
        const SizedBox(width: 6),
        Text(
          'Перевод защищён DPoP-подписью',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}
