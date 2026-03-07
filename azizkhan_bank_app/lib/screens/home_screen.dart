import 'package:azizkhan_bank_app/api/api_service.dart';
import 'package:azizkhan_bank_app/screens/account_history_screen.dart';
import 'package:azizkhan_bank_app/screens/phone_screen.dart';
import 'package:azizkhan_bank_app/screens/transfer_screen.dart';
import 'package:azizkhan_bank_app/ui/bank_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController(viewportFraction: 0.92);

  List<Map<String, dynamic>> _accounts = <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _hideBalances = false;
  String? _errorMessage;
  int _selectedAccountIndex = 0;
  DateTime? _lastUpdatedAt;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accounts = await _apiService.getAccounts();
      if (!mounted) return;

      final parsedAccounts = accounts.whereType<Map<String, dynamic>>().toList();
      setState(() {
        _accounts = parsedAccounts;
        _selectedAccountIndex = parsedAccounts.isEmpty
            ? 0
            : _safeAccountIndex(parsedAccounts.length);
        _lastUpdatedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: BankColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text('Выйти из приложения'),
          content: const Text(
            'Текущая сессия будет завершена на этом устройстве.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Выйти',
                style: TextStyle(color: BankColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    const storage = FlutterSecureStorage();
    await storage.deleteAll();
    if (!mounted) return;

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const PhoneScreen()),
      (route) => false,
    );
  }

  Map<String, dynamic>? get _selectedAccount {
    if (_accounts.isEmpty) return null;
    final index = _safeAccountIndex(_accounts.length);
    return _accounts[index];
  }

  int _safeAccountIndex(int length) {
    if (length <= 0) return 0;
    if (_selectedAccountIndex < 0) return 0;
    if (_selectedAccountIndex >= length) return length - 1;
    return _selectedAccountIndex;
  }

  int? _extractAccountId(Map<String, dynamic> account) {
    final value = account['id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _extractCurrency(Map<String, dynamic> account) {
    return account['currency']?.toString().toUpperCase() ?? 'KGS';
  }

  double _extractBalance(Map<String, dynamic> account) {
    final value = account['balance'];
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
    return 0;
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

  IconData _currencyIcon(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return Icons.attach_money_rounded;
      case 'EUR':
        return Icons.euro_rounded;
      case 'RUB':
        return Icons.currency_ruble_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Color _currencyAccent(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return const Color(0xFF1AA774);
      case 'EUR':
        return const Color(0xFF1C76F8);
      case 'RUB':
        return const Color(0xFFF18B38);
      case 'KGS':
        return const Color(0xFFF0B64E);
      default:
        return BankColors.primary;
    }
  }

  List<Color> _currencyGradient(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return const [Color(0xFF0F5B43), Color(0xFF18A874)];
      case 'EUR':
        return const [Color(0xFF103D8E), Color(0xFF3183FF)];
      case 'RUB':
        return const [Color(0xFF8A3519), Color(0xFFF18B38)];
      case 'KGS':
        return const [Color(0xFF624300), Color(0xFFF0B64E)];
      default:
        return const [BankColors.heroStart, BankColors.heroEnd];
    }
  }

  String _formatAmount(num amount) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts.first;
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      final reverseIndex = digits.length - index;
      buffer.write(digits[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write(' ');
    }

    return '${buffer.toString().trim()}.${parts.last}';
  }

  String _maskedAccountId(int? accountId) {
    if (accountId == null) return '•••• ----';
    final value = accountId.toString();
    final visible = value.length <= 4 ? value : value.substring(value.length - 4);
    return '•••• $visible';
  }

  Set<String> get _currencies => _accounts.map(_extractCurrency).toSet();

  String _portfolioHeadline() {
    if (_accounts.isEmpty) return '0.00';
    if (_currencies.length == 1) {
      final currency = _currencies.first;
      final total = _accounts.fold<double>(
        0,
        (sum, account) => sum + _extractBalance(account),
      );
      return '${_formatAmount(total)} ${_currencySymbol(currency)}';
    }
    return '${_accounts.length} счёта';
  }

  String _portfolioSubtitle() {
    if (_accounts.isEmpty) {
      return 'Подключите первый счёт, чтобы видеть баланс и историю операций.';
    }
    if (_currencies.length == 1) {
      return 'Все активные счета в валюте ${_currencies.first}.';
    }
    return '${_currencies.length} валюты в портфеле. Баланс сгруппирован по карточкам ниже.';
  }

  String _lastUpdatedLabel() {
    if (_isLoading && _lastUpdatedAt == null) return 'Синхронизация';
    if (_lastUpdatedAt == null) return 'Не обновлялось';
    final hour = _lastUpdatedAt!.hour.toString().padLeft(2, '0');
    final minute = _lastUpdatedAt!.minute.toString().padLeft(2, '0');
    return 'Обновлено $hour:$minute';
  }

  Future<void> _selectAccount(int index) async {
    if (index < 0 || index >= _accounts.length) return;
    setState(() => _selectedAccountIndex = index);
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openTransfer() {
    final account = _selectedAccount;
    final accountId = account == null ? null : _extractAccountId(account);
    final currency = account == null ? null : _extractCurrency(account);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransferScreen(
          prefilledFromAccountId: accountId,
          preferredCurrency: currency,
        ),
      ),
    );
  }

  void _openHistory() {
    final account = _selectedAccount;
    final accountId = account == null ? null : _extractAccountId(account);
    if (accountId == null) {
      _showMessage('Сначала загрузите и выберите счёт.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountHistoryScreen(accountId: accountId),
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
            child: RefreshIndicator(
              onRefresh: _loadAccounts,
              color: BankColors.primary,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 124),
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 20),
                  _buildPortfolioCard(),
                  const SizedBox(height: 20),
                  _buildQuickActions(),
                  const SizedBox(height: 28),
                  if (_errorMessage != null && _accounts.isEmpty)
                    _buildErrorState()
                  else if (_isLoading && _accounts.isEmpty)
                    _buildLoadingState()
                  else if (_accounts.isEmpty)
                    _buildEmptyState()
                  else ...[
                    const BankSectionHeader(
                      title: 'Мои счета',
                      subtitle: 'Листайте карточки и открывайте историю по каждому счёту.',
                    ),
                    const SizedBox(height: 16),
                    _buildAccountsCarousel(),
                    const SizedBox(height: 16),
                    _buildAccountIndicators(),
                    const SizedBox(height: 24),
                    _buildInsights(),
                    const SizedBox(height: 24),
                    const BankSectionHeader(
                      title: 'Быстрый список',
                      subtitle: 'Подробности по каждому счёту и переход в историю операций.',
                    ),
                    const SizedBox(height: 14),
                    _buildAccountsList(),
                  ],
                ],
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
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [BankColors.heroStart, BankColors.heroEnd],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.account_balance_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Azizkhan Bank',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: BankColors.textPrimary,
                ),
              ),
              Text(
                _isLoading && _accounts.isNotEmpty
                    ? 'Обновляем данные по счетам...'
                    : 'Ваши счета, переводы и контроль операций.',
                style: const TextStyle(
                  fontSize: 13,
                  color: BankColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        BankSoftIconButton(
          icon: Icons.refresh_rounded,
          onPressed: _loadAccounts,
        ),
        const SizedBox(width: 8),
        BankSoftIconButton(
          icon: Icons.logout_rounded,
          onPressed: _logout,
        ),
      ],
    );
  }

  Widget _buildPortfolioCard() {
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
          Row(
            children: [
              Text(
                'Общий баланс',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.74),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _hideBalances = !_hideBalances),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _hideBalances
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _hideBalances ? '••••••' : _portfolioHeadline(),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _portfolioSubtitle(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              BankStatusPill(
                label: '${_accounts.length} активных',
                icon: Icons.account_balance_wallet_rounded,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
              ),
              BankStatusPill(
                label: _lastUpdatedLabel(),
                icon: _isLoading ? Icons.sync_rounded : Icons.check_circle_rounded,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildQuickActionTile(
            icon: Icons.send_rounded,
            label: 'Перевод',
            subtitle: 'По выбранному счёту',
            color: BankColors.primary,
            onTap: _openTransfer,
          ),
          _buildQuickActionTile(
            icon: Icons.receipt_long_rounded,
            label: 'История',
            subtitle: 'Последние операции',
            color: BankColors.success,
            onTap: _openHistory,
          ),
          _buildQuickActionTile(
            icon: Icons.sync_rounded,
            label: 'Обновить',
            subtitle: 'Синхронизация счетов',
            color: BankColors.warning,
            onTap: _loadAccounts,
          ),
          _buildQuickActionTile(
            icon: _hideBalances
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            label: _hideBalances ? 'Показать' : 'Скрыть',
            subtitle: 'Защита баланса',
            color: BankColors.primaryDark,
            onTap: () => setState(() => _hideBalances = !_hideBalances),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 156,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(26),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BankColors.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: BankColors.outline),
                boxShadow: [
                  BoxShadow(
                    color: BankColors.shadow.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const Spacer(),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: BankColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: BankColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsCarousel() {
    return SizedBox(
      height: 208,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _accounts.length,
        onPageChanged: (index) => setState(() => _selectedAccountIndex = index),
        itemBuilder: (context, index) {
          final account = _accounts[index];
          final accountId = _extractAccountId(account);
          final currency = _extractCurrency(account);
          final balance = _extractBalance(account);
          final gradient = _currencyGradient(currency);

          return Padding(
            padding: EdgeInsets.only(
              right: index == _accounts.length - 1 ? 0 : 12,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedAccountIndex = index);
                _openHistory();
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.last.withValues(alpha: 0.24),
                      blurRadius: 24,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _currencyIcon(currency),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          currency,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      _maskedAccountId(accountId),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _hideBalances
                          ? '••••••'
                          : '${_formatAmount(balance)} ${_currencySymbol(currency)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Открыть историю',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.74),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_accounts.length, (index) {
        final isSelected = index == _selectedAccountIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isSelected ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isSelected ? BankColors.primary : BankColors.outline,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }

  Widget _buildInsights() {
    return Row(
      children: [
        Expanded(
          child: _buildInsightCard(
            icon: Icons.layers_rounded,
            title: 'Валют',
            value: _currencies.length.toString(),
            accent: BankColors.primary,
            background: BankColors.primarySoft,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInsightCard(
            icon: Icons.verified_user_rounded,
            title: 'Защита',
            value: 'Активна',
            accent: BankColors.success,
            background: BankColors.successSoft,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String value,
    required Color accent,
    required Color background,
  }) {
    return BankSurfaceCard(
      padding: const EdgeInsets.all(18),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: BankColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: BankColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    return BankSurfaceCard(
      padding: const EdgeInsets.all(8),
      radius: 28,
      child: Column(
        children: List.generate(_accounts.length, (index) {
          final account = _accounts[index];
          final accountId = _extractAccountId(account);
          final currency = _extractCurrency(account);
          final balance = _extractBalance(account);
          final accent = _currencyAccent(currency);
          final isSelected = index == _selectedAccountIndex;

          return Column(
            children: [
              Material(
                color: isSelected
                    ? BankColors.primarySoft.withValues(alpha: 0.65)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: () async {
                    await _selectAccount(index);
                    _openHistory();
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            _currencyIcon(currency),
                            color: accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Счёт в $currency',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: BankColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _maskedAccountId(accountId),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: BankColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _hideBalances
                                  ? '••••••'
                                  : '${_formatAmount(balance)} ${_currencySymbol(currency)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: BankColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'История',
                              style: TextStyle(
                                fontSize: 12,
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index != _accounts.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(height: 1),
                ),
            ],
          );
        }),
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
        child: ElevatedButton.icon(
          onPressed: _openTransfer,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Новый перевод'),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return BankSurfaceCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      child: Column(
        children: const [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(BankColors.primary),
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Загружаем счета',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Подтягиваем баланс и доступные карточки для мобильного дашборда.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: BankColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return BankSurfaceCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: BankColors.dangerSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: BankColors.danger,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Не удалось загрузить счета',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Попробуйте обновить данные ещё раз.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: BankColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _loadAccounts,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return BankSurfaceCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      child: Column(
        children: const [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: BankColors.textTertiary,
          ),
          SizedBox(height: 16),
          Text(
            'Счета пока не найдены',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'После подключения счёта здесь появятся карточки, баланс и быстрые действия.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: BankColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
