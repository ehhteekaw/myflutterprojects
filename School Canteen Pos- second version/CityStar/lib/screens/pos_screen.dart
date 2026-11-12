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
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  List<dynamic> _categories = [];
  Map<int, List<dynamic>> _subcategoriesMap = {};

  int? _selectedCategoryId;
  int? _selectedSubcategoryId;

  bool _isLoading = true;
  int? _expandedCategoryId;

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
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt('shop_id') ?? 1;

    final products = await ApiService().getProducts(shopId);
    final categories = await ApiService().getCategories();

    setState(() {
      _allProducts = products;
      _filteredProducts = products;
      _categories = categories;
      _isLoading = false;
    });
  }

  Future<void> _onCategoryTap(int? categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedSubcategoryId = null;

      if (_expandedCategoryId == categoryId) {
        _expandedCategoryId = null;
      } else {
        _expandedCategoryId = categoryId;
      }
    });

    if (categoryId != null) {
      if (!_subcategoriesMap.containsKey(categoryId)) {
        final subs = await ApiService().getSubcategories(categoryId);
        setState(() {
          _subcategoriesMap[categoryId] = subs;
        });
      }
      _applyFilter();
    } else {
      setState(() => _filteredProducts = _allProducts);
    }
  }

  void _onSubcategoryTap(int? subcategoryId) {
    setState(() => _selectedSubcategoryId = subcategoryId);
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {
      if (_selectedCategoryId == null && _selectedSubcategoryId == null) {
        _filteredProducts = _allProducts;
      } else if (_selectedSubcategoryId != null) {
        _filteredProducts = _allProducts
            .where((p) => p.subcategoryId == _selectedSubcategoryId)
            .toList();
      } else if (_selectedCategoryId != null) {
        final subs = _subcategoriesMap[_selectedCategoryId] ?? [];
        final subIds = subs.map((s) => s['id']).toList();
        _filteredProducts = _allProducts
            .where((p) => subIds.contains(p.subcategoryId))
            .toList();
      }
    });
  }

  Future<void> _showPaymentDialog(CartProvider cart) async {
    final cardCtrl = TextEditingController();
    Customer? foundCustomer;
    bool isSearching = false;
    String? errorMsg;
    final FocusNode cardFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      cardFocusNode.requestFocus();
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Payment - Scan Card'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Please scan or enter the card number to proceed.'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cardCtrl,
                        focusNode: cardFocusNode,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Card Number',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) async {
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
                              'Insufficient balance!',
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

    if (mounted) Navigator.pop(context);

    if (result.containsKey('success')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment Successful! New Balance: ${_currencyFormat.format(customer.balance - cart.totalAmount)}',
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

  // ==========================================
  // Extract Widget: Category Item
  // ==========================================
  Widget _buildCategoryItem(dynamic cat, bool isSelected, bool isExpanded) {
    final catId = cat['id'] as int;
    final subCats = _subcategoriesMap[catId] ?? [];

    return Column(
      children: [
        Material(
          // <--- Material နဲ့ ခြုံလိုက်တယ်
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          child: ListTile(
            title: Text(
              cat['name'],
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue[800] : Colors.black87,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey,
            ),
            onTap: () => _onCategoryTap(catId),
          ),
        ),

        if (isExpanded) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // All Subcategories ရွေးချယ်မှု
                Material(
                  color: _selectedSubcategoryId == null
                      ? Colors.blue.shade50
                      : Colors.transparent,
                  child: ListTile(
                    dense: true,
                    title: Text(
                      'All ${cat['name']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedSubcategoryId == null
                            ? Colors.blue[800]
                            : Colors.grey[700],
                      ),
                    ),
                    onTap: () => _onSubcategoryTap(null),
                  ),
                ),
                // Subcategory တွေ
                ...subCats.map((sub) {
                  final isSubSelected = _selectedSubcategoryId == sub['id'];
                  return Material(
                    color: isSubSelected
                        ? Colors.blue.shade50
                        : Colors.transparent,
                    child: ListTile(
                      dense: true,
                      title: Text(
                        sub['name'],
                        style: TextStyle(
                          fontSize: 14,
                          color: isSubSelected
                              ? Colors.blue[800]
                              : Colors.grey[700],
                          fontWeight: isSubSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSubSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.blue,
                            )
                          : null,
                      onTap: () => _onSubcategoryTap(sub['id']),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // ================= LEFT SIDE: Accordion Menu =================
                Container(
                  width: 220,
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey[100],
                        child: const Text(
                          'Menu',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _categories.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              // "All Categories" ခလုတ်
                              final isSelected = _selectedCategoryId == null;
                              return Material(
                                color: isSelected
                                    ? Colors.blue.shade50
                                    : Colors.transparent,
                                child: ListTile(
                                  title: Text(
                                    'All Categories',
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.blue[800]
                                          : Colors.black87,
                                    ),
                                  ),
                                  onTap: () => _onCategoryTap(null),
                                ),
                              );
                            }

                            // တခြား Category တွေ
                            final cat = _categories[index - 1];
                            final catId = cat['id'] as int;
                            final isSelected = _selectedCategoryId == catId;
                            final isExpanded = _expandedCategoryId == catId;

                            return _buildCategoryItem(
                              cat,
                              isSelected,
                              isExpanded,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ================= MIDDLE: Products Grid =================
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.grey[50],
                    child: _filteredProducts.isEmpty
                        ? const Center(child: Text('No products found.'))
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  childAspectRatio: 0.8,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (c, i) {
                              final p = _filteredProducts[i];
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () =>
                                      context.read<CartProvider>().addToCart(p),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                          child:
                                              p.imageUrl != null &&
                                                  p.imageUrl!.isNotEmpty
                                              ? Image.network(
                                                  p.imageUrl!.startsWith('http')
                                                      ? p.imageUrl!
                                                      : '${ApiService.baseUrl}${p.imageUrl}',
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Container(
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
                                        padding: const EdgeInsets.all(10.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _currencyFormat.format(p.price),
                                              style: TextStyle(
                                                color: Colors.green[700],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
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
                          ),
                  ),
                ),

                // ================= RIGHT SIDE: Cart =================
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shopping_cart, color: Colors.blue),
                            SizedBox(width: 10),
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
                      Expanded(
                        child: Consumer<CartProvider>(
                          builder: (context, cart, _) {
                            if (cart.items.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_basket_outlined,
                                      size: 60,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Cart is empty',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: cart.items.length,
                              itemBuilder: (context, index) {
                                final item = cart.items.values.toList()[index];
                                final p = item['product'] as Product;
                                final qty = item['quantity'] as int;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
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
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              _currencyFormat.format(p.price),
                                              style: TextStyle(
                                                color: Colors.grey[600],
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
                                              size: 20,
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
                                              size: 20,
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
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Consumer<CartProvider>(
                          builder: (context, cart, _) => Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontSize: 18,
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
                              const SizedBox(height: 16),
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
              ],
            ),
    );
  }
}
