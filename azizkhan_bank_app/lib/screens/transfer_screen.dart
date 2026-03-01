import 'package:azizkhan_bank_app/api/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final ApiService _apiService = ApiService();
  final Uuid _uuid = const Uuid();
  final TextEditingController _fromAccountIdController = TextEditingController();
  final TextEditingController _toAccountIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _currency = 'KGS';
  bool _isLoading = false;

  static const List<String> _currencies = <String>['KGS', 'USD', 'EUR', 'RUB'];

  @override
  void dispose() {
    _fromAccountIdController.dispose();
    _toAccountIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  num? _parsedAmount() {
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    return num.tryParse(amountText);
  }

  String _feeText() {
    final amount = _parsedAmount();
    if (amount == null || amount <= 0) {
      return 'Fee (1%): 0.00';
    }
    final fee = amount * 0.01;
    return 'Fee (1%): ${fee.toStringAsFixed(2)}';
  }

  Future<void> _submitTransfer() async {
    final fromAccountId = _fromAccountIdController.text.trim();
    final toAccountId = _toAccountIdController.text.trim();
    final amount = _parsedAmount();

    if (fromAccountId.isEmpty) {
      _showError('Enter your account ID (fromAccountId)');
      return;
    }
    if (int.tryParse(fromAccountId) == null) {
      _showError('fromAccountId must be a number');
      return;
    }
    if (toAccountId.isEmpty) {
      _showError('Enter recipient account ID');
      return;
    }
    if (int.tryParse(toAccountId) == null) {
      _showError('toAccountId must be a number');
      return;
    }
    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }

    final idempotencyKey = _uuid.v4();

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.createTransfer(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        currency: _currency,
        idempotencyKey: idempotencyKey,
      );
      if (!mounted) return;

      _showSnack('Transfer completed successfully', isError: false);
      _fromAccountIdController.clear();
      _toAccountIdController.clear();
      _amountController.clear();
      setState(() {});
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        _showSnack('Daily limit exceeded', isError: true);
      } else {
        _showSnack(_resolveDioMessage(e), isError: true);
      }
    } catch (error) {
      _showSnack(error.toString(), isError: true);
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
    return error.message ?? 'Transfer failed';
  }

  void _showError(String message) {
    _showSnack(message, isError: true);
  }

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'You can find your account IDs on the home screen.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fromAccountIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Your account ID (fromAccountId)',
                  hintText: '1001',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _toAccountIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Recipient account ID (toAccountId)',
                  hintText: '1002',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '100.00',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _feeText(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: _currencies
                    .map(
                      (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _currency = value);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitTransfer,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send transfer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
