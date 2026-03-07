import 'package:azizkhan_bank_app/api/api_service.dart';
import 'package:azizkhan_bank_app/ui/bank_ui.dart';
import 'package:flutter/material.dart';

class AccountHistoryScreen extends StatefulWidget {
  const AccountHistoryScreen({super.key, required this.accountId});

  final int accountId;

  @override
  State<AccountHistoryScreen> createState() => _AccountHistoryScreenState();
}

enum _HistoryFilter { all, credit, debit }

class _AccountHistoryScreenState extends State<AccountHistoryScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final history = await _apiService.getAccountHistory(widget.accountId);
      if (!mounted) return;
      setState(() {
        _history = history.whereType<Map<String, dynamic>>().toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _field(Map<String, dynamic> entry, String key, {String fallback = '-'}) {
    return entry[key]?.toString() ?? fallback;
  }

  String _formatTimestamp(String rawTimestamp) {
    final parsed = DateTime.tryParse(rawTimestamp);
    if (parsed == null) return rawTimestamp;

    final local = parsed.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';

    if (isToday) return 'Сегодня, $time';

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;
    if (isYesterday) return 'Вчера, $time';

    final months = [
      '',
      'янв',
      'фев',
      'мар',
      'апр',
      'мая',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return '${local.day} ${months[local.month]} ${local.year}, $time';
  }

  Color _typeColor(String type) {
    final normalized = type.toUpperCase();
    if (normalized == 'CREDIT') return BankColors.success;
    if (normalized == 'DEBIT') return BankColors.danger;
    return BankColors.textSecondary;
  }

  IconData _typeIcon(String type) {
    final normalized = type.toUpperCase();
    if (normalized == 'CREDIT') return Icons.arrow_downward_rounded;
    if (normalized == 'DEBIT') return Icons.arrow_upward_rounded;
    return Icons.swap_horiz_rounded;
  }

  String _typeLabel(String type) {
    final normalized = type.toUpperCase();
    if (normalized == 'CREDIT') return 'Зачисление';
    if (normalized == 'DEBIT') return 'Списание';
    return type;
  }

  String _formatAmount(String amount, String type) {
    final normalized = type.toUpperCase();
    final prefix = normalized == 'CREDIT' ? '+' : '-';
    return '$prefix $amount';
  }

  double _numericAmount(Map<String, dynamic> entry) {
    final raw = entry['amount'];
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(raw.replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_filter == _HistoryFilter.all) return _history;
    final expected = _filter == _HistoryFilter.credit ? 'CREDIT' : 'DEBIT';
    return _history
        .where((entry) => _field(entry, 'type').toUpperCase() == expected)
        .toList();
  }

  String get _incomingTotal {
    final total = _history
        .where((entry) => _field(entry, 'type').toUpperCase() == 'CREDIT')
        .fold<double>(0, (sum, entry) => sum + _numericAmount(entry));
    return total.toStringAsFixed(2);
  }

  String get _outgoingTotal {
    final total = _history
        .where((entry) => _field(entry, 'type').toUpperCase() == 'DEBIT')
        .fold<double>(0, (sum, entry) => sum + _numericAmount(entry));
    return total.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BankBackdrop(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadHistory,
              color: BankColors.primary,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 20),
                  _buildAccountHeader(),
                  const SizedBox(height: 20),
                  _buildFilterChips(),
                  const SizedBox(height: 20),
                  _buildBody(),
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
                'История операций',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BankColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Просмотр начислений и списаний по выбранному счёту.',
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

  Widget _buildAccountHeader() {
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
            'Счёт •••• ${widget.accountId}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  label: 'Операций',
                  value: _history.length.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMetric(
                  label: 'Зачисления',
                  value: _incomingTotal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryMetric(
            label: 'Списания',
            value: _outgoingTotal,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildFilterChip(_HistoryFilter.all, 'Все'),
        _buildFilterChip(_HistoryFilter.credit, 'Зачисления'),
        _buildFilterChip(_HistoryFilter.debit, 'Списания'),
      ],
    );
  }

  Widget _buildFilterChip(_HistoryFilter filter, String label) {
    return ChoiceChip(
      selected: _filter == filter,
      label: Text(label),
      onSelected: (_) => setState(() => _filter = filter),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(BankColors.primary),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return BankSurfaceCard(
        radius: 28,
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 16),
            const Text(
              'Не удалось загрузить историю',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: BankColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_filteredHistory.isEmpty) {
      return BankSurfaceCard(
        radius: 28,
        padding: const EdgeInsets.all(24),
        child: const Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: BankColors.textTertiary,
            ),
            SizedBox(height: 16),
            Text(
              'Операций не найдено',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Смените фильтр или выполните перевод, чтобы здесь появились записи.',
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

    return Column(
      children: _filteredHistory.map((item) {
        final amount = _field(item, 'amount');
        final currency = _field(item, 'currency');
        final type = _field(item, 'type').toUpperCase();
        final timestamp = _formatTimestamp(_field(item, 'timestamp'));
        final color = _typeColor(type);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BankSurfaceCard(
            radius: 26,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(_typeIcon(type), color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _typeLabel(type),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: BankColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timestamp,
                        style: const TextStyle(
                          fontSize: 13,
                          color: BankColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_formatAmount(amount, type)} $currency',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
