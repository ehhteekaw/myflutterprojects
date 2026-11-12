import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider/cart_provider.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/customer.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  Future<List<Product>>? _productsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'Ks ',
    decimalDigits: 0,
  );

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt('shop_id') ?? 1;
    setState(() {
      _productsFuture = ApiService().getProducts(shopId);
    });
  }

  // =========================================================
  // Payment Dialog - ကတ်နံပါတ် ထည့်ခိုင်းတဲ့ Dialog အသစ်
  // =========================================================
  Future<void> _showPaymentDialog(CartProvider cart) async {
    final cardCtrl = TextEditingController();
    Customer? foundCustomer;
    bool isSearching = false;
    String? errorMsg;

    await showDialog(
      context: context,
      barrierDismissible: false, // Dialog အပြင်ကို နှိပ်လို့ မပိတ်ရဘူး
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Payment - Scan Card'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Please scan or enter the student/staff card number to proceed.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cardCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Card Number',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) async {
                          // Enter နှိပ်ရင်လည်း ရှာမယ်
                          setDialogState(() => isSearching = true);
                          final c = await ApiService().getCustomer(
                            cardCtrl.text.trim(),
                          );
                          setDialogState(() {
                            foundCustomer = c;
                            isSearching = false;
                            if (c == null) errorMsg = 'Card not found!';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: isSearching
                          ? null
                          : () async {
                              setDialogState(() => isSearching = true);
                              final c = await ApiService().getCustomer(
                                cardCtrl.text.trim(),
                              );
                              setDialogState(() {
                                foundCustomer = c;
                                isSearching = false;
                                if (c == null) errorMsg = 'Card not found!';
                              });
                            },
                      icon: isSearching
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),

                // ကတ်တွေ့ရင် အချက်အလက် ပြမယ်
                if (foundCustomer != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          foundCustomer!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${foundCustomer!.customerType} • ${foundCustomer!.cardNumber}',
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
                              _currencyFormat.format(foundCustomer!.balance),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color:
                                    foundCustomer!.balance >= cart.totalAmount
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        if (foundCustomer!.balance < cart.totalAmount)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Insufficient balance for this order!',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                // ကတ်တွေ့ပြီး၊ လက်ကျန်ငွေ လုံလောက်မှ Confirm လုပ်ခွင့်ပြုမယ်
                onPressed:
                    (foundCustomer == null ||
                        foundCustomer!.balance < cart.totalAmount)
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        _checkout(cart, foundCustomer!);
                      },
                child: const Text('Confirm Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================
  // Checkout API ခေါ်ခြင်း
  // =========================================================
  Future<void> _checkout(CartProvider cart, Customer customer) async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt('shop_id') ?? 1;

    List<Map<String, dynamic>> orderItems = cart.items.values.map((item) {
      final p = item['product'] as Product;
      return {
        'product_id': p.id,
        'quantity': item['quantity'],
        'price': p.price,
      };
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await ApiService().checkout(
      shopId: shopId,
      cardNumber: customer.cardNumber,
      items: orderItems,
      totalAmount: cart.totalAmount,
    );

    if (mounted) Navigator.pop(context); // Loading ပိတ်

    if (result.containsKey('success')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment Successful! Balance: ${_currencyFormat.format(customer.balance - cart.totalAmount)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        cart.clearCart();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Payment Failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS')),
      body: Row(
        children: [
          // ================= Products Grid =================
          Expanded(
            flex: 2,
            child: FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (_productsFuture == null ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No products found.'));
                }

                final products = snapshot.data!;
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: products.length,
                  itemBuilder: (c, i) {
                    final p = products[i];
                    return Card(
                      elevation: 2,
                      child: InkWell(
                        onTap: () => context.read<CartProvider>().addToCart(p),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                                child:
                                    p.imageUrl != null && p.imageUrl!.isNotEmpty
                                    ? Image.network(
                                        p.imageUrl!.startsWith('http')
                                            ? p.imageUrl!
                                            : '${ApiService.baseUrl}${p.imageUrl}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.inventory_2,
                                          color: Colors.grey,
                                          size: 40,
                                        ),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currencyFormat.format(p.price),
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ================= Cart Side =================
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  // Header အပိုင်း (Customer မပါတော့ဘူး)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: const Row(
                      children: [
                        Icon(Icons.shopping_cart, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Current Order',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Cart Items List
                  Expanded(
                    child: Consumer<CartProvider>(
                      builder: (context, cart, _) {
                        if (cart.items.isEmpty) {
                          return const Center(
                            child: Text('Cart is empty. Tap products to add.'),
                          );
                        }
                        return ListView.builder(
                          itemCount: cart.items.length,
                          itemBuilder: (context, index) {
                            final item = cart.items.values.toList()[index];
                            final p = item['product'] as Product;
                            final qty = item['quantity'] as int;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            _currencyFormat.format(p.price),
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              cart.decreaseQuantity(p.id),
                                        ),
                                        Text(
                                          '$qty',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                            color: Colors.green,
                                          ),
                                          onPressed: () =>
                                              cart.increaseQuantity(p.id),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        _currencyFormat.format(p.price * qty),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const Divider(height: 1),

                  // Total & Pay Button
                  Consumer<CartProvider>(
                    builder: (context, cart, _) => Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.white,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _currencyFormat.format(cart.totalAmount),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: cart.items.isEmpty
                                  ? null
                                  : () => _showPaymentDialog(cart),
                              child: const Text(
                                'PAY NOW',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
