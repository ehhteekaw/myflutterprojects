class Shop {
  final int id;
  final String shopName;

  Shop({required this.id, required this.shopName});

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(id: json['id'], shopName: json['shop_name'] ?? 'Unknown Shop');
  }
}
