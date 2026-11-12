import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  List<dynamic> _shops = [];
  List<dynamic> _categories = [];
  final Map<int, List<dynamic>> _subcategoriesMap = {};

  int? _selectedShopId;
  int? _selectedCategoryId;
  int? _selectedSubcategoryId;

  String _currentRole = '';
  int? _currentShopId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _currentRole = prefs.getString('role') ?? 'Cashier';
    _currentShopId = prefs.getInt('shop_id');

    final shops = await ApiService().getShops();
    final categories = await ApiService().getCategories();

    setState(() {
      _shops = shops;
      _categories = categories;
      _selectedShopId = _currentRole == 'SuperAdmin' ? null : _currentShopId;
    });

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final shopIdToFetch = _currentRole == 'SuperAdmin'
        ? _selectedShopId
        : _currentShopId;

    final products = await ApiService().getProducts(shopIdToFetch);

    setState(() {
      _allProducts = products;
      _applyFilter();
      _isLoading = false;
    });
  }

  Future<void> _onCategoryChanged(int? categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedSubcategoryId = null; // Category ပြောင်းရင် Sub ကို ရှင်းမယ်
    });

    if (categoryId != null && !_subcategoriesMap.containsKey(categoryId)) {
      final subs = await ApiService().getSubcategories(categoryId);
      setState(() => _subcategoriesMap[categoryId] = subs);
    }
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        bool matchesCategory = true;
        if (_selectedSubcategoryId != null) {
          matchesCategory = p.subcategoryId == _selectedSubcategoryId;
        } else if (_selectedCategoryId != null) {
          final subs = _subcategoriesMap[_selectedCategoryId] ?? [];
          final subIds = subs.map((s) => s['id']).toList();
          matchesCategory = subIds.contains(p.subcategoryId);
        }
        return matchesCategory;
      }).toList();
    });
  }

  // ==========================================
  // Custom Dialog ပုံစံသစ် (Result ကို ပြန်ပေးမယ်)
  // ==========================================
  Future<bool?> _showCustomCardDialog(Widget child) async {
    // showDialog က ပြန်ပေးတဲ့ Result ကို ယူပြီး Return ပြန်မယ်
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: 800,
          height: 650,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                child,
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(
                      context,
                    ), // ဒီနေရာမှာ Result မပေးဘဲ ပိတ်ရင် null ပြန်သွားမယ်
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      shape: const CircleBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
        actions: [
          // Categories ကို Custom Dialog အနေနဲ့ ခေါ်မယ်
          TextButton.icon(
            onPressed: () {
              _showCustomCardDialog(const CategoryScreen());
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
        onPressed: () {
          _showCustomCardDialog(const ProductFormScreen()).then((result) {
            if (result == true) _loadProducts();
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // ================= LEFT SIDE: Filters =================
                Container(
                  width: 250,
                  color: Colors.grey[50],
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Shop Filter (SuperAdmin ပဲ မြင်ရမယ်)
                      if (_currentRole == 'SuperAdmin') ...[
                        const Text(
                          'Shop',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _selectedShopId,
                          hint: const Text('All Shops'),
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          items: _shops
                              .map(
                                (s) => DropdownMenuItem<int>(
                                  value: s['id'],
                                  child: Text(s['shop_name']),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() => _selectedShopId = val);
                            _loadProducts();
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Category Filter
                      const Text(
                        'Category',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        hint: const Text('All Categories'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: _categories
                            .map(
                              (c) => DropdownMenuItem<int>(
                                value: c['id'],
                                child: Text(c['name']),
                              ),
                            )
                            .toList(),
                        onChanged: _onCategoryChanged,
                      ),
                      const SizedBox(height: 20),

                      // Subcategory Filter
                      if (_selectedCategoryId != null) ...[
                        const Text(
                          'Subcategory',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _selectedSubcategoryId,
                          hint: const Text('All Subcategories'),
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          items: [
                            // "All Subcategories" ရွေးချယ်မှု ထည့်မယ် (တန်ဖိုးက null)
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('All Subcategories'),
                            ),
                            ...(_subcategoriesMap[_selectedCategoryId] ?? [])
                                .map(
                                  (s) => DropdownMenuItem<int>(
                                    value: s['id'],
                                    child: Text(s['name']),
                                  ),
                                ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedSubcategoryId = val);
                            _applyFilter();
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // ================= RIGHT SIDE: Product List =================
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? const Center(child: Text('No products found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final p = _filteredProducts[index];
                            final displayNo = index + 1; // စဉ်နံပါတ်

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // ================= ၁။ Card အပြင်က စဉ်နံပါတ် =================
                                  SizedBox(
                                    width: 40, // နေရာသတ်မှတ်
                                    child: Text(
                                      '$displayNo.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),

                                  // ================= ၂။ Product Card =================
                                  Expanded(
                                    child: Card(
                                      margin: EdgeInsets.zero, // Margin ကို Padding မှာ ပြောင်းထားတယ်
                                      child: ListTile(
                                        leading: Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child:
                                              p.imageUrl != null &&
                                                  p.imageUrl!.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.network(
                                                    p.imageUrl!.startsWith(
                                                          'http',
                                                        )
                                                        ? p.imageUrl!
                                                        : '${ApiService.baseUrl}${p.imageUrl}',
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          __,
                                                          ___,
                                                        ) => const Icon(
                                                          Icons.broken_image,
                                                          color: Colors.grey,
                                                        ),
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.inventory_2,
                                                  color: Colors.blue,
                                                  size: 30,
                                                ),
                                        ),
                                        title: Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.orange,
                                              ),
                                              onPressed: () {
                                                _showCustomCardDialog(
                                                  ProductFormScreen(product: p),
                                                ).then((result) {
                                                  if (result == true)
                                                    _loadProducts();
                                                });
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () async {
                                                final confirm =
                                                    await showDialog<bool>(
                                                      context: context,
                                                      builder: (_) => AlertDialog(
                                                        title: const Text(
                                                          'Delete Product?',
                                                        ),
                                                        content: Text(
                                                          'Are you sure you want to delete ${p.name}?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                if (confirm == true) {
                                                  final success =
                                                      await ApiService()
                                                          .deleteProduct(p.id);
                                                  if (success && mounted) {
                                                    _loadProducts();
                                                  }
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
