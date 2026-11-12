import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reports_provider.dart';
import '../../core/database.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

enum DateFilter { today, thisWeek, thisMonth, allTime }

class ReportsDashboardScreen extends ConsumerStatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  ConsumerState<ReportsDashboardScreen> createState() =>
      _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState
    extends ConsumerState<ReportsDashboardScreen> {
  DateFilter _selectedDateFilter = DateFilter.allTime;
  String _selectedPaymentMethod = 'All';

  // ================= DATE RANGE PICKER STATES =================
  DateTime? _startDate;
  DateTime? _endDate;

  // ================= PAGINATION STATE =================
  int _currentPage = 1;
  final int _rowsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    final ordersWithUserAsync = ref.watch(ordersWithUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Analytics & Reports'),
        elevation: 1,
        actions: [
          ordersWithUserAsync.when(
            data: (ordersWithUser) => Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.file_download, size: 18),
                label: const Text('Export Excel'),
                onPressed: ordersWithUser.isEmpty
                    ? null
                    : () => _exportToExcel(
                          context,
                          ordersWithUser.map((e) => e.order).toList(),
                        ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      // 👉 တစ်မျက်နှာလုံး Scroll ဆွဲလို့ရအောင် ပြုလုပ်ထားခြင်း (Overflow လုံးဝ မရှိတော့ပါ)
      body: ordersWithUserAsync.when(
        data: (allOrdersWithUser) {
          // 1. Filter orders based on user selection
          final filteredList = allOrdersWithUser.where((item) {
            final order = item.order;
            final matchesPayment = _selectedPaymentMethod == 'All' ||
                order.paymentMethod == _selectedPaymentMethod;

            // Date Filter Chip Check
            final now = DateTime.now();
            final orderDate = order.createdAt;
            bool matchesDateChip = true;

            if (_selectedDateFilter == DateFilter.today) {
              matchesDateChip = orderDate.year == now.year &&
                  orderDate.month == now.month &&
                  orderDate.day == now.day;
            } else if (_selectedDateFilter == DateFilter.thisWeek) {
              final weekAgo = now.subtract(const Duration(days: 7));
              matchesDateChip = orderDate.isAfter(weekAgo);
            } else if (_selectedDateFilter == DateFilter.thisMonth) {
              matchesDateChip =
                  orderDate.year == now.year && orderDate.month == now.month;
            }

            // Custom Date Range Picker Check
            bool matchesDateRange = true;
            if (_startDate != null && _endDate != null) {
              final normalizedOrderDate =
                  DateTime(orderDate.year, orderDate.month, orderDate.day);
              final normalizedStart = DateTime(
                  _startDate!.year, _startDate!.month, _startDate!.day);
              final normalizedEnd =
                  DateTime(_endDate!.year, _endDate!.month, _endDate!.day);

              matchesDateRange = (normalizedOrderDate
                          .isAfter(normalizedStart) ||
                      normalizedOrderDate.isAtSameMomentAs(normalizedStart)) &&
                  (normalizedOrderDate.isBefore(normalizedEnd) ||
                      normalizedOrderDate.isAtSameMomentAs(normalizedEnd));
            }

            return matchesPayment && matchesDateChip && matchesDateRange;
          }).toList();

          // 2. Compute summary metrics for filtered orders
          final totalRevenue = filteredList.fold(
              0.0, (sum, item) => sum + item.order.totalPrice);
          final cashRevenue = filteredList
              .where((item) => item.order.paymentMethod == 'Cash')
              .fold(0.0, (sum, item) => sum + item.order.totalPrice);
          final cardRevenue = filteredList
              .where((item) => item.order.paymentMethod == 'Student ID Card')
              .fold(0.0, (sum, item) => sum + item.order.totalPrice);

          // 3. Pagination Calculations
          final totalOrders = filteredList.length;
          final totalPages = (totalOrders / _rowsPerPage).ceil();

          if (_currentPage > totalPages && totalPages > 0) {
            _currentPage = totalPages;
          }

          final startIndex = (_currentPage - 1) * _rowsPerPage;
          final endIndex = (startIndex + _rowsPerPage > totalOrders)
              ? totalOrders
              : startIndex + _rowsPerPage;

          final paginatedOrders = totalOrders > 0
              ? filteredList.sublist(startIndex, endIndex)
              : <OrderWithUser>[];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ================= FILTER CONTROLS BAR =================
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SegmentedButton<DateFilter>(
                          segments: const [
                            ButtonSegment(
                                value: DateFilter.today, label: Text('Today')),
                            ButtonSegment(
                                value: DateFilter.thisWeek,
                                label: Text('This Week')),
                            ButtonSegment(
                                value: DateFilter.thisMonth,
                                label: Text('This Month')),
                            ButtonSegment(
                                value: DateFilter.allTime,
                                label: Text('All Time')),
                          ],
                          selected: {_selectedDateFilter},
                          onSelectionChanged: (set) {
                            setState(() {
                              _selectedDateFilter = set.first;
                              _startDate = null;
                              _endDate = null;
                              _currentPage = 1;
                            });
                          },
                        ),
                        DropdownButton<String>(
                          value: _selectedPaymentMethod,
                          items: const [
                            DropdownMenuItem(
                                value: 'All',
                                child: Text('All Payment Methods')),
                            DropdownMenuItem(
                                value: 'Cash', child: Text('Cash Only')),
                            DropdownMenuItem(
                                value: 'Student ID Card',
                                child: Text('ID Card Only')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedPaymentMethod = val ?? 'All';
                              _currentPage = 1;
                            });
                          },
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.date_range, size: 18),
                              label: Text(_startDate == null
                                  ? 'From Date'
                                  : DateFormat('yyyy-MM-dd')
                                      .format(_startDate!)),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _startDate = picked;
                                    _currentPage = 1;
                                  });
                                }
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6.0),
                              child: Text('to'),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.date_range, size: 18),
                              label: Text(_endDate == null
                                  ? 'To Date'
                                  : DateFormat('yyyy-MM-dd').format(_endDate!)),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? DateTime.now(),
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _endDate = picked;
                                    _currentPage = 1;
                                  });
                                }
                              },
                            ),
                            if (_startDate != null || _endDate != null)
                              IconButton(
                                icon:
                                    const Icon(Icons.clear, color: Colors.red),
                                tooltip: 'Clear Date Filter',
                                onPressed: () {
                                  setState(() {
                                    _startDate = null;
                                    _endDate = null;
                                    _currentPage = 1;
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ================= KPI SUMMARY CARDS =================
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Filtered Revenue',
                        value: '${totalRevenue.toStringAsFixed(0)} MMK',
                        icon: Icons.attach_money,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Cash Sales',
                        value: '${cashRevenue.toStringAsFixed(0)} MMK',
                        icon: Icons.payments,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'ID Card Sales',
                        value: '${cardRevenue.toStringAsFixed(0)} MMK',
                        icon: Icons.credit_card,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Orders Count',
                        value: '${filteredList.length}',
                        icon: Icons.receipt_long,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ================= TOP-SELLING LEADERBOARD =================
                const Text('Top-Selling Products Leaderboard',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 190,
                  child: Consumer(
                    builder: (context, ref, child) {
                      final topProductsAsync =
                          ref.watch(topSellingProductsProvider);

                      return topProductsAsync.when(
                        data: (topProducts) {
                          if (topProducts.isEmpty) {
                            return const Card(
                              child: Center(
                                child: Text('No sales records yet.',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                            );
                          }

                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount:
                                topProducts.length > 5 ? 5 : topProducts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final item = topProducts[index];
                              final product = item.product;

                              return Container(
                                width: 145,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          height: 85,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: product.imageUrl != null &&
                                                  product
                                                      .imageUrl!.isNotEmpty &&
                                                  File(product.imageUrl!)
                                                      .existsSync()
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child: Image.file(
                                                      File(product.imageUrl!),
                                                      fit: BoxFit.cover),
                                                )
                                              : const Icon(Icons.fastfood,
                                                  size: 30, color: Colors.grey),
                                        ),
                                        Positioned(
                                          top: 4,
                                          left: 4,
                                          child: CircleAvatar(
                                            radius: 10,
                                            backgroundColor: index == 0
                                                ? Colors.amber
                                                : Colors.blueGrey,
                                            child: Text(
                                              '#${index + 1}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Sold: ${item.totalQuantitySold} units',
                                        style: TextStyle(
                                            color: Colors.blue.shade800,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error: $err')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Orders Table',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    if (totalOrders > 0)
                      Text(
                        'Showing ${startIndex + 1}-$endIndex of $totalOrders orders',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // ================= RECENT ORDERS TABLE & PAGINATION =================
                filteredList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(
                          child: Text(
                              'No matching orders found for selected dates.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    : Card(
                        elevation: 1,
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth:
                                      MediaQuery.of(context).size.width - 40,
                                ),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                      Colors.grey.shade100),
                                  columnSpacing: 24,
                                  columns: const [
                                    DataColumn(
                                        label: Text('No.',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Order Code',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Date & Time',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Payment',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Cashier',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Total Price',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Actions',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                  ],
                                  rows: paginatedOrders
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    final rowNumber = startIndex + index + 1;

                                    final order = item.order;
                                    final cashierName =
                                        item.user?.username ?? 'Staff';

                                    return DataRow(
                                      cells: [
                                        DataCell(Text('$rowNumber',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey))),
                                        DataCell(Text(order.orderNumber,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600))),
                                        DataCell(Text(order.createdAt
                                            .toString()
                                            .substring(0, 16))),
                                        DataCell(
                                          Chip(
                                            labelPadding: EdgeInsets.zero,
                                            backgroundColor:
                                                order.paymentMethod == 'Cash'
                                                    ? Colors.green.shade50
                                                    : Colors.blue.shade50,
                                            label: Text(
                                              order.paymentMethod,
                                              style: TextStyle(
                                                color: order.paymentMethod ==
                                                        'Cash'
                                                    ? Colors.green.shade800
                                                    : Colors.blue.shade800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(cashierName)),
                                        DataCell(
                                          Text(
                                            '${order.totalPrice.toStringAsFixed(0)} MMK',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green),
                                          ),
                                        ),
                                        DataCell(
                                          TextButton.icon(
                                            icon: const Icon(Icons.visibility,
                                                size: 16),
                                            label: const Text('View'),
                                            onPressed: () =>
                                                _showOrderDetailsDialog(context,
                                                    order, cashierName),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),

                            // ================= PAGINATION CONTROLLER BAR =================
                            if (totalPages > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border(
                                    top:
                                        BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Page $_currentPage of $totalPages',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.chevron_left),
                                          onPressed: _currentPage > 1
                                              ? () =>
                                                  setState(() => _currentPage--)
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        ...List.generate(totalPages, (index) {
                                          final pageNum = index + 1;
                                          final isSelected =
                                              pageNum == _currentPage;

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 2.0),
                                            child: InkWell(
                                              onTap: () => setState(
                                                  () => _currentPage = pageNum),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Colors.blue
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '$pageNum',
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.black87,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.chevron_right),
                                          onPressed: _currentPage < totalPages
                                              ? () =>
                                                  setState(() => _currentPage++)
                                              : null,
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
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  // Helper method to show order details dialog
  void _showOrderDetailsDialog(
      BuildContext context, Order order, String cashierName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order Details: ${order.orderNumber}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Date & Time: ${order.createdAt.toString().substring(0, 16)}'),
              Text('Cashier: $cashierName'),
              Text('Payment Method: ${order.paymentMethod}'),
              const Divider(),
              Text(
                'Total Price: ${order.totalPrice.toStringAsFixed(0)} MMK',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Excel Export Helper
  Future<void> _exportToExcel(BuildContext context, List<Order> orders) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];
      excel.rename('Sheet1', 'Sales Reports');

      sheetObject.appendRow([
        TextCellValue('Order Code'),
        TextCellValue('Date & Time'),
        TextCellValue('Payment Method'),
        TextCellValue('Total Price (MMK)')
      ]);

      for (var order in orders) {
        sheetObject.appendRow([
          TextCellValue(order.orderNumber),
          TextCellValue(order.createdAt.toString().substring(0, 16)),
          TextCellValue(order.paymentMethod),
          DoubleCellValue(order.totalPrice),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/sales_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel exported successfully to: $filePath')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export Excel: $e')),
        );
      }
    }
  }
}

// Metric Card Widget
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(30),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
