import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Shop ID အတွက်

import '../services/api_service.dart';
import '../models/product.dart';
import 'category_screen.dart';
import 'product_form_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  Future<List<Product>>? _productsFuture;
  int _currentShopId = 1; // Default

  @override
  void initState() {
    super.initState();
    _loadShopIdAndProducts();
  }

  Future<void> _loadShopIdAndProducts() async {
    // သိမ်းထားတဲ့ Shop ID ကို ယူမယ်
    final prefs = await SharedPreferences.getInstance();
    _currentShopId = prefs.getInt('shop_id') ?? 1;
    _loadProducts();
  }

  void _loadProducts() {
    setState(() {
      _productsFuture = ApiService().getProducts(_currentShopId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoryScreen()),
              );
              _loadProducts();
            },
            icon: const Icon(Icons.category, color: Colors.black),
            label: const Text(
              'Manage Categories',
              style: TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductFormScreen()),
          );
          if (result == true) _loadProducts();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No products found.'));
          }

          final products = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return Card(
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              // --- ဒီနေရာမှာ ပြင်ထားပါတယ် ---
                              // ပုံ URL က http နဲ့ စရင် တိုက်ရိုက်သုံးမယ်၊ မဟုတ်ရင် baseUrl နဲ့ ပေါင်းမယ်
                              p.imageUrl!.startsWith('http')
                                  ? p.imageUrl!
                                  : '${ApiService.baseUrl}${p.imageUrl}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                if (kDebugMode) {
                                  print('IMAGE ERROR: $error');
                                }
                                return const Icon(
                                  Icons.broken_image,
                                  color: Colors.red,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.inventory_2,
                            color: Colors.blue,
                            size: 40,
                          ),
                  ),
                  title: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('SKU: ${p.sku}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${p.price} MMK',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductFormScreen(product: p),
                            ),
                          );
                          if (result == true) _loadProducts();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete Product?'),
                              content: Text(
                                'Are you sure you want to delete ${p.name}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
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
                            final success = await ApiService().deleteProduct(
                              p.id,
                            );
                            if (success && mounted) _loadProducts();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
