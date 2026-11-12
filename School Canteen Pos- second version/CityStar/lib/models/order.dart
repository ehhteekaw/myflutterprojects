class Order {
  final int id;
  final int shopId;
  final String? studentCardId;
  final double totalAmount;
  final String createdAt;

  Order({
    required this.id,
    required this.shopId,
    this.studentCardId,
    required this.totalAmount,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      shopId: json['shop_id'],
      studentCardId: json['student_card_id'],
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdAt: json['created_at'] ?? '',
    );
  }
}
