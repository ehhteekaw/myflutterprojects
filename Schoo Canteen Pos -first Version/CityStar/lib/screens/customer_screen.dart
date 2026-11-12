import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/customer.dart';
import '../services/api_service.dart';
import '../widgets/topup_dialog.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  late Future<List<dynamic>> _customersFuture;
  List<dynamic> _allCustomers = [];
  List<dynamic> _filteredCustomers = [];
  final TextEditingController _searchController = TextEditingController();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'MMK ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  void _loadCustomers() {
    setState(() {
      _customersFuture = ApiService().getAllCustomers().then((data) {
        _allCustomers = data;
        _filteredCustomers = data;
        return data;
      });
    });
  }

  // Search Logic
  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _allCustomers;
      } else {
        _filteredCustomers = _allCustomers.where((c) {
          final name = c['name'].toString().toLowerCase();
          final card = c['card_number'].toString().toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || card.contains(q);
        }).toList();
      }
    });
  }

  // Add / Edit Dialog
  void _showCustomerFormDialog({
    int? id,
    String? currentCard,
    String? currentName,
    String? currentType,
  }) {
    final cardCtrl = TextEditingController(text: currentCard);
    final nameCtrl = TextEditingController(text: currentName);
    String type = currentType ?? 'Student';
    final isEditing = id != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Student' : 'Add New Student'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: cardCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Card ID / Student ID',
                  ),
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Student Name'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: ['Student', 'Teacher', 'Staff']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => type = val!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newCard = cardCtrl.text.trim();
                  final newName = nameCtrl.text.trim();
                  final newType = type;

                  // Dialog ကို ပိတ်မယ်
                  Navigator.pop(context);

                  if (isEditing) {
                    // --- EDIT (Optimistic Update) ---
                    setState(() {
                      final index = _allCustomers.indexWhere(
                        (element) => element['id'] == id,
                      );
                      if (index != -1) {
                        _allCustomers[index]['card_number'] = newCard;
                        _allCustomers[index]['name'] = newName;
                        _allCustomers[index]['customer_type'] = newType;
                      }
                      _filterCustomers(_searchController.text);
                    });

                    final success = await ApiService().updateCustomer(
                      id,
                      newCard,
                      newName,
                      newType,
                    );

                    if (!context.mounted) return;
                    if (!success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Failed to update on server. Refreshing...',
                          ),
                        ),
                      );
                      _loadCustomers(); // Error တက်ရင် Data ကို ပြန် Sync လုပ်မယ်
                    }
                  } else {
                    // --- ADD အသစ်ထည့်တဲ့အပိုင်း ---
                    final newCustomer = await ApiService().addCustomer(
                      newCard,
                      newName,
                      newType,
                    );

                    if (!context.mounted) return;

                    if (newCustomer != null) {
                      setState(() {
                        _allCustomers.insert(0, newCustomer);
                        _filterCustomers(_searchController.text);
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Operation failed. Card number might already exist.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Text(isEditing ? 'Update' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Delete Confirm Dialog
  void _showDeleteDialog(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student?'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Dialog ပိတ်မယ်
              Navigator.pop(context);

              // --- DELETE (Optimistic Update) ---
              setState(() {
                _allCustomers.removeWhere((element) => element['id'] == id);
                _filteredCustomers.removeWhere(
                  (element) => element['id'] == id,
                );
              });

              final success = await ApiService().deleteCustomer(id);

              if (!context.mounted) return;
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete on server. Refreshing...'),
                  ),
                );
                _loadCustomers();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Student ID Card & Balance Management'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _customersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No students found.'));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // ----- အပေါ်ပိုင်း Search နဲ့ Add Button -----
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterCustomers,
                        decoration: InputDecoration(
                          hintText: 'Search by Student ID or Name...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _showCustomerFormDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Add New Student',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ----- အောက်ပိုင်း Data Table -----
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            Colors.grey[50],
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'CARD ID / STUDENT ID',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'STUDENT NAME',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'CLASS / GRADE',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'CURRENT BALANCE',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'ACTIONS',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: _filteredCustomers.map((c) {
                            final balance = (c['balance'] as num).toDouble();
                            final isZero = balance == 0;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      c['card_number'],
                                      style: TextStyle(
                                        color: Colors.blue[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    c['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                DataCell(Text(c['customer_type'])),
                                DataCell(
                                  Text(
                                    _currencyFormat.format(balance),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isZero ? Colors.red : Colors.green,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[600],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                        ),
                                        onPressed: () async {
                                          final updatedCustomer =
                                              await showDialog<Customer>(
                                                context: context,
                                                builder: (_) => TopUpDialog(
                                                  initialCardNumber:
                                                      c['card_number'],
                                                ),
                                              );

                                          if (updatedCustomer != null) {
                                            setState(() {
                                              final index = _allCustomers
                                                  .indexWhere(
                                                    (element) =>
                                                        element['id'] ==
                                                        updatedCustomer.id,
                                                  );
                                              if (index != -1) {
                                                _allCustomers[index]['balance'] =
                                                    updatedCustomer.balance;
                                              }

                                              final filteredIndex =
                                                  _filteredCustomers.indexWhere(
                                                    (element) =>
                                                        element['id'] ==
                                                        updatedCustomer.id,
                                                  );
                                              if (filteredIndex != -1) {
                                                _filteredCustomers[filteredIndex]['balance'] =
                                                    updatedCustomer.balance;
                                              }
                                            });
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.credit_card,
                                          size: 18,
                                        ),
                                        label: const Text('Top-Up'),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        tooltip: 'Edit',
                                        onPressed: () =>
                                            _showCustomerFormDialog(
                                              id: c['id'],
                                              currentCard: c['card_number'],
                                              currentName: c['name'],
                                              currentType: c['customer_type'],
                                            ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        tooltip: 'Delete',
                                        onPressed: () => _showDeleteDialog(
                                          c['id'],
                                          c['name'],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
