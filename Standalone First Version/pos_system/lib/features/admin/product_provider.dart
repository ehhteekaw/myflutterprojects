import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../core/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// Category နဲ့ Total Sold ပါဝင်သော Model
class ProductWithCategory {
  final Product product;
  final Category? category;
  final Subcategory? subcategory;
  final int totalSold;

  ProductWithCategory({
    required this.product,
    this.category,
    this.subcategory,
    required this.totalSold,
  });
}

// 1. Stream all products
final productStreamProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllProducts();
});

// 2. Stream all categories
final categoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

// 3. Stream subcategories filtered by category ID
final subcategoriesByCatProvider = StreamProvider.autoDispose
    .family<List<Subcategory>, int>((ref, categoryId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.subcategories)
        ..where((s) => s.categoryId.equals(categoryId)))
      .watch();
});

// 4. Products with Category, Subcategory & Total Sold Stream Provider
final productsWithCategoryProvider =
    StreamProvider.autoDispose<List<ProductWithCategory>>((ref) {
  final db = ref.watch(databaseProvider);

  return db
      .customSelect(
        '''
    SELECT 
      p.id, p.name, p.sku, p.price, p.stock_quantity, p.image_url, p.subcategory_id,
      c.id as cat_id, c.name as cat_name,
      s.id as sub_id, s.name as sub_name,
      COALESCE(SUM(oi.quantity), 0) as total_sold
    FROM products p
    LEFT JOIN subcategories s ON p.subcategory_id = s.id
    LEFT JOIN categories c ON s.category_id = c.id
    LEFT JOIN order_items oi ON p.id = oi.product_id
    GROUP BY p.id
    ''',
        readsFrom: {
          db.products,
          db.subcategories,
          db.categories,
          db.orderItems
        }, // 👉 reads အစား readsFrom သုံးပါ
      )
      .watch()
      .map((rows) {
        return rows.map((row) {
          final product = Product(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
            sku: row.read<String>('sku'),
            price: row.read<double>('price'),
            stockQuantity: row.read<int>('stock_quantity'),
            imageUrl: row.read<String?>('image_url'),
            subcategoryId: row.read<int?>('subcategory_id'),
          );

          Category? category;
          if (row.read<int?>('cat_id') != null) {
            category = Category(
              id: row.read<int>('cat_id'),
              name: row.read<String>('cat_name'),
            );
          }

          Subcategory? subcategory;
          if (row.read<int?>('sub_id') != null) {
            subcategory = Subcategory(
              id: row.read<int>('sub_id'),
              categoryId: row.read<int>('cat_id'),
              name: row.read<String>('sub_name'),
            );
          }

          final totalSold = row.read<int>('total_sold');

          return ProductWithCategory(
            product: product,
            category: category,
            subcategory: subcategory,
            totalSold: totalSold,
          );
        }).toList();
      });
});
