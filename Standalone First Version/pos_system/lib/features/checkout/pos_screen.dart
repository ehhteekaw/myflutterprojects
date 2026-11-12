import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database.dart';
import '../admin/product_provider.dart';
import '../auth/auth_provider.dart';
import './pos_provider.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  int? _selectedCategoryId; // Selected Main Category Filter
  int? _selectedSubcategoryId; // Selected Subcategory Filter

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Colors.blue;
    const backgroundGrey = Color(0xFFF5F6F8);

    // Join Provider ကို အသုံးပြု၍ Product များ၊ Category နှင့် Subcategory များကို တစ်ခါတည်း ယူခြင်း
    final productsWithCatAsync = ref.watch(productsWithCategoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    final searchQuery = ref.watch(productSearchQueryProvider);
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        title: const Text('School Canteen POS - Terminal 1'),
        actions: [
          // User badge displaying who is logged in
          Consumer(
            builder: (context, ref, child) {
              final user = ref.watch(authProvider).currentUser;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Chip(
                    avatar: const Icon(Icons.person, size: 16),
                    label:
                        Text('${user?.username ?? ""} (${user?.role ?? ""})'),
                  ),
                ),
              );
            },
          ),

          Consumer(
            builder: (context, ref, child) {
              final user = ref.watch(authProvider).currentUser;
              if (user?.role == 'Admin') {
                return IconButton(
                  style: IconButton.styleFrom(
                    enabledMouseCursor: SystemMouseCursors.click,
                    disabledMouseCursor: SystemMouseCursors.forbidden,
                  ),
                  icon: const Icon(Icons.dashboard_outlined),
                  tooltip: 'Admin Dashboard',
                  onPressed: () => Navigator.pop(context),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Logout Button
          IconButton(
            style: IconButton.styleFrom(
              enabledMouseCursor: SystemMouseCursors.click,
              disabledMouseCursor: SystemMouseCursors.forbidden,
            ),
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Logout',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text(
                      'Are you sure you want to log out of the terminal?'),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        enabledMouseCursor: SystemMouseCursors.click,
                        disabledMouseCursor: SystemMouseCursors.forbidden,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        enabledMouseCursor: SystemMouseCursors.click,
                        disabledMouseCursor: SystemMouseCursors.forbidden,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(authProvider.notifier).logout();
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // ================= LEFT SIDE: CATALOG & FILTERS =================
          Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Search Bar
                  TextField(
                    onChanged: (value) {
                      ref.read(productSearchQueryProvider.notifier).state =
                          value;
                    },
                    decoration: InputDecoration(
                      hintText: 'Search products or scan barcode...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                ref
                                    .read(productSearchQueryProvider.notifier)
                                    .state = '';
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Main Category Filter Chips Bar
                  categoriesAsync.when(
                    data: (categories) {
                      if (categories.isEmpty) return const SizedBox.shrink();
                      return SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            FilterChip(
                              mouseCursor: SystemMouseCursors.click,
                              label: const Text('All Categories'),
                              selected: _selectedCategoryId == null,
                              onSelected: (_) {
                                setState(() {
                                  _selectedCategoryId = null;
                                  _selectedSubcategoryId =
                                      null; // Reset subcategory
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            ...categories.map((cat) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  mouseCursor: SystemMouseCursors.click,
                                  label: Text(cat.name),
                                  selected: _selectedCategoryId == cat.id,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedCategoryId =
                                          selected ? cat.id : null;
                                      _selectedSubcategoryId =
                                          null; // Reset subcategory on category change
                                    });
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // 3. Subcategory Filter Chips Bar (Shown only if a Category is selected)
                  if (_selectedCategoryId != null)
                    Consumer(
                      builder: (context, ref, child) {
                        final subcategoriesAsync = ref.watch(
                            subcategoriesByCatProvider(_selectedCategoryId!));

                        return subcategoriesAsync.when(
                          data: (subcategories) {
                            if (subcategories.isEmpty)
                              return const SizedBox.shrink();
                            return Container(
                              height: 40,
                              margin: const EdgeInsets.only(top: 8),
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  FilterChip(
                                    mouseCursor: SystemMouseCursors.click,
                                    backgroundColor: Colors.grey.shade200,
                                    label: const Text('All Subcategories'),
                                    selected: _selectedSubcategoryId == null,
                                    onSelected: (_) {
                                      setState(
                                          () => _selectedSubcategoryId = null);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ...subcategories.map((sub) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: FilterChip(
                                        mouseCursor: SystemMouseCursors.click,
                                        backgroundColor: Colors.grey.shade200,
                                        label: Text(sub.name),
                                        selected:
                                            _selectedSubcategoryId == sub.id,
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedSubcategoryId =
                                                selected ? sub.id : null;
                                          });
                                        },
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),

                  const SizedBox(height: 12),

                  // 4. Product Grid Stream Builder with Filtering
                  Expanded(
                    child: productsWithCatAsync.when(
                      data: (items) {
                        final query = searchQuery.toLowerCase().trim();

                        // Filter items based on Category, Subcategory, and Search Query
                        final filteredItems = items.where((item) {
                          final product = item.product;

                          // Search match condition
                          final matchesSearch = query.isEmpty ||
                              product.name.toLowerCase().contains(query) ||
                              product.sku.toLowerCase().contains(query);

                          // Category match condition
                          final matchesCategory = _selectedCategoryId == null ||
                              item.category?.id == _selectedCategoryId;

                          // Subcategory match condition
                          final matchesSubcategory = _selectedSubcategoryId ==
                                  null ||
                              item.subcategory?.id == _selectedSubcategoryId;

                          return matchesSearch &&
                              matchesCategory &&
                              matchesSubcategory;
                        }).toList();

                        if (filteredItems.isEmpty) {
                          const secondaryTextColor = Colors.grey;
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.fastfood_outlined,
                                    size: 64, color: secondaryTextColor),
                                const SizedBox(height: 12),
                                Text(
                                    query.isNotEmpty
                                        ? 'No products match "$searchQuery"'
                                        : 'No products found in this category.',
                                    style: const TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 16)),
                              ],
                            ),
                          );
                        }

                        return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.82,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final product = item.product;

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              child: InkWell(
                                mouseCursor: SystemMouseCursors.precise,
                                onTap: () => cartNotifier.addProduct(product),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: product.imageUrl != null &&
                                                  product.imageUrl!.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.file(
                                                    File(product.imageUrl!),
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        const Center(
                                                      child: Icon(
                                                          Icons.fastfood,
                                                          size: 40,
                                                          color: Colors.grey),
                                                    ),
                                                  ),
                                                )
                                              : const Center(
                                                  child: Icon(Icons.fastfood,
                                                      size: 40,
                                                      color: Colors.grey),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${product.price.toStringAsFixed(0)} MMK',
                                        style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) =>
                          Center(child: Text('Error loading database: $err')),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ================= RIGHT SIDE: CURRENT CART & CHECKOUT =================
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Cart Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Order',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          style: IconButton.styleFrom(
                            enabledMouseCursor: SystemMouseCursors.click,
                            disabledMouseCursor: SystemMouseCursors.forbidden,
                          ),
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => cartNotifier.clearCart(),
                        ),
                      ],
                    ),
                  ),

                  // Cart Items List
                  Expanded(
                    child: cartItems.isEmpty
                        ? const Center(
                            child: Text('Cart is empty',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: cartItems.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = cartItems[index];
                              return ListTile(
                                title: Text(item.product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                subtitle: Text(
                                    '${item.quantity} x ${item.product.price.toStringAsFixed(0)} MMK'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      style: IconButton.styleFrom(
                                        enabledMouseCursor:
                                            SystemMouseCursors.click,
                                        disabledMouseCursor:
                                            SystemMouseCursors.forbidden,
                                      ),
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 20),
                                      onPressed: () => cartNotifier
                                          .updateQuantity(item.product, -1),
                                    ),
                                    Text('${item.quantity}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    IconButton(
                                      style: IconButton.styleFrom(
                                        enabledMouseCursor:
                                            SystemMouseCursors.click,
                                        disabledMouseCursor:
                                            SystemMouseCursors.forbidden,
                                      ),
                                      icon: const Icon(Icons.add_circle_outline,
                                          size: 20),
                                      onPressed: () => cartNotifier
                                          .updateQuantity(item.product, 1),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Checkout Summary & Action Buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border:
                          Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal',
                                style: TextStyle(color: Colors.grey)),
                            Text(
                                '${cartNotifier.subtotal.toStringAsFixed(0)} MMK',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Tax (0%)',
                                style: TextStyle(color: Colors.grey)),
                            Text('0 MMK',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(
                              '${cartNotifier.subtotal.toStringAsFixed(0)} MMK',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: cartItems.isEmpty
                                ? null
                                : () => _showCheckoutDialog(
                                    context, ref, cartNotifier.subtotal),
                            style: ElevatedButton.styleFrom(
                              enabledMouseCursor: SystemMouseCursors.click,
                              disabledMouseCursor: SystemMouseCursors.forbidden,
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              'Charge ${cartNotifier.subtotal.toStringAsFixed(0)} MMK',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
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

  // ================= CHECKOUT DIALOG =================

  void _showCheckoutDialog(
      BuildContext context, WidgetRef ref, double totalAmount) {
    final cardIdController = TextEditingController();
    Student? selectedStudent;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Complete Payment'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Due: ${totalAmount.toStringAsFixed(0)} MMK',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _processOrder(
                                  ref, totalAmount, 'Cash', null);
                              if (context.mounted) Navigator.pop(context);
                            },
                            icon: const Icon(Icons.money),
                            label: const Text('Cash'),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text('Or Pay with Student ID Card:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cardIdController,
                            decoration: const InputDecoration(
                              hintText: 'Enter/Scan Card ID (e.g. STU-1001)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final db = ref.read(databaseProvider);
                            final student = await db.getStudentByCardId(
                                cardIdController.text.trim());
                            setState(() {
                              selectedStudent = student;
                            });
                          },
                          child: const Text('Verify'),
                        ),
                      ],
                    ),
                    if (selectedStudent != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Name: ${selectedStudent!.name}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                                'Current Balance: ${selectedStudent!.balance.toStringAsFixed(0)} MMK'),
                            if (selectedStudent!.balance < totalAmount)
                              const Text('⚠️ Insufficient Balance!',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                selectedStudent!.balance >= totalAmount
                                    ? Colors.green
                                    : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: selectedStudent!.balance >= totalAmount
                              ? () async {
                                  await _processOrder(ref, totalAmount,
                                      'Student ID Card', selectedStudent);
                                  if (context.mounted) Navigator.pop(context);
                                }
                              : null,
                          child: const Text('Pay with Card'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _processOrder(WidgetRef ref, double totalAmount,
      String paymentMethod, Student? student) async {
    final db = ref.read(databaseProvider);
    final cartItems = ref.read(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final currentUser = ref.read(authProvider).currentUser;

    try {
      await db.transaction(() async {
        // 1. Insert Order
        final orderId = await db.into(db.orders).insert(
              OrdersCompanion.insert(
                orderNumber: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
                totalPrice: totalAmount,
                paymentMethod: paymentMethod,
                status: 'Completed',
                userId: Value(currentUser?.id),
                createdAt: DateTime.now(),
              ),
            );

        // 2. Insert Items & Reduce Product Stock
        for (final item in cartItems) {
          await db.into(db.orderItems).insert(
                OrderItemsCompanion.insert(
                  orderId: orderId,
                  productId: item.product.id,
                  quantity: item.quantity,
                  unitPrice: item.product.price,
                ),
              );

          final newStock =
              (item.product.stockQuantity - item.quantity).clamp(0, 999999);
          await (db.update(db.products)
                ..where((p) => p.id.equals(item.product.id)))
              .write(ProductsCompanion(stockQuantity: Value(newStock)));
        }

        // 3. ID Card ဖြင့် ငွေချေပါက Student Balance ထဲမှ ကျသင့်ငွေကို နှုတ်ယူခြင်း
        if (paymentMethod == 'Student ID Card' && student != null) {
          final newBalance = student.balance - totalAmount;
          await (db.update(db.students)..where((s) => s.id.equals(student.id)))
              .write(StudentsCompanion(balance: Value(newBalance)));
        }
      });

      cartNotifier.clearCart();
    } catch (e) {
      debugPrint('Order processing error: $e');
    }
  }
}
