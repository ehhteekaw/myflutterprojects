// lib/database.dart
import 'package:sqlite3/sqlite3.dart';
import 'schema.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  late Database _db;

  DatabaseHelper._internal();

  void initialize() {
    _db = sqlite3.open('bin/pos.db');
    _db.execute(createTablesSQL);

    final result = _db.select('SELECT COUNT(*) as count FROM shops');
    final count = result.first['count'] as int;

    if (count == 0) {
      _db.execute(insertDummyDataSQL);
      print('Database created and populated with dummy data.');
    } else {
      print('Database connected successfully.');
    }
  }

  // --- Login ---
  Map<String, dynamic>? loginUser(String username, String pin) {
    final ResultSet resultSet = _db.select(
        'SELECT id, shop_id, username, role FROM users WHERE username = ? AND pin_code = ? AND is_active = 1',
        [username, pin]
    );
    return resultSet.isNotEmpty ? resultSet.first : null;
  }

  // --- Shops ---
  List<Map<String, dynamic>> getAllShops() {
    final ResultSet resultSet = _db.select('SELECT id, shop_name FROM shops');
    return resultSet.map((row) => row).toList();
  }

  // 1. Add New Shop
  bool addShop(String shopName) {
    try {
      _db.execute('INSERT INTO shops (shop_name) VALUES (?)', [shopName]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 2. Update Shop
  bool updateShop(int id, String shopName) {
    try {
      _db.execute('UPDATE shops SET shop_name = ? WHERE id = ?', [shopName, id]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 3. Delete Shop (Optional: You might want to prevent this if they have products)
  bool deleteShop(int id) {
    try {
      // ပစ္စည်းတွေ ရှိသေးရင် ဖျက်လို့မရအောင် ကာကွယ်လို့ရပါတယ်၊ ဒါပေမယ့် အခုတော့ တိုက်ရိုက်ဖျက်လိုက်ပါမယ်
      _db.execute('DELETE FROM shops WHERE id = ?', [id]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Products ---
  // shopId က null ဖြစ်ရင် ဆိုင်အားလုံးရဲ့ Product တွေကို ဆွဲထုတ်မယ်
  List<Map<String, dynamic>> getProducts(int? shopId) {
    String query = 'SELECT * FROM products';
    List<dynamic> params = [];

    if (shopId != null) {
      query += ' WHERE shop_id = ?';
      params.add(shopId);
    }

    final ResultSet resultSet = _db.select(query, params);
    return resultSet.map((row) => row).toList();
  }

  // --- Customers ---
  Map<String, dynamic>? getCustomerByCard(String cardNumber) {
    final ResultSet resultSet = _db.select(
        'SELECT * FROM customers WHERE card_number = ?', [cardNumber]
    );
    return resultSet.isNotEmpty ? resultSet.first : null;
  }

  // 1. Get All Customers
  List<Map<String, dynamic>> getAllCustomers() {
    final ResultSet resultSet = _db.select('SELECT * FROM customers ORDER BY name ASC');
    return resultSet.map((row) => row).toList();
  }

  // 2. Add New Customer
  Map<String, dynamic>? addCustomer(String cardNumber, String name, String type) {
    try {
      _db.execute(
          'INSERT INTO customers (card_number, name, customer_type, balance) VALUES (?, ?, ?, 0.0)',
          [cardNumber, name, type]
      );
      // ထည့်ပြီးသား Customer ကို ပြန်ယူပြီး ပြန်ပေးမယ်
      return getCustomerByCard(cardNumber);
    } catch (e) {
      return null; // usually means card_number already exists
    }
  }

  // Update Customer
  // Update Customer (Now includes Card Number)
  bool updateCustomer(int id, String cardNumber, String name, String type) {
    try {
      _db.execute(
          'UPDATE customers SET card_number = ?, name = ?, customer_type = ? WHERE id = ?',
          [cardNumber, name, type, id]
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete Customer
  bool deleteCustomer(int id) {
    try {
      _db.execute('DELETE FROM customers WHERE id = ?', [id]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Create a new order and deduct customer balance
  // Create Order & Deduct Balance
  Map<String, dynamic>? createOrder(int shopId, String? cardNumber, List<Map<String, dynamic>> items, double totalAmount) {
    try {
      _db.execute('BEGIN TRANSACTION');

      // ၁။ ကတ်နံပါတ်ပေးထားရင် ပိုက်ဆံလုံလောက်မလုံလောက် စစ်ပြီး နုတ်မယ်
      if (cardNumber != null && cardNumber.isNotEmpty) {
        final customer = getCustomerByCard(cardNumber);
        if (customer == null) return {'error': 'Customer not found'};

        double currentBalance = (customer['balance'] as num).toDouble();
        if (currentBalance < totalAmount) {
          return {'error': 'Insufficient balance. Current: $currentBalance'};
        }

        _db.execute(
            'UPDATE customers SET balance = ? WHERE card_number = ?',
            [currentBalance - totalAmount, cardNumber]
        );
      }

      // ၂။ Orders Table ထဲ ထည့်မယ်
      _db.execute(
          "INSERT INTO orders (shop_id, student_card_id, total_amount, created_at) VALUES (?, ?, ?, datetime('now', 'localtime'))",
          [shopId, cardNumber, totalAmount]
      );
      final orderId = _db.lastInsertRowId;

      // ၃။ Order Items တွေ ထည့်မယ်
      for (var item in items) {
        _db.execute(
            'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (?, ?, ?, ?)',
            [orderId, item['product_id'], item['quantity'], item['price']]
        );
      }

      _db.execute('COMMIT');
      return {'success': true, 'order_id': orderId};
    } catch (e) {
      _db.execute('ROLLBACK');
      return {'error': e.toString()};
    }
  }

  // --- Reports ---
  // Order အားလုံးကို ဆိုင်အလိုက်၊ ရက်အလိုက် ဆွဲထုတ်မယ်
  List<Map<String, dynamic>> getOrders({int? shopId, String? fromDate, String? toDate}) {
    // Shop Name ပါ တွဲထုတ်ဖို့ Query ကို ပြင်ထားတယ်
    String query = '''
      SELECT o.id, o.shop_id, s.shop_name, o.student_card_id, o.total_amount, o.created_at, 
             c.name as customer_name
      FROM orders o
      LEFT JOIN customers c ON o.student_card_id = c.card_number
      LEFT JOIN shops s ON o.shop_id = s.id
      WHERE 1=1
    ''';
    List<dynamic> params = [];

    if (shopId != null) {
      query += ' AND o.shop_id = ?';
      params.add(shopId);
    }
    if (fromDate != null && fromDate.isNotEmpty) {
      query += ' AND DATE(o.created_at) >= ?';
      params.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      query += ' AND DATE(o.created_at) <= ?';
      params.add(toDate);
    }

    query += ' ORDER BY o.created_at DESC';

    final ResultSet resultSet = _db.select(query, params);
    return resultSet.map((row) => row).toList();
  }

  Map<String, dynamic> getSalesSummary({int? shopId, String? fromDate, String? toDate}) {
    String query = 'SELECT COUNT(id) as total_orders, SUM(total_amount) as total_sales FROM orders WHERE 1=1';
    List<dynamic> params = [];

    if (shopId != null) {
      query += ' AND shop_id = ?';
      params.add(shopId);
    }
    if (fromDate != null && fromDate.isNotEmpty) {
      query += ' AND DATE(created_at) >= ?';
      params.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      query += ' AND DATE(created_at) <= ?';
      params.add(toDate);
    }

    final ResultSet resultSet = _db.select(query, params);
    final row = resultSet.first;

    return {
      'total_orders': row['total_orders'] ?? 0,
      'total_sales': row['total_sales'] ?? 0.0,
    };
  }

  // Order တစ်ခုရဲ့ ပစ္စည်းစာရင်း (Order Detail အတွက်)
  List<Map<String, dynamic>> getOrderItems(int orderId) {
    final ResultSet resultSet = _db.select('''
      SELECT oi.*, p.name as product_name
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    ''', [orderId]);
    return resultSet.map((row) => row).toList();
  }

  // Update customer balance (Top up or Withdraw)
  bool updateBalance(String cardNumber, double amount, bool isTopUp) {
    final customer = getCustomerByCard(cardNumber);
    if (customer == null) return false;

    double currentBalance = (customer['balance'] as num).toDouble();
    double newBalance = isTopUp ? currentBalance + amount : currentBalance - amount;

    // Prevent balance from going below zero (optional, but recommended)
    if (newBalance < 0) return false;

    _db.execute(
        'UPDATE customers SET balance = ? WHERE card_number = ?',
        [newBalance, cardNumber]
    );
    return true;
  }


  // --- Categories ---
  List<Map<String, dynamic>> getAllCategories() {
    return _db.select('SELECT * FROM categories').map((e) => e).toList();
  }

  bool addCategory(String name) {
    try {
      _db.execute('INSERT INTO categories (name) VALUES (?)', [name]);
      return true;
    } catch (e) { return false; }
  }

  bool deleteCategory(int id) {
    try {
      _db.execute('DELETE FROM categories WHERE id = ?', [id]); // ON DELETE CASCADE ကြောင့် Sub တွေပါ ပျက်မယ်
      return true;
    } catch (e) { return false; }
  }

  // --- Subcategories ---
  List<Map<String, dynamic>> getSubcategoriesByCategory(int categoryId) {
    return _db.select('SELECT * FROM subcategories WHERE category_id = ?', [categoryId]).map((e) => e).toList();
  }

  bool addSubcategory(int categoryId, String name) {
    try {
      _db.execute('INSERT INTO subcategories (category_id, name) VALUES (?, ?)', [categoryId, name]);
      return true;
    } catch (e) { return false; }
  }

  // Delete Subcategory
  bool deleteSubcategory(int id) {
    try {
      _db.execute('DELETE FROM subcategories WHERE id = ?', [id]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get Product by ID (ပုံအဟောင်း Path ကို ရှာဖို့)
  Map<String, dynamic>? getProductById(int id) {
    final resultSet = _db.select('SELECT * FROM products WHERE id = ?', [id]);
    return resultSet.isNotEmpty ? resultSet.first : null;
  }

  // --- Products ---
  bool addProduct(String name, String sku, double price, int shopId, String? imageUrl, int? subcategoryId) {
    try {
      _db.execute(
          'INSERT INTO products (name, sku, price, shop_id, image_url, subcategory_id) VALUES (?, ?, ?, ?, ?, ?)',
          [name, sku, price, shopId, imageUrl, subcategoryId]
      );
      return true;
    } catch (e) { return false; }
  }

  bool deleteProduct(int id) {
    try {
      _db.execute('DELETE FROM products WHERE id = ?', [id]);
      return true;
    } catch (e) { return false; }
  }
  // Update Product (ပုံးအသစ် ရှိရင် အသစ်သုံးမယ်၊ မရှိရင် အဟောင်းအတိုင်းထားမယ်)
  bool updateProduct(int id, String name, String sku, double price, String? imageUrl, int? subcategoryId) {
    try {
      _db.execute(
          'UPDATE products SET name = ?, sku = ?, price = ?, image_url = ?, subcategory_id = ? WHERE id = ?',
          [name, sku, price, imageUrl, subcategoryId, id]
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Top Selling Products (အရောင်းရဆုံး ပစ္စည်းများ)
  List<Map<String, dynamic>> getTopSellingProducts({int? shopId, String? fromDate, String? toDate}) {
    String query = '''
      SELECT p.name,p.image_url, SUM(oi.quantity) as total_qty, SUM(oi.quantity * oi.price) as total_sales
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      JOIN products p ON oi.product_id = p.id
      WHERE 1=1
    ''';
    List<dynamic> params = [];

    if (shopId != null) {
      query += ' AND o.shop_id = ?';
      params.add(shopId);
    }
    if (fromDate != null && fromDate.isNotEmpty) {
      query += ' AND DATE(o.created_at) >= ?';
      params.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      query += ' AND DATE(o.created_at) <= ?';
      params.add(toDate);
    }

    query += ' GROUP BY p.id ORDER BY total_qty DESC LIMIT 10'; // Top 10 ကို ယူမယ်

    final ResultSet resultSet = _db.select(query, params);
    return resultSet.map((row) => row).toList();
  }

  // --- Users ---
  // Get All Users (SuperAdmin အတွက်)
  List<Map<String, dynamic>> getAllUsers() {
    final ResultSet resultSet = _db.select(
        'SELECT id, shop_id, username, role, is_active FROM users ORDER BY role ASC'
    );
    return resultSet.map((row) => row).toList();
  }

  // Get Users by Shop (ShopAdmin အတွက်)
  List<Map<String, dynamic>> getUsersByShop(int shopId) {
    final ResultSet resultSet = _db.select(
        'SELECT id, shop_id, username, role, is_active FROM users WHERE shop_id = ? ORDER BY role ASC',
        [shopId]
    );
    return resultSet.map((row) => row).toList();
  }

  // Add User
  bool addUser(int? shopId, String username, String pin, String role) {
    try {
      _db.execute(
          'INSERT INTO users (shop_id, username, pin_code, role) VALUES (?, ?, ?, ?)',
          [shopId, username, pin, role]
      );
      return true;
    } catch (e) { return false; }
  }

  // Update User
  bool updateUser(int id, String username, String role, int isActive) {
    try {
      _db.execute(
          'UPDATE users SET username = ?, role = ?, is_active = ? WHERE id = ?',
          [username, role, isActive, id]
      );
      return true;
    } catch (e) { return false; }
  }

  // Delete User
  bool deleteUser(int id) {
    try {
      _db.execute('DELETE FROM users WHERE id = ?', [id]);
      return true;
    } catch (e) { return false; }
  }


}

final dbHelper = DatabaseHelper();