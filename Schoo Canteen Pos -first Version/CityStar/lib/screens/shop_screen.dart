import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late Future<List<dynamic>> _shopsFuture;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  void _loadShops() {
    setState(() {
      _shopsFuture = ApiService().getShops();
    });
  }

  // Add / Edit Dialog
  void _showShopDialog({int? id, String? currentName}) {
    final nameCtrl = TextEditingController(text: currentName);
    final isEditing = id != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Shop' : 'Add New Shop'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Shop Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              bool success;
              if (isEditing) {
                success = await ApiService().updateShop(id, name);
              } else {
                success = await ApiService().addShop(name);
              }

              if (success && mounted) {
                Navigator.pop(context);
                _loadShops(); // Reload list
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Operation failed')),
                );
              }
            },
            child: Text(isEditing ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Shops')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showShopDialog(),
        child: const Icon(Icons.add_business),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _shopsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No shops found.'));
          }

          final shops = snapshot.data!;
          return ListView.builder(
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final s = shops[index];
              return ListTile(
                leading: const Icon(Icons.store, color: Colors.orange),
                title: Text(s['shop_name']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showShopDialog(
                        id: s['id'],
                        currentName: s['shop_name'],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Shop?'),
                            content: Text(
                              'Are you sure you want to delete ${s['shop_name']}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final success = await ApiService().deleteShop(
                            s['id'],
                          );
                          if (success && mounted) _loadShops();
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
