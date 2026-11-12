import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  // late ကို ဖျက်ပြီး ? (Nullable) လုပ်ထားပါတယ်
  Future<List<dynamic>>? _ordersFuture;
  Future<Map<String, dynamic>>? _summaryFuture;

  String _currentRole = '';
  int? _currentShopId;
  DateTime _selectedDate = DateTime.now();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'MMK ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentRole = prefs.getString('role') ?? 'Cashier';
    _currentShopId = prefs.getInt('shop_id');
    _loadData();
  }

  void _loadData() {
    final shopIdToFetch = _currentRole == 'SuperAdmin' ? null : _currentShopId;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    setState(() {
      _ordersFuture = ApiService().getOrders(
        shopId: shopIdToFetch,
        date: dateStr,
      );
      _summaryFuture = ApiService().getSalesSummary(
        shopId: shopIdToFetch,
        date: dateStr,
      );
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  void _showOrderDetails(int orderId) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<dynamic>>(
        future: ApiService().getOrderItems(orderId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(
              content: SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          final items = snapshot.data!;
          return AlertDialog(
            title: Text('Order #$orderId Details'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    dense: true,
                    title: Text(item['product_name']),
                    subtitle: Text(
                      'Qty: ${item['quantity']} x ${_currencyFormat.format(item['price'])}',
                    ),
                    trailing: Text(
                      _currencyFormat.format(item['quantity'] * item['price']),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Order History & Reports'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, color: Colors.blue),
            label: Text(
              DateFormat('dd MMM yyyy').format(_selectedDate),
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ----- Summary Card -----
          FutureBuilder<Map<String, dynamic>>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final summary = snapshot.data!;
              final totalSales =
                  (summary['total_sales'] as num?)?.toDouble() ?? 0.0;
              final totalOrders = summary['total_orders'] as int? ?? 0;

              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'Total Orders',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$totalOrders',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 50, color: Colors.white30),
                    Column(
                      children: [
                        const Text(
                          'Total Sales',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currencyFormat.format(totalSales),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // ----- Order List -----
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                // Null ဖြစ်နေရင် Loading ပြမယ်
                if (_ordersFuture == null ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No orders found for this date.'),
                  );
                }

                final orders = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    // Date String ကို သေချာ Parse လုပ်မယ်
                    final createdAt = order['created_at'] != null
                        ? DateTime.tryParse(order['created_at'])
                        : null;
                    final time = createdAt != null
                        ? DateFormat('hh:mm a').format(createdAt)
                        : '--:--';
                    final customerName = order['customer_name'] ?? 'Walk-in';
                    final totalAmount =
                        (order['total_amount'] as num?)?.toDouble() ?? 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _showOrderDetails(order['id']),
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[50],
                          child: Icon(
                            Icons.receipt_long,
                            color: Colors.green[700],
                          ),
                        ),
                        title: Text(
                          '#${order['id']} - $customerName',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(time),
                        trailing: Text(
                          _currencyFormat.format(totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
