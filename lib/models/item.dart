class Item {
  final int? id;
  final String name;
  final String priceType; // 'weight' (₹/kg) or 'piece' (₹/unit)
  final double price;

  Item({
    this.id,
    required this.name,
    required this.priceType,
    required this.price,
  });

  // Convert an Item into a Map for SQLite database operations
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'price_type': priceType,
      'price': price,
    };
  }

  // Extract an Item from a Map
  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as int?,
      name: map['name'] as String,
      priceType: map['price_type'] as String,
      price: (map['price'] as num).toDouble(),
    );
  }

  Item copyWith({
    int? id,
    String? name,
    String? priceType,
    double? price,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      priceType: priceType ?? this.priceType,
      price: price ?? this.price,
    );
  }
}
