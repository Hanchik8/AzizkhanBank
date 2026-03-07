import 'package:azizkhan_bank_app/api/api_service.dart';
import 'package:azizkhan_bank_app/ui/bank_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({
    super.key,
    this.prefilledFromAccountId,
    this.preferredCurrency,
  });

  final int? prefilledFromAccountId;
  final String? preferredCurrency;

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
  late final Animation<Offset> _slideAnimation;

  String _currency = 'KGS';
  bool _isLoading = false;
  bool _transferSuccess = false;

  static const List<String> _currencies = <String>['KGS', 'USD', 'EUR', 'RUB'];

  @override
  void initState() {
    super.initState();
    if (widget.prefilledFromAccountId != null) {
      _fromAccountIdController.text = widget.prefilledFromAccountId.toString();
    }
    final preferredCurrency = widget.preferredCurrency?.toUpperCase();
    if (preferredCurrency != null && _currencies.contains(preferredCurrency)) {
      _currency = preferredCurrency;
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
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
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '\u20AC';
      case 'RUB':
        return '\u20BD';
      case 'KGS':
        return 'сом';
      default:
        return currency.toUpperCase();
    }
  }

  Future<void> _submitTransfer() async {
    final fromAccountId = _fromAccountIdController.text.trim();
    final toAccountId = _toAccountIdController.text.trim();
    final amount = _parsedAmount();

    if (fromAccountId.isEmpty) {
      _showSnack('Введите ID счёта списания.', isError: true);
      return;
    }
    if (int.tryParse(fromAccountId) == null) {
      _showSnack('ID счёта списания должен быть числом.', isError: true);
      return;
    }
    if (toAccountId.isEmpty) {
      _showSnack('Введите ID счёта получателя.', isError: true);
      return;
    }
    if (int.tryParse(toAccountId) == null) {
      _showSnack('ID счёта получателя должен быть числом.', isError: true);
      return;
    }
    if (amount == null || amount <= 0) {
      _showSnack('Введите корректную сумму перевода.', isError: true);
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
      _showSnack('Перевод успешно выполнен.', isError: false);
      _toAccountIdController.clear();
      _amountController.clear();

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _transferSuccess = false);
    } on DioException catch (error) {
      if (error.response?.statusCode == 422) {
        _showSnack('Дневной лимит переводов превышен.', isError: true);
      } else {
        _showSnack(
          ApiService.resolveDioMessage(error, fallback: 'Ошибка перевода.'),
          isError: true,
        );
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
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? BankColors.danger : BankColors.success,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _buildBottomAction(),
      body: Stack(
        children: [
          const BankBackdrop(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 20),
                    _buildAmountSection(),
                    const SizedBox(height: 20),
                    _buildAccountFields(),
                    const SizedBox(height: 20),
                    _buildFeeSection(),
                    const SizedBox(height: 16),
                    _buildSecurityCard(),
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
                'Перевод',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BankColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Перевод между счетами с подтверждённого устройства.',
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

  Widget _buildAmountSection() {
    return BankSurfaceCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BankColors.heroStart, BankColors.heroEnd],
      ),
      borderColor: Colors.white.withValues(alpha: 0.08),
      radius: 32,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сумма перевода',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.74),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
            decoration: InputDecoration(
              hintText: '0.00 ${_currencySymbol(_currency)}',
              hintStyle: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.26),
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _currencies.map((currency) {
              final isSelected = currency == _currency;
              return ChoiceChip(
                selected: isSelected,
                label: Text('$currency ${_currencySymbol(currency)}'),
                labelStyle: TextStyle(
                  color: isSelected ? BankColors.primary : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                side: BorderSide(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.18),
                ),
                onSelected: (_) => setState(() => _currency = currency),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountFields() {
    return BankSurfaceCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BankSectionHeader(
            title: 'Реквизиты перевода',
            subtitle: 'Укажите счёт списания и счёт получателя.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _fromAccountIdController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Со счёта',
              hintText: 'Например, 1001',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
          ),
          if (widget.prefilledFromAccountId != null) ...[
            const SizedBox(height: 10),
            const Text(
              'Счёт списания предзаполнен из выбранной карточки на главном экране.',
              style: TextStyle(
                fontSize: 12,
                color: BankColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _toAccountIdController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'На счёт',
              hintText: 'Введите ID получателя',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeSection() {
    final amount = _parsedAmount();
    final hasAmount = amount != null && amount > 0;

    return BankSurfaceCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BankSectionHeader(
            title: 'Расчёт списания',
            subtitle: 'Комиссия рассчитывается автоматически перед отправкой.',
          ),
          const SizedBox(height: 18),
          _buildFeeRow(
            'Сумма',
            hasAmount ? '${amount!.toStringAsFixed(2)} ${_currencySymbol(_currency)}' : '-',
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),
          _buildFeeRow(
            'Комиссия 1%',
            hasAmount ? '${_feeText()} ${_currencySymbol(_currency)}' : '-',
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),
          _buildFeeRow(
            'Итого к списанию',
            hasAmount ? '${_totalText()} ${_currencySymbol(_currency)}' : '-',
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: highlight ? BankColors.textPrimary : BankColors.textSecondary,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            color: highlight ? BankColors.primary : BankColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityCard() {
    return BankSurfaceCard(
      radius: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: BankColors.successSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: BankColors.success,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Безопасная отправка',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BankColors.textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Запрос подписывается DPoP-ключом и проходит с уникальным idempotency key.',
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

  Widget _buildBottomAction() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: BankSurfaceCard(
        padding: const EdgeInsets.all(10),
        radius: 30,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitTransfer,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _transferSuccess ? BankColors.success : BankColors.primary,
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
                        Icon(Icons.check_circle_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Перевод отправлен'),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Подтвердить перевод'),
                      ],
                    ),
        ),
      ),
    );
  }
}
