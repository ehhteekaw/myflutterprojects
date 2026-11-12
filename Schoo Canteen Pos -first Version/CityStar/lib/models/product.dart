class Product {
  final int id;
  final String name;
  final String sku; // <--- ဒါလေး ထည့်ပါ
  final double price;
  final String? imageUrl; // Image URL ပါ ထည့်ထားတာ ကောင်းပါတယ်
  final int? subcategoryId;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    this.imageUrl,
    this.subcategoryId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      sku: json['sku'] ?? '', // sku မရှိရင် empty string ပေးမယ်
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'],
      subcategoryId: json['subcategory_id'],
    );
  }
}
