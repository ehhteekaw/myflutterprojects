import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/customer.dart';

class CartProvider with ChangeNotifier {
  final Map<int, Map<String, dynamic>> _items = {};
  Customer? _selectedCustomer;

  Map<int, Map<String, dynamic>> get items => _items;
  Customer? get selectedCustomer => _selectedCustomer;

  double get totalAmount {
    double total = 0;
    _items.forEach(
      (key, value) => total += value['product'].price * value['quantity'],
    );
    return total;
  }

  void addToCart(Product product) {
    if (_items.containsKey(product.id)) {
      _items[product.id]!['quantity']++;
    } else {
      _items[product.id] = {'product': product, 'quantity': 1};
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    _items.remove(productId);
    notifyListeners();
  }

  // အရေအတွက် တိုးရန်
  void increaseQuantity(int productId) {
    if (_items.containsKey(productId)) {
      _items[productId]!['quantity']++;
      notifyListeners();
    }
  }

  // အရေအတွက် လျှော့ရန် (၁ ခုအောက် မလျော့အောင်)
  void decreaseQuantity(int productId) {
    if (_items.containsKey(productId)) {
      if (_items[productId]!['quantity'] > 1) {
        _items[productId]!['quantity']--;
      } else {
        _items.remove(productId); // ၁ ခုပဲ ကျန်ရင် ဖျက်မယ်
      }
      notifyListeners();
    }
  }

  void setCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _selectedCustomer = null;
    notifyListeners();
  }
}
