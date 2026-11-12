import 'dart:convert';
import 'dart:io'; // File အတွက်

import 'package:http_parser/http_parser.dart'; // Multipart အတွက်
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/customer.dart';

class ApiService {
  // Default IP (ဘာမှ မထည့်ရသေးရင် သုံးဖို့)
  static String _baseUrl = 'http://localhost:9090';

  // App စတင်တဲ့အခါ သိမ်းထားတဲ့ IP ကို ပြန်ယူဖို့
  static Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip');
    if (savedIp != null && savedIp.isNotEmpty) {
      // IP ထည့်ထားရင် http:// ပါမပါ စစ်ပြီး သိမ်းမယ်
      _baseUrl = savedIp.startsWith('http') ? savedIp : 'http://$savedIp';
    }
  }

  // baseUrl ကို ယူတဲ့အခါ အဆုံးမှာ / ပါနေရင် ဖျက်ပြီး ပြန်ပေးမယ်
  static String get baseUrl {
    if (_baseUrl.endsWith('/')) {
      return _baseUrl.substring(0, _baseUrl.length - 1);
    }
    return _baseUrl;
  }

  // Setup လုပ်စဉ် IP အသစ်ကို သိမ်းဖို့
  static Future<void> saveBaseUrl(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = ip.startsWith('http') ? ip : 'http://$ip';
    await prefs.setString('server_ip', _baseUrl);
  }

  // Shop ---- အောက်ကဟာတွေက မူလအတိုင်း ထားပါ ----

  Future<List<dynamic>> getShops() async {
    final res = await http.get(Uri.parse('$baseUrl/shops'));
    return json.decode(res.body);
  }

  Future<bool> addShop(String shopName) async {
    final res = await http.post(
      Uri.parse('$baseUrl/shops'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'shop_name': shopName}),
    );
    return res.statusCode == 200;
  }

  Future<bool> updateShop(int id, String shopName) async {
    final res = await http.put(
      Uri.parse('$baseUrl/shops/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'shop_name': shopName}),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteShop(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/shops/$id'));
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> login(String username, String pin) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'pin_code': pin}),
    );
    if (res.statusCode == 200) return json.decode(res.body);
    return null;
  }

  Future<List<Product>> getProducts(int? shopId) async {
    // shopId မရှိရင် 'all' လို့ ပို့မယ်
    final url = shopId == null
        ? '$baseUrl/products/all'
        : '$baseUrl/products/$shopId';
    final res = await http.get(Uri.parse(url));
    List data = json.decode(res.body);
    return data.map((e) => Product.fromJson(e)).toList();
  }

  Future<Customer?> getCustomer(String cardNumber) async {
    final res = await http.get(Uri.parse('$baseUrl/customers/$cardNumber'));
    if (res.statusCode == 200) return Customer.fromJson(json.decode(res.body));
    return null;
  }

  Future<Customer?> updateBalance(
    String cardNumber,
    double amount,
    bool isTopUp,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customers/topup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'card_number': cardNumber,
        'amount': amount,
        'is_topup': isTopUp,
      }),
    );
    if (res.statusCode == 200) {
      return Customer.fromJson(json.decode(res.body));
    }
    return null;
  }

  Future<Map<String, dynamic>> checkout({
    required int shopId,
    String? cardNumber,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/checkout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'shop_id': shopId,
        'card_number': cardNumber,
        'items': items,
        'total_amount': totalAmount,
      }),
    );
    return json.decode(res.body);
  }

  Future<List<dynamic>> getAllCustomers() async {
    final res = await http.get(Uri.parse('$baseUrl/customers'));
    return json.decode(res.body);
  }

  Future<Map<String, dynamic>?> addCustomer(
    String cardNumber,
    String name,
    String type,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'card_number': cardNumber,
        'name': name,
        'customer_type': type,
      }),
    );
    if (res.statusCode == 200) {
      return json.decode(res.body); // Customer အသစ်ရဲ့ Data ကို ပြန်ပေးမယ်
    }
    return null;
  }

  Future<bool> updateCustomer(
    int id,
    String cardNumber,
    String name,
    String type,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl/customers/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'card_number': cardNumber,
        'name': name,
        'customer_type': type,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteCustomer(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/customers/$id'));
    return res.statusCode == 200;
  }

  // --- Categories ---
  Future<List<dynamic>> getCategories() async {
    final res = await http.get(Uri.parse('$baseUrl/categories'));
    return json.decode(res.body);
  }

  Future<bool> addCategory(String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteCategory(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/categories/$id'));
    return res.statusCode == 200;
  }

  // --- Subcategories ---
  Future<List<dynamic>> getSubcategories(int categoryId) async {
    final res = await http.get(Uri.parse('$baseUrl/subcategories/$categoryId'));
    return json.decode(res.body);
  }

  Future<bool> addSubcategory(int categoryId, String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/subcategories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'category_id': categoryId, 'name': name}),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteSubcategory(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/subcategories/$id'));
    return res.statusCode == 200;
  }

  // --- Image Upload ---
  Future<String?> uploadImage(File imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'), // Image အမျိုးအစား
      ),
    );

    var response = await request.send();
    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      return json.decode(responseData)['image_url'];
    }
    return null;
  }

  // --- Products ---
  Future<bool> addProduct(
    String name,
    String sku,
    double price,
    int shopId,
    String? imageUrl,
    int? subcategoryId,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/products'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'sku': sku,
        'price': price,
        'shop_id': shopId,
        'image_url': imageUrl,
        'subcategory_id': subcategoryId,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteProduct(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/products/$id'));
    return res.statusCode == 200;
  }

  Future<bool> updateProduct(
    int id,
    String name,
    String sku,
    double price,
    String? imageUrl,
    int? subcategoryId,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl/products/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'sku': sku,
        'price': price,
        'image_url': imageUrl, // Image အသစ်ရှိရင် Path အသစ်၊ မရှိရင် အဟောင်း
        'subcategory_id': subcategoryId,
      }),
    );
    return res.statusCode == 200;
  }

  // --- Users ---
  Future<List<dynamic>> getUsers(int? shopId) async {
    final url = shopId == null
        ? '$baseUrl/users/all'
        : '$baseUrl/users/$shopId';
    final res = await http.get(Uri.parse(url));
    return json.decode(res.body);
  }

  Future<bool> addUser(
    int? shopId,
    String username,
    String pin,
    String role,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'shop_id': shopId,
        'username': username,
        'pin_code': pin,
        'role': role,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> updateUser(
    int id,
    String username,
    String role,
    int isActive,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl/users/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'role': role,
        'is_active': isActive,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteUser(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/users/$id'));
    return res.statusCode == 200;
  }

  // --- Reports ---
  Future<List<dynamic>> getOrders({
    int? shopId,
    String? fromDate,
    String? toDate,
  }) async {
    String url = '$baseUrl/reports/orders?';
    if (shopId != null) url += 'shop_id=$shopId&';
    if (fromDate != null) url += 'from_date=$fromDate&';
    if (toDate != null) url += 'to_date=$toDate';

    final res = await http.get(Uri.parse(url));
    return json.decode(res.body);
  }

  Future<Map<String, dynamic>> getSalesSummary({
    int? shopId,
    String? fromDate,
    String? toDate,
  }) async {
    String url = '$baseUrl/reports/summary?';
    if (shopId != null) url += 'shop_id=$shopId&';
    if (fromDate != null) url += 'from_date=$fromDate&';
    if (toDate != null) url += 'to_date=$toDate';

    final res = await http.get(Uri.parse(url));
    return json.decode(res.body);
  }

  Future<List<dynamic>> getOrderItems(int orderId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/reports/order-items/$orderId'),
    );
    return json.decode(res.body);
  }

  Future<List<dynamic>> getTopSellingProducts({
    int? shopId,
    String? fromDate,
    String? toDate,
  }) async {
    String url = '$baseUrl/reports/top-products?';
    if (shopId != null) url += 'shop_id=$shopId&';
    if (fromDate != null) url += 'from_date=$fromDate&';
    if (toDate != null) url += 'to_date=$toDate';

    final res = await http.get(Uri.parse(url));
    return json.decode(res.body);
  }
}
