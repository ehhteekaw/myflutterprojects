import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database.dart';
import '../admin/product_provider.dart';

// 1. Cart Item Model
class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}

// 2. Cart State Management
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addProduct(Product product) {
    final existingIndex =
        state.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex)
            CartItem(product: state[i].product, quantity: state[i].quantity + 1)
          else
            state[i]
      ];
    } else {
      state = [...state, CartItem(product: product)];
    }
  }

  void removeProduct(Product product) {
    state = state.where((item) => item.product.id != product.id).toList();
  }

  void updateQuantity(Product product, int delta) {
    state = state
        .map((item) {
          if (item.product.id == product.id) {
            final newQty = item.quantity + delta;
            return newQty > 0
                ? CartItem(product: item.product, quantity: newQty)
                : null;
          }
          return item;
        })
        .whereType<CartItem>()
        .toList();
  }

  void clearCart() {
    state = [];
  }

  double get subtotal => state.fold(0.0, (sum, item) => sum + item.total);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

// 3. Provider for filtering products in POS screen
final productSearchQueryProvider = StateProvider<String>((ref) => '');

// 4. Filtered Products Provider (uses productStreamProvider from product_provider.dart)
final filteredProductsProvider = Provider.autoDispose<List<Product>>((ref) {
  final productsAsync =
      ref.watch(productStreamProvider); // product_provider.dart မှ လာပါသည်
  final searchQuery =
      ref.watch(productSearchQueryProvider).toLowerCase().trim();

  return productsAsync.maybeWhen(
    data: (products) {
      if (searchQuery.isEmpty) return products;
      return products.where((p) {
        final matchesName = p.name.toLowerCase().contains(searchQuery);
        final matchesSku = p.sku.toLowerCase().contains(searchQuery);
        return matchesName || matchesSku;
      }).toList();
    },
    orElse: () => [],
  );
});
