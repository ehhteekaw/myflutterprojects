class Customer {
  final int id;
  final String cardNumber;
  final String name;
  final String customerType;
  final double balance; // NEW

  Customer({
    required this.id,
    required this.cardNumber,
    required this.name,
    required this.customerType,
    required this.balance,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      cardNumber: json['card_number'],
      name: json['name'],
      customerType: json['customer_type'],
      balance:
          (json['balance'] as num?)?.toDouble() ?? 0.0, // Handle nulls safely
    );
  }
}
