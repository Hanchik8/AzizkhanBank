import 'dart:convert';

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
  final TextEditingController _toAccountIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _toAccountIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitTransfer() async {
    final toAccountId = _toAccountIdController.text.trim();
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    final amount = num.tryParse(amountText);

    if (toAccountId.isEmpty) {
      _showError('Введите ID счета получателя');
      return;
    }
    if (amount == null || amount <= 0) {
      _showError('Введите корректную сумму перевода');
      return;
    }

    final idempotencyKey = _uuid.v4();

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.createTransfer(
        toAccountId: toAccountId,
        amount: amount,
        idempotencyKey: idempotencyKey,
      );
      if (!mounted) return;

      final transactionId = _extractTransactionId(result);
      final message = transactionId != null
          ? 'Перевод успешен. Transaction ID: $transactionId'
          : 'Перевод успешен. Ответ: ${jsonEncode(result)}';
      _showSnack(message, isError: false);
    } on DioException catch (error) {
      _showSnack(_resolveDioMessage(error), isError: true);
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

  String? _extractTransactionId(Map<String, dynamic> payload) {
    final knownKeys = <String>['transactionId', 'transferId', 'id'];
    for (final key in knownKeys) {
      final value = payload[key];
      if (value != null) {
        final asString = value.toString();
        if (asString.isNotEmpty) {
          return asString;
        }
      }
    }
    return null;
  }

  String _resolveDioMessage(DioException error) {
    final payload = error.response?.data;
    if (payload is Map<String, dynamic>) {
      final message = payload['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return error.message ?? 'Ошибка при выполнении перевода';
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _toAccountIdController,
                decoration: const InputDecoration(
                  labelText: 'ID счета получателя (toAccountId)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Сумма перевода (amount)',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitTransfer,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Отправить перевод'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
