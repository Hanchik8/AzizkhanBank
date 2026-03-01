import 'package:azizkhan_bank_app/api/api_service.dart';
import 'package:azizkhan_bank_app/screens/account_history_screen.dart';
import 'package:azizkhan_bank_app/screens/transfer_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _accounts = <dynamic>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAccountsInInit();
  }

  Future<void> _loadAccountsInInit() async {
    await _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accounts = await _apiService.getAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
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

  int? _extractAccountId(dynamic account) {
    if (account is! Map<String, dynamic>) {
      return null;
    }

    final value = account['id'];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String _extractCurrency(dynamic account) {
    if (account is! Map<String, dynamic>) {
      return '-';
    }
    final value = account['currency'];
    return value?.toString() ?? '-';
  }

  String _extractBalance(dynamic account) {
    if (account is! Map<String, dynamic>) {
      return '-';
    }
    final value = account['balance'];
    return value?.toString() ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Azizkhan Bank')),
      body: SafeArea(child: _buildBody()),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Open Transfer Screen',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TransferScreen(),
            ),
          );
        },
        child: const Icon(Icons.compare_arrows),
      ),
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
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadAccounts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_accounts.isEmpty) {
      return const Center(child: Text('No accounts found'));
    }

    return RefreshIndicator(
      onRefresh: _loadAccounts,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _accounts.length,
        itemBuilder: (context, index) {
          final account = _accounts[index];
          final accountId = _extractAccountId(account);
          final currency = _extractCurrency(account);
          final balance = _extractBalance(account);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              onTap: accountId == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AccountHistoryScreen(
                            accountId: accountId,
                          ),
                        ),
                      );
                    },
              title: Text('ID: ${accountId ?? '-'}'),
              subtitle: Text('Currency: $currency'),
              trailing: Text(
                'Balance: $balance',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          );
        },
      ),
    );
  }
}
