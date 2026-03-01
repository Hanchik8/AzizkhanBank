import 'package:azizkhan_bank_app/api/api_service.dart';
import 'package:flutter/material.dart';

class AccountHistoryScreen extends StatefulWidget {
  const AccountHistoryScreen({super.key, required this.accountId});

  final int accountId;

  @override
  State<AccountHistoryScreen> createState() => _AccountHistoryScreenState();
}

class _AccountHistoryScreenState extends State<AccountHistoryScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _history = <dynamic>[];

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
        _history = history;
      });
    } catch (error) {
      if (!mounted) return;
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

  String _field(dynamic entry, String key, {String fallback = '-'}) {
    if (entry is! Map<String, dynamic>) {
      return fallback;
    }
    final value = entry[key];
    return value?.toString() ?? fallback;
  }

  String _formatTimestamp(String rawTimestamp) {
    final parsed = DateTime.tryParse(rawTimestamp);
    if (parsed == null) {
      return rawTimestamp;
    }

    final local = parsed.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute:$second';
  }

  Color _typeColor(String type) {
    final normalized = type.toUpperCase();
    if (normalized == 'CREDIT') {
      return Colors.green;
    }
    if (normalized == 'DEBIT') {
      return Colors.red;
    }
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Account ${widget.accountId} History')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadHistory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return const Center(child: Text('No transactions'));
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          final amount = _field(item, 'amount');
          final currency = _field(item, 'currency');
          final type = _field(item, 'type').toUpperCase();
          final timestamp = _formatTimestamp(_field(item, 'timestamp'));
          final color = _typeColor(type);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              title: Text('Type: $type'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Date & time: $timestamp'),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: <InlineSpan>[
                        const TextSpan(text: 'Amount: '),
                        TextSpan(
                          text: amount,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: ' $currency'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
