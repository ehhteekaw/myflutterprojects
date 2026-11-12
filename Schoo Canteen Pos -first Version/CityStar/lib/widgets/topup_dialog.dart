import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../models/customer.dart';

class TopUpDialog extends StatefulWidget {
  final String? initialCardNumber;

  const TopUpDialog({super.key, this.initialCardNumber});

  @override
  State<TopUpDialog> createState() => _TopUpDialogState();
}

class _TopUpDialogState extends State<TopUpDialog> {
  final _cardCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  // --- အသစ်ထည့်လိုက်တဲ့ FocusNode ---
  final FocusNode _cardFocusNode = FocusNode();

  Customer? _foundCustomer;
  bool _isLoading = false;
  String? _errorMsg;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'MMK ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();

    // Dialog ပွင့်လာတာနဲ့ Card ID Field ကို Focus လုပ်မယ်
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cardFocusNode.requestFocus();
    });

    if (widget.initialCardNumber != null &&
        widget.initialCardNumber!.isNotEmpty) {
      _cardCtrl.text = widget.initialCardNumber!;
      _search();
    }
  }

  @override
  void dispose() {
    // မလိုအပ်တော့ရင် FocusNode ကို ရှင်းမယ်
    _cardFocusNode.dispose();
    _cardCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_cardCtrl.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final customer = await ApiService().getCustomer(_cardCtrl.text.trim());

    setState(() {
      _foundCustomer = customer;
      _isLoading = false;
      if (customer == null) {
        _errorMsg = 'Card not found! Please check the number.';
      } else {
        // ကတ်ရှာတွေ့ရင် Amount ထည့်တဲ့နေရာကို Focus ပြောင်းပေးမယ် (အဆင်ပြေစေဖို့)
        // ဒါပေမယ့် မလိုအပ်ရင် ဒီလိုင်းကို ဖျက်လို့ရပါတယ်
        // FocusScope.of(context).requestFocus(_amountFocusNode);
      }
    });
  }

  Future<void> _process(bool isTopUp) async {
    if (_foundCustomer == null || _amountCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    final updated = await ApiService().updateBalance(
      _foundCustomer!.cardNumber,
      amount,
      isTopUp,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (updated != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          title: const Text('Success!'),
          content: Text(
            '${isTopUp ? "Top Up" : "Withdraw"} Successful.\n\nNew Balance: ${_currencyFormat.format(updated.balance)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context, updated);
                },
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.error, color: Colors.red, size: 60),
          title: const Text('Failed'),
          content: const Text(
            'Transaction Failed. Please check the amount or balance.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Card Top Up / Withdraw'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Card Search Section ---
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cardCtrl,
                    focusNode:
                        _cardFocusNode, // <--- ဒီနေရာမှာ FocusNode ကို ချိတ်ပါ
                    decoration: const InputDecoration(
                      labelText: 'Scan/Enter Card No.',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : _search,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),

            if (_errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorMsg!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // --- Customer Info Section (ကတ်တွေ့ရင် ပြမယ်) ---
            if (_foundCustomer != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          _foundCustomer!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Balance:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _currencyFormat.format(_foundCustomer!.balance),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // --- Amount Input ---
              TextField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount (MMK)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              // --- Action Buttons ---
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _process(false), // Withdraw
                      child: const Text(
                        'Withdraw',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _process(true), // Top Up
                      child: const Text(
                        'Top Up',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
