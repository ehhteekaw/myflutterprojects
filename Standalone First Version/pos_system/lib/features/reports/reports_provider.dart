import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database.dart';
import '../admin/product_provider.dart';
import '../checkout/pos_provider.dart';

// Stream of all completed orders
final ordersStreamProvider = StreamProvider<List<Order>>((ref) {
  final db = ref.read(databaseProvider);
  return db.select(db.orders).watch();
});

// Computed provider for total revenue
final totalRevenueProvider = Provider.autoDispose<double>((ref) {
  final ordersAsync = ref.watch(ordersStreamProvider);
  return ordersAsync.maybeWhen(
    data: (orders) => orders.fold(0.0, (sum, order) => sum + order.totalPrice),
    orElse: () => 0.0,
  );
});

// Computed provider for total order count
final totalOrdersCountProvider = Provider.autoDispose<int>((ref) {
  final ordersAsync = ref.watch(ordersStreamProvider);
  return ordersAsync.maybeWhen(
    data: (orders) => orders.length,
    orElse: () => 0,
  );
});

class OrderItemWithProduct {
  final OrderItem orderItem;
  final Product product;

  OrderItemWithProduct({required this.orderItem, required this.product});
}

// Order ID ဖြင့် အဆိုပါ Order တွင်ပါသော Products များကို ဆွဲထုတ်ပေးသည့် Provider
final orderItemsWithProductProvider =
    FutureProvider.family<List<OrderItemWithProduct>, int>(
        (ref, orderId) async {
  final db = ref.watch(databaseProvider);

  final query = db.select(db.orderItems).join([
    innerJoin(db.products, db.products.id.equalsExp(db.orderItems.productId)),
  ])
    ..where(db.orderItems.orderId.equals(orderId));

  final rows = await query.get();

  return rows.map((row) {
    return OrderItemWithProduct(
      orderItem: row.readTable(db.orderItems),
      product: row.readTable(db.products),
    );
  }).toList();
});

// Model for Top Selling Products
class TopProductItem {
  final Product product;
  final int totalQuantitySold;
  final double totalRevenue;

  TopProductItem({
    required this.product,
    required this.totalQuantitySold,
    required this.totalRevenue,
  });
}

// Computed provider for top-selling products leaderboard
final topSellingProductsProvider =
    FutureProvider.autoDispose<List<TopProductItem>>((ref) async {
  final db = ref.watch(databaseProvider);

  // Fetch all order items and products from database
  final orderItems = await db.select(db.orderItems).get();
  final products = await db.select(db.products).get();

  final productMap = {for (var p in products) p.id: p};

  // Aggregate quantities and revenue per product ID
  final Map<int, int> qtyMap = {};
  final Map<int, double> revenueMap = {};

  for (var item in orderItems) {
    qtyMap[item.productId] = (qtyMap[item.productId] ?? 0) + item.quantity;
    revenueMap[item.productId] =
        (revenueMap[item.productId] ?? 0.0) + (item.quantity * item.unitPrice);
  }

  // Convert to list and sort by quantity sold descending
  List<TopProductItem> topProducts = [];
  qtyMap.forEach((productId, qty) {
    if (productMap.containsKey(productId)) {
      topProducts.add(TopProductItem(
        product: productMap[productId]!,
        totalQuantitySold: qty,
        totalRevenue: revenueMap[productId] ?? 0.0,
      ));
    }
  });

  topProducts
      .sort((a, b) => b.totalQuantitySold.compareTo(a.totalQuantitySold));
  return topProducts;
});

class OrderWithUser {
  final Order order;
  final User? user;

  OrderWithUser({required this.order, required this.user});
}

// Orders များကို Users ဇယားနှင့် Join လုပ်ပေးသော Provider
final ordersWithUserProvider =
    StreamProvider.autoDispose<List<OrderWithUser>>((ref) {
  final db = ref.watch(databaseProvider);

  final query = db.select(db.orders).join([
    leftOuterJoin(db.users, db.users.id.equalsExp(db.orders.userId)),
  ])
    ..orderBy([OrderingTerm.desc(db.orders.createdAt)]);

  return query.watch().map((rows) {
    return rows.map((row) {
      return OrderWithUser(
        order: row.readTable(db.orders),
        user: row.readTableOrNull(db.users),
      );
    }).toList();
  });
});
