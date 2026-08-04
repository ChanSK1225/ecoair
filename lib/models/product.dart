class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String imageUrl;
  final int stock;
  final double rating;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
    required this.stock,
    required this.rating,
  });
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => unitPrice * quantity;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unitPrice'] as num).toDouble(),
    );
  }
}

class StoreOrder {
  final String id;
  final List<OrderItem> items;
  final double total;
  final DateTime createdAt;
  final String customerName;
  final String deliveryAddress;
  final String paymentMethod;
  final String status;

  StoreOrder({
    required this.id,
    required this.items,
    required this.total,
    required this.createdAt,
    required this.customerName,
    required this.deliveryAddress,
    required this.paymentMethod,
    this.status = 'Processing',
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((item) => item.toJson()).toList(),
      'total': total,
      'createdAt': createdAt.toIso8601String(),
      'customerName': customerName,
      'deliveryAddress': deliveryAddress,
      'paymentMethod': paymentMethod,
      'status': status,
    };
  }

  factory StoreOrder.fromJson(Map<String, dynamic> json) {
    return StoreOrder(
      id: json['id'] as String,
      items: (json['items'] as List<dynamic>)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      customerName: json['customerName'] as String,
      deliveryAddress: json['deliveryAddress'] as String,
      paymentMethod: json['paymentMethod'] as String,
      status: json['status'] as String? ?? 'Processing',
    );
  }
}
