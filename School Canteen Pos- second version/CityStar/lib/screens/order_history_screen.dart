import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

import 'dart:typed_data';

import '../services/api_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<dynamic> _allOrders = [];
  Future<Map<String, dynamic>>? _summaryFuture;
  Future<List<dynamic>>? _topProductsFuture;

  String _currentRole = '';
  int? _currentShopId;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  int _currentPage = 0;
  final int _itemsPerPage = 10; // Table အတွက် ၁၀ ခု

  bool _isLoading = true;

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final shopIdToFetch = _currentRole == 'SuperAdmin' ? null : _currentShopId;
    final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final toStr = DateFormat('yyyy-MM-dd').format(_toDate);

    final orders = await ApiService().getOrders(
      shopId: shopIdToFetch,
      fromDate: fromStr,
      toDate: toStr,
    );

    _summaryFuture = ApiService().getSalesSummary(
      shopId: shopIdToFetch,
      fromDate: fromStr,
      toDate: toStr,
    );
    _topProductsFuture = ApiService().getTopSellingProducts(
      shopId: shopIdToFetch,
      fromDate: fromStr,
      toDate: toStr,
    );

    setState(() {
      _allOrders = orders;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _loadData();
    }
  }

  List<dynamic> get _paginatedOrders {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _allOrders.length) return [];
    return _allOrders.sublist(
      startIndex,
      endIndex > _allOrders.length ? _allOrders.length : endIndex,
    );
  }

  int get _totalPages => (_allOrders.length / _itemsPerPage).ceil();

  Future<void> _exportToExcel() async {
    if (_allOrders.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln('Order ID,Date,Time,Shop,Customer,Total Amount (MMK)');

      for (var order in _allOrders) {
        final createdAt = order['created_at'] != null
            ? DateTime.parse(order['created_at']).toLocal()
            : null;
        final id = order['id'];
        final date = createdAt != null
            ? DateFormat('yyyy-MM-dd').format(createdAt)
            : '';
        final time = createdAt != null
            ? DateFormat('hh:mm a').format(createdAt)
            : '';
        final shopName = '"${order['shop_name'] ?? 'Unknown Shop'}"';
        final customer = '"${order['customer_name'] ?? 'Walk-in'}"';
        final amount = order['total_amount'];

        csvBuffer.writeln('$id,$date,$time,$shopName,$customer,$amount');
      }

      String csvData = csvBuffer.toString();
      Uint8List bytes = Uint8List.fromList(utf8.encode(csvData));

      Uri? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Save Order Report',
        fileName:
            'Order_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (outputFile == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report Saved Successfully!\nLocation: $outputFile'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Order History & Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----- Top Bar (Date & Export) -----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _pickDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${DateFormat('dd MMM yyyy').format(_fromDate)}  -  ${DateFormat('dd MMM yyyy').format(_toDate)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _exportToExcel,
                    icon: const Icon(Icons.download),
                    label: const Text('Export to Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // ----- Summary Cards (3 items) -----
                FutureBuilder<Map<String, dynamic>>(
                  future: _summaryFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final s = snapshot.data!;

                    // Null ဖြစ်နေရင် 0 ပြဖို့ ကာကွယ်မယ်
                    final totalSales =
                        (s['total_sales'] as num?)?.toDouble() ?? 0.0;
                    final cardSales =
                        (s['card_sales'] as num?)?.toDouble() ?? 0.0;
                    final totalOrders = s['total_orders'] ?? 0;

                    return Row(
                      children: [
                        _buildSummaryCard(
                          'Filtered Revenue',
                          _currencyFormat.format(totalSales),
                          Icons.attach_money,
                          Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _buildSummaryCard(
                          'ID Card Sales',
                          _currencyFormat.format(cardSales),
                          Icons.credit_card,
                          Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _buildSummaryCard(
                          'Orders Count',
                          '$totalOrders',
                          Icons.receipt,
                          Colors.purple,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ----- Top Selling Products -----
                const Text(
                  'Top-Selling Products',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<dynamic>>(
                  future: _topProductsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final topProducts = snapshot.data!;
                    return SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: topProducts.length,
                        itemBuilder: (context, index) {
                          final p = topProducts[index];
                          final rank = index + 1;
                          return Container(
                            width: 150,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child:
                                          p['image_url'] != null &&
                                              p['image_url']
                                                  .toString()
                                                  .isNotEmpty
                                          ? Image.network(
                                              p['image_url']
                                                      .toString()
                                                      .startsWith('http')
                                                  ? p['image_url']
                                                  : '${ApiService.baseUrl}${p['image_url']}',
                                              height: 100,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                    height: 100,
                                                    width: double.infinity,
                                                    color: Colors.grey[200],
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              height: 100,
                                              width: double.infinity,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.image,
                                                color: Colors.grey,
                                              ),
                                            ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: rank == 1
                                            ? Colors.amber
                                            : (rank == 2
                                                  ? Colors.grey
                                                  : Colors.brown),
                                        child: Text(
                                          '$rank',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Sold: ${p['total_qty']} units',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ----- Recent Orders Table -----
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Orders Table',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Showing ${_currentPage * _itemsPerPage + 1}-${(_currentPage + 1) * _itemsPerPage > _allOrders.length ? _allOrders.length : (_currentPage + 1) * _itemsPerPage} of ${_allOrders.length} orders',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                'No.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Order Code',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Date & Time',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Customer',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Total Price',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_allOrders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('No orders found.')),
                        )
                      else
                        ..._paginatedOrders.map((order) {
                          final createdAt = order['created_at'] != null
                              ? DateTime.parse(order['created_at']).toLocal()
                              : null;
                          final time = createdAt != null
                              ? DateFormat('hh:mm a').format(createdAt)
                              : '--:--';
                          final dateStr = createdAt != null
                              ? DateFormat('dd MMM yyyy').format(createdAt)
                              : '';
                          final customerName =
                              order['customer_name'] ?? 'Walk-in';
                          final totalAmount =
                              (order['total_amount'] as num?)?.toDouble() ??
                              0.0;
                          final orderNo = _allOrders.indexOf(order) + 1;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 1, child: Text('$orderNo')),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '#${order['id']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '$dateStr • $time',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Expanded(flex: 2, child: Text(customerName)),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _currencyFormat.format(totalAmount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),

                      // Pagination Footer
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Page ${_currentPage + 1} of $_totalPages',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _currentPage == 0
                                      ? null
                                      : () => setState(() => _currentPage--),
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                ...List.generate(
                                  _totalPages > 5 ? 5 : _totalPages,
                                  (index) {
                                    return GestureDetector(
                                      onTap: () =>
                                          setState(() => _currentPage = index),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        width: 32,
                                        height: 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _currentPage == index
                                              ? Colors.blue
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: _currentPage == index
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  onPressed: _currentPage >= _totalPages - 1
                                      ? null
                                      : () => setState(() => _currentPage++),
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
