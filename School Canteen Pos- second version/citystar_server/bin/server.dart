// bin/server.dart
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:citystar_server/database.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:mime/mime.dart';

void main() async {
  dbHelper.initialize();
  final router = Router();

  // ==========================================
  // Project ရဲ့ အပေါ်ဆုံးက uploads Folder ကို သုံးမယ်
  // ==========================================
  final uploadDir = Directory('uploads');
  if (!uploadDir.existsSync()) {
    uploadDir.createSync(recursive: true);
  }

  // Absolute Path ကို ယူမယ်
  final uploadPath = uploadDir.absolute.path;
  print('Images are served from: $uploadPath');

  // Routes တွေကို ချိတ်မယ်
  _setupRoutes(router, dbHelper, uploadPath);

  // ==========================================
  // Static Handler ကို သေချာချိတ်ဆက်ခြင်း
  // ==========================================
  final staticHandler = createStaticHandler(
    uploadPath,
    defaultDocument: 'index.html',
  );

  // /uploads ဆိုတဲ့ အပိုင်းကို ဖြုတ်ပြီး ရှာဖို့ Handler
  final uploadsHandler = (Request request) {
    final path = request.url.path;

    // URL က 'uploads/' နဲ့ စရင်
    if (path.startsWith('uploads/')) {
      // 'uploads/' ကို ဖြုတ်ပြီး ကျန်တဲ့ပုံနာမည်ကို ယူမယ်
      final newPath = path.substring('uploads/'.length);

      // Request အသစ်ကို ဖန်တီးမယ် (ဒီနေရာမှာ request.change မသုံးဘဲ Request အသစ် ဆောက်မယ်)
      final newRequest = Request(
        request.method,
        request.requestedUri.replace(path: '/$newPath'),
        headers: request.headers,
        body: request.read(),
        context: request.context,
      );
      return staticHandler(newRequest);
    }
    return Response.notFound('Not found');
  };

  final cascadeHandler = Cascade()
      .add(uploadsHandler)
      .add(router.call)
      .handler;

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(cascadeHandler);
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 9090);
  print('Server running on http://${server.address.host}:${server.port}');
}

// ==========================================
// Routes အားလုံးကို ဒီ Function ထဲမှာ ထည့်မယ်
// ==========================================
void _setupRoutes(Router router, DatabaseHelper dbHelper, String uploadPath) {
  // 1. Get Shops
  router.get('/shops', (Request req) {
    return Response.ok(
        jsonEncode(dbHelper.getAllShops()),
        headers: {'Content-Type': 'application/json'}
    );
  });

  router.post('/shops', (Request req) async {
    final payload = jsonDecode(await req.readAsString());
    final success = dbHelper.addShop(payload['shop_name']);
    if (success) return Response.ok(jsonEncode({'success': true}));
    return Response.badRequest(body: jsonEncode({'error': 'Failed to add shop'}));
  });

  router.put('/shops/<id>', (Request req, String id) async {
    final payload = jsonDecode(await req.readAsString());
    final success = dbHelper.updateShop(int.parse(id), payload['shop_name']);
    if (success) return Response.ok(jsonEncode({'success': true}));
    return Response.badRequest(body: jsonEncode({'error': 'Failed to update shop'}));
  });

  router.delete('/shops/<id>', (Request req, String id) {
    final success = dbHelper.deleteShop(int.parse(id));
    if (success) return Response.ok(jsonEncode({'success': true}));
    return Response.badRequest(body: jsonEncode({'error': 'Failed to delete shop'}));
  });

  // 2. Login
  router.post('/login', (Request req) async {
    final payload = jsonDecode(await req.readAsString());
    final user = dbHelper.loginUser(payload['username'], payload['pin_code']);
    if (user != null) {
      return Response.ok(jsonEncode(user), headers: {'Content-Type': 'application/json'});
    }
    return Response.forbidden(jsonEncode({'error': 'Invalid credentials'}));
  });

  // 3. Get Products by Shop
  router.get('/products/<shopId>', (Request req, String shopId) {
    // 'all' ဆိုရင် null ပေးပြီး အကုန်ဆွဲမယ်
    final id = shopId == 'all' ? null : int.tryParse(shopId);
    final products = dbHelper.getProducts(id);
    return Response.ok(jsonEncode(products), headers: {'Content-Type': 'application/json'});
  });

  // 4. Top Up or Withdraw Balance
  router.post('/customers/topup', (Request req) async {
    final payload = jsonDecode(await req.readAsString());
    final cardNumber = payload['card_number'];
    final amount = (payload['amount'] as num).toDouble();
    final isTopUp = payload['is_topup'] as bool;

    final success = dbHelper.updateBalance(cardNumber, amount, isTopUp);

    if (success) {
      final updatedCustomer = dbHelper.getCustomerByCard(cardNumber);
      return Response.ok(jsonEncode(updatedCustomer), headers: {'Content-Type': 'application/json'});
    } else {
      return Response.badRequest(body: jsonEncode({'error': 'Transaction failed. Check balance or card number.'}));
    }
  });

  // 5. Get Customer by Card
  router.get('/customers/<cardNumber>', (Request req, String cardNumber) {
    final customer = dbHelper.getCustomerByCard(cardNumber);
    if (customer != null) {
      return Response.ok(jsonEncode(customer), headers: {'Content-Type': 'application/json'});
    }
    return Response.notFound('Not found');
  });

  // Route: Checkout
  router.post('/checkout', (Request req) async {
    final payload = jsonDecode(await req.readAsString());
    final result = dbHelper.createOrder(
      payload['shop_id'],
      payload['card_number'],
      List<Map<String, dynamic>>.from(payload['items']),
      (payload['total_amount'] as num).toDouble(),
    );

    if (result != null && result.containsKey('success')) {
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } else {
      return Response.badRequest(
          body: jsonEncode({'error': result?['error'] ?? 'Checkout failed'}),
          headers: {'Content-Type': 'application/json'}
      );
    }
  });

  // --- Reports Routes ---
  router.get('/reports/orders', (Request req) {
    final shopIdParam = req.url.queryParameters['shop_id'];
    final fromDate = req.url.queryParameters['from_date'];
    final toDate = req.url.queryParameters['to_date'];

    final shopId = (shopIdParam != null && shopIdParam != 'null' && shopIdParam != 'all')
        ? int.tryParse(shopIdParam) : null;

    final orders = dbHelper.getOrders(shopId: shopId, fromDate: fromDate, toDate: toDate);
    return Response.ok(jsonEncode(orders), headers: {'Content-Type': 'application/json'});
  });

  router.get('/reports/summary', (Request req) {
    final shopIdParam = req.url.queryParameters['shop_id'];
    final fromDate = req.url.queryParameters['from_date'];
    final toDate = req.url.queryParameters['to_date'];

    final shopId = (shopIdParam != null && shopIdParam != 'null' && shopIdParam != 'all')
        ? int.tryParse(shopIdParam) : null;

    final summary = dbHelper.getSalesSummary(shopId: shopId, fromDate: fromDate, toDate: toDate);
    return Response.ok(jsonEncode(summary), headers: {'Content-Type': 'application/json'});
  });

  router.get('/reports/order-items/<orderId>', (Request req, String orderId) {
    final items = dbHelper.getOrderItems(int.parse(orderId));
    return Response.ok(jsonEncode(items), headers: {'Content-Type': 'application/json'});
  });

  // Route: Get All Customers
  router.get('/customers', (Request req) {
    final customers = dbHelper.getAllCustomers();
    return Response.ok(jsonEncode(customers), headers: {'Content-Type': 'application/json'});
  });

  // Route: Add New Customer
  router.post('/customers', (Request req) async {
    final payload = jsonDecode(await req.readAsString());
    final newCustomer = dbHelper.addCustomer(
        payload['card_number'],
        payload['name'],
        payload['customer_type']
    );

    if (newCustomer != null) {
      return Response.ok(jsonEncode(newCustomer), headers: {'Content-Type': 'application/json'});
    } else {
      return Response.badRequest(body: jsonEncode({'error': 'Card number might already exist.'}));
    }
  });

  // Route: Update Customer
  router.put('/customers/<id>', (Request req, String id) async {
    final payload = jsonDecode(await req.readAsString());
    final success = dbHelper.updateCustomer(
        int.parse(id),
        payload['card_number'],
        payload['name'],
        payload['customer_type']
    );
    if (success) return Response.ok(jsonEncode({'success': true}));
    return Response.badRequest(body: jsonEncode({'error': 'Failed to update. Card number might already exist.'}));
  });

  // Route: Delete Customer
  router.delete('/customers/<id>', (Request req, String id) {
    final success = dbHelper.deleteCustomer(int.parse(id));
    if (success) return Response.ok(jsonEncode({'success': true}));
    return Response.badRequest(body: jsonEncode({'error': 'Failed to delete'}));
  });

  // Categories & Subcategories Routes
  router.get('/categories', (Request req) => Response.ok(jsonEncode(dbHelper.getAllCategories()), headers: {'Content-Type': 'application/json'}));

  router.post('/categories', (Request req) async {
    final payload = jsonDecode(await req.readAsString());
    final success = dbHelper.addCategory(payload['name']);
    return success ? Response.ok('Success') : Response.badRequest(body: 'Failed');
  });

  router.delete('/categories/<id>', (Request req, String id) {
    final success = dbHelper.deleteCategory(int.parse(id));
    return success ? Response.ok('Deleted') : Response.badRequest(body: 'Failed');
  });

  router.get('/subcategories/<catId>', (Request req, String catId) => Response.ok(jsonEncode(dbHelper.getSubcategoriesByCategory(int.parse(catId))), headers: {'Content-Type': 'application/json'}));

  router.post('/subcategories', (Request req) async {
    final payload = jsonDecode(await req.readAsString());
    final success = dbHelper.addSubcategory(payload['category_id'], payload['name']);
    return success ? Response.ok('Success') : Response.badRequest(body: 'Failed');
  });

  router.delete('/subcategories/<id>', (Request req, String id) {
    final success = dbHelper.deleteSubcategory(int.parse(id));
    return success ? Response.ok('Deleted') : Response.badRequest(body: 'Failed');
  });

  // Image Upload Route
  router.post('/upload', (Request req) async {
    try {
      final contentType = req.headers['content-type'];
      if (contentType == null || !contentType.startsWith('multipart/form-data')) {
        return Response.badRequest(body: 'Invalid content type');
      }

      final boundary = contentType.split('boundary=')[1];
      final transformer = MimeMultipartTransformer(boundary);
      final parts = transformer.bind(req.read());

      String? savedFilePath;

      await for (var part in parts) {
        if (part.headers['content-type'] != null) {
          final filename = DateTime.now().millisecondsSinceEpoch.toString() + '.jpg';
          final file = File('$uploadPath/$filename');
          final sink = file.openWrite();
          await part.pipe(sink);
          await sink.close();
          savedFilePath = '/uploads/$filename';
        }
      }

      if (savedFilePath != null) {
        return Response.ok(jsonEncode({'image_url': savedFilePath}), headers: {'Content-Type': 'application/json'});
      } else {
        return Response.badRequest(body: 'No image found in request');
      }
    } catch (e) {
      return Response.internalServerError(body: e.toString());
    }
  });

  // Route: Delete Old Image
  router.delete('/uploads/<filename>', (Request req, String filename) {
    try {
      final file = File('$uploadPath/$filename');
      if (file.existsSync()) {
        file.deleteSync();
      }
      return Response.ok('Deleted');
    } catch (e) {
      return Response.badRequest(body: 'Failed to delete image');
    }
  });

  // Products Routes
  router.post('/products', (Request req) async {
    final payload = jsonDecode(await req.readAsString());
    final success = dbHelper.addProduct(
        payload['name'], payload['sku'], (payload['price'] as num).toDouble(),
        payload['shop_id'], payload['image_url'], payload['subcategory_id']
    );
    return success ? Response.ok('Success') : Response.badRequest(body: 'Failed');
  });

  router.delete('/products/<id>', (Request req, String id) {
    final success = dbHelper.deleteProduct(int.parse(id));
    return success ? Response.ok('Success') : Response.badRequest(body: 'Failed');
  });

  router.put('/products/<id>', (Request req, String id) async {
    final payload = jsonDecode(await req.readAsString());

    final oldProduct = dbHelper.getProductById(int.parse(id));
    final oldImageUrl = oldProduct?['image_url'];
    final newImageUrl = payload['image_url'];

    if (oldImageUrl != null && oldImageUrl != newImageUrl) {
      final oldFilename = oldImageUrl.toString().split('/').last;
      final oldFile = File('$uploadPath/$oldFilename');
      if (oldFile.existsSync()) {
        oldFile.deleteSync();
      }
    }

    final success = dbHelper.updateProduct(
        int.parse(id),
        payload['name'],
        payload['sku'],
        (payload['price'] as num).toDouble(),
        newImageUrl,
        payload['subcategory_id']
    );
    return success ? Response.ok('Updated') : Response.badRequest(body: 'Failed');
  });

  // --- Users Routes ---
  router.get('/users/<shopId>', (Request req, String shopId) {
    // shopId က 'all' ဖြစ်ရင် အကုန်ယူမယ်၊ မဟုတ်ရင် ဆိုင်အလိုက် ယူမယ်
    if (shopId == 'all') {
      return Response.ok(jsonEncode(dbHelper.getAllUsers()), headers: {'Content-Type': 'application/json'});
    } else {
      return Response.ok(jsonEncode(dbHelper.getUsersByShop(int.parse(shopId))), headers: {'Content-Type': 'application/json'});
    }
  });

  router.post('/users', (Request req) async {
    final payload = jsonDecode(await req.readAsString());
    final success = dbHelper.addUser(
        payload['shop_id'],
        payload['username'],
        payload['pin_code'],
        payload['role']
    );
    return success ? Response.ok('Success') : Response.badRequest(body: 'Failed. Username might exist.');
  });

  router.put('/users/<id>', (Request req, String id) async {
    final payload = jsonDecode(await req.readAsString());
    final success = dbHelper.updateUser(
        int.parse(id),
        payload['username'],
        payload['role'],
        payload['is_active']
    );
    return success ? Response.ok('Updated') : Response.badRequest(body: 'Failed');
  });

  router.delete('/users/<id>', (Request req, String id) {
    final success = dbHelper.deleteUser(int.parse(id));
    return success ? Response.ok('Deleted') : Response.badRequest(body: 'Failed');
  });

  router.get('/reports/top-products', (Request req) {
    final shopIdParam = req.url.queryParameters['shop_id'];
    final fromDate = req.url.queryParameters['from_date'];
    final toDate = req.url.queryParameters['to_date'];

    final shopId = (shopIdParam != null && shopIdParam != 'null' && shopIdParam != 'all')
        ? int.tryParse(shopIdParam) : null;

    final products = dbHelper.getTopSellingProducts(shopId: shopId, fromDate: fromDate, toDate: toDate);
    return Response.ok(jsonEncode(products), headers: {'Content-Type': 'application/json'});
  });

}