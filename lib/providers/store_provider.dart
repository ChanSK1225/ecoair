import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class StoreProvider with ChangeNotifier {
  static const _cartPrefsKey = 'ecoairCart';
  static const _ordersPrefsKey = 'ecoairOrders';

  final List<Product> _products = [];
  final List<CartItem> _cart = [];
  final List<StoreOrder> _orders = [];

  List<Product> get products => _products;
  List<CartItem> get cart => _cart;
  List<StoreOrder> get orders => List.unmodifiable(_orders);

  StoreProvider() {
    _loadMockProducts();
    _loadSavedStoreState();
  }

  void _loadMockProducts() {
    _products.clear();
    _products.addAll([
      Product(
        id: '1',
        name: '3M N95 Respirator',
        description:
            'Medical-grade N95 respirator mask with adjustable nose clip. Filters 95% of airborne particles including PM2.5. Perfect for daily use during haze season.',
        price: 29.90,
        category: 'N95 Masks',
        imageUrl:
            'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&q=80&w=400',
        stock: 156,
        rating: 4.8,
      ),
      Product(
        id: '2',
        name: 'KN95 Face Mask (50pcs)',
        description: 'High filtration efficiency KN95 masks in a pack of 50.',
        price: 45.00,
        category: 'Surgical Masks',
        imageUrl:
            'https://images.unsplash.com/photo-1586944229162-7b724c90c59e?auto=format&fit=crop&q=80&w=400',
        stock: 200,
        rating: 4.6,
      ),
      Product(
        id: '3',
        name: 'Xiaomi Air Purifier 4',
        description: 'High-efficiency air purifier with HEPA filter.',
        price: 599.00,
        category: 'Air Purifiers',
        imageUrl:
            'https://images.unsplash.com/photo-1585771724684-252702b64431?auto=format&fit=crop&q=80&w=400',
        stock: 45,
        rating: 4.7,
      ),
      Product(
        id: '4',
        name: 'Sharp Plasmacluster',
        description: 'Advanced air purifier with plasmacluster technology.',
        price: 899.00,
        category: 'Air Purifiers',
        imageUrl:
            'https://images.unsplash.com/photo-1591114163475-4927f8a7d0c7?auto=format&fit=crop&q=80&w=400',
        stock: 12,
        rating: 4.9,
      ),
    ]);
    notifyListeners();
  }

  Future<void> _loadSavedStoreState() async {
    final prefs = await SharedPreferences.getInstance();
    _cart
      ..clear()
      ..addAll(_decodeCart(prefs.getString(_cartPrefsKey)));
    _orders
      ..clear()
      ..addAll(_decodeOrders(prefs.getString(_ordersPrefsKey)));
    notifyListeners();
  }

  List<CartItem> _decodeCart(String? encoded) {
    if (encoded == null) return [];

    try {
      final rows = jsonDecode(encoded) as List<dynamic>;
      return rows
          .map((row) {
            final data = row as Map<String, dynamic>;
            final product = _findProduct(data['productId'] as String? ?? '');
            if (product == null) return null;
            return CartItem(
              product: product,
              quantity: data['quantity'] as int? ?? 1,
            );
          })
          .whereType<CartItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<StoreOrder> _decodeOrders(String? encoded) {
    if (encoded == null) return [];

    try {
      final rows = jsonDecode(encoded) as List<dynamic>;
      return rows
          .map((row) => StoreOrder.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Product? _findProduct(String productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _cart
          .map(
            (item) => {'productId': item.product.id, 'quantity': item.quantity},
          )
          .toList(),
    );
    await prefs.setString(_cartPrefsKey, encoded);
  }

  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_orders.map((order) => order.toJson()).toList());
    await prefs.setString(_ordersPrefsKey, encoded);
  }

  void addToCart(Product product, {int quantity = 1}) {
    final existingIndex = _cart.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity += quantity;
    } else {
      _cart.add(CartItem(product: product, quantity: quantity));
    }
    _saveCart();
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((item) => item.product.id == productId);
    _saveCart();
    notifyListeners();
  }

  void updateQuantity(String productId, int delta) {
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _cart[index].quantity += delta;
      if (_cart[index].quantity <= 0) {
        _cart.removeAt(index);
      }
      _saveCart();
      notifyListeners();
    }
  }

  double get cartTotal => _cart.fold(0, (sum, item) => sum + item.total);

  int get cartItemCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  StoreOrder? placeOrder({
    required String customerName,
    required String deliveryAddress,
    required String paymentMethod,
  }) {
    if (_cart.isEmpty) return null;

    final order = StoreOrder(
      id: 'EA-${DateTime.now().millisecondsSinceEpoch}',
      items: _cart
          .map(
            (item) => OrderItem(
              productId: item.product.id,
              productName: item.product.name,
              quantity: item.quantity,
              unitPrice: item.product.price,
            ),
          )
          .toList(),
      total: cartTotal,
      createdAt: DateTime.now(),
      customerName: customerName,
      deliveryAddress: deliveryAddress,
      paymentMethod: paymentMethod,
    );

    _orders.insert(0, order);
    _cart.clear();
    _saveOrders();
    _saveCart();
    notifyListeners();
    return order;
  }

  void clearCart() {
    _cart.clear();
    _saveCart();
    notifyListeners();
  }
}
