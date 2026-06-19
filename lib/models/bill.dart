import 'dart:convert';

class BillItem {
  final String name;
  final String priceType; // 'weight' or 'piece'
  final double rate; // Price per kg or per piece
  final double quantity; // grams (e.g. 500) or pieces (e.g. 10)
  final double totalPrice;

  BillItem({
    required this.name,
    required this.priceType,
    required this.rate,
    required this.quantity,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price_type': priceType,
      'rate': rate,
      'quantity': quantity,
      'total_price': totalPrice,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      name: map['name'] as String,
      priceType: map['price_type'] as String,
      rate: (map['rate'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      totalPrice: (map['total_price'] as num).toDouble(),
    );
  }

  // Helper to format quantity for receipts
  String get quantityDisplay {
    if (priceType == 'weight') {
      if (quantity >= 1000) {
        double kg = quantity / 1000;
        // If it's a whole number, show without decimals
        return kg % 1 == 0 ? '${kg.toInt()} kg' : '${kg.toStringAsFixed(2)} kg';
      } else {
        return '${quantity.toInt()} g';
      }
    } else {
      return '${quantity.toInt()} pcs';
    }
  }
}

class Bill {
  final int? id;
  final List<BillItem> items;
  final double subtotal;
  final double discount;
  final double totalAmount;
  final String paymentMode; // 'Cash', 'UPI', 'Unpaid'
  final DateTime dateTime;

  Bill({
    this.id,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.totalAmount,
    required this.paymentMode,
    required this.dateTime,
  });

  // Convert Bill to Map for SQLite database
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'items_json': jsonEncode(items.map((i) => i.toMap()).toList()),
      'subtotal': subtotal,
      'discount': discount,
      'total_amount': totalAmount,
      'payment_mode': paymentMode,
      'date_time': dateTime.toIso8601String(),
    };
  }

  // Extract Bill from Map
  factory Bill.fromMap(Map<String, dynamic> map) {
    final itemsList = jsonDecode(map['items_json'] as String) as List;
    return Bill(
      id: map['id'] as int?,
      items: itemsList
          .map((i) => BillItem.fromMap(i as Map<String, dynamic>))
          .toList(),
      subtotal: ((map['subtotal'] ?? map['total_amount']) as num).toDouble(),
      discount: ((map['discount'] ?? 0.0) as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentMode: map['payment_mode'] as String,
      dateTime: DateTime.parse(map['date_time'] as String),
    );
  }
}
