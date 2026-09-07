import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local/ecoair_database.dart';
import '../models/product.dart';

class StoreProvider with ChangeNotifier {
  static const _cartPrefsKey = 'ecoairCart';
  static const _ordersPrefsKey = 'ecoairOrders';

  final List<Product> _products = [];
  final List<CartItem> _cart = [];
  final List<StoreOrder> _orders = [];
  late final Future<void> ready;
  Future<void> _pendingCartSave = Future.value();
  bool _isPlacingOrder = false;
  bool get isPlacingOrder => _isPlacingOrder;

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  List<Product> get products => _products;
  List<CartItem> get cart => _cart;
  List<StoreOrder> get orders => List.unmodifiable(_orders);

  final EcoAirDatabase _database;
  String? persistenceError;

  StoreProvider({String? userId, bool initialize = true})
    : _database = userId == null
          ? EcoAirDatabase.instance
          : EcoAirDatabase.forUser(userId) {
    _products.clear();
    _products.addAll(_defaultProducts());
    ready = initialize ? _loadSavedStoreState() : Future.value();
  }

  List<Product> _defaultProducts() {
    return [
      Product(
        id: '1',
        name: '3M N95 Respirator',
        description:
            'Medical-grade N95 respirator mask with adjustable nose clip. Filters 95% of airborne particles including PM2.5. Perfect for daily use during haze season.',
        price: 29.90,
        category: 'N95 Masks',
        imageUrl: 'assets/image/3mN95.jpeg',
        stock: 200,
      ),
      Product(
        id: '2',
        name: 'KN95 Face Mask (50pcs)',
        description: 'High filtration efficiency KN95 masks in a pack of 50.',
        price: 45.00,
        category: 'Surgical Masks',
        imageUrl: 'assets/image/KN95.jpeg',
        stock: 200,
      ),
    ];
  }

  Future<void> _loadSavedStoreState() async {
    try {
      final database = _database;
      final loadedProducts = await database.loadProducts(_defaultProducts());
      _products
        ..clear()
        ..addAll(loadedProducts);

      final savedCart = await database.loadCartItems(_products);
      final savedOrders = await database.loadStoreOrders();
      _cart
        ..clear()
        ..addAll(savedCart);
      _orders
        ..clear()
        ..addAll(savedOrders);
      notifyListeners();
      return;
    } catch (e) {
      persistenceError =
          'Could not load your cart and orders. Restart to retry.';
      if (_database.userId != null) {
        notifyListeners();
        return;
      }
      debugPrint('Store database cache ignored: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    _cart
      ..clear()
      ..addAll(_decodeCart(prefs.getString(_cartPrefsKey)));
    _orders
      ..clear()
      ..addAll(_decodeOrders(prefs.getString(_ordersPrefsKey)));
    if (_cart.isNotEmpty) await _saveCart();
    if (_orders.isNotEmpty) await _saveOrders();
    notifyListeners();
  }

  List<CartItem> _decodeCart(String? encoded) {
    if (encoded == null) return [];

    try {
      final rows = jsonDecode(encoded) as List<dynamic>;
      return rows
          .map((row) {
            final data = Map<String, dynamic>.from(row as Map);
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
          .map(
            (row) => StoreOrder.fromJson(Map<String, dynamic>.from(row as Map)),
          )
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

  Future<void> _saveCart() {
    final snapshot = _cart
        .map((item) => CartItem(product: item.product, quantity: item.quantity))
        .toList();
    _pendingCartSave = _pendingCartSave
        .then((_) async {
          await _database.replaceCartItems(snapshot);
          persistenceError = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_cartPrefsKey);
        })
        .catchError((Object e) {
          persistenceError =
              'Cart changes could not be saved. Please retry before checkout.';
          notifyListeners();
          debugPrint('Cart database save failed: $e');
        });
    return _pendingCartSave;
  }

  Future<void> _saveOrders() async {
    try {
      await _database.replaceStoreOrders(_orders);
    } catch (e) {
      debugPrint('Order database save failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ordersPrefsKey);
  }

  void addToCart(Product product, {int quantity = 1}) {
    if (_isPlacingOrder || quantity <= 0 || product.stock <= 0) return;
    final existingIndex = _cart.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity = (_cart[existingIndex].quantity + quantity)
          .clamp(1, product.stock);
    } else {
      _cart.add(
        CartItem(product: product, quantity: quantity.clamp(1, product.stock)),
      );
    }
    _saveCart();
    notifyListeners();
  }

  void removeFromCart(String productId) {
    if (_isPlacingOrder) return;
    _cart.removeWhere((item) => item.product.id == productId);
    _saveCart();
    notifyListeners();
  }

  void updateQuantity(String productId, int delta) {
    if (_isPlacingOrder) return;
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _cart[index].quantity += delta;
      if (_cart[index].quantity > _cart[index].product.stock) {
        _cart[index].quantity = _cart[index].product.stock;
      }
      if (_cart[index].quantity <= 0) {
        _cart.removeAt(index);
      }
      _saveCart();
      notifyListeners();
    }
  }

  double get cartTotal => _cart.fold(0, (sum, item) => sum + item.total);

  int get cartItemCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  Future<StoreOrder?> placeOrder({
    required String customerName,
    required String deliveryAddress,
    required String paymentMethod,
  }) async {
    if (_isPlacingOrder) return null;
    _isPlacingOrder = true;
    notifyListeners();
    try {
      await ready;
      await _pendingCartSave;
      if (persistenceError != null) throw StateError(persistenceError!);
      if (_cart.isEmpty) return null;
      if (customerName.trim().isEmpty || deliveryAddress.trim().isEmpty) {
        throw ArgumentError('Customer name and delivery address are required.');
      }

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

      await _database.saveOrderAndClearCart(order);
      for (final item in order.items) {
        final index = _products.indexWhere((p) => p.id == item.productId);
        if (index >= 0) {
          final p = _products[index];
          _products[index] = Product(
            id: p.id,
            name: p.name,
            description: p.description,
            price: p.price,
            category: p.category,
            imageUrl: p.imageUrl,
            stock: (p.stock - item.quantity).clamp(0, 999999),
          );
        }
      }
      _orders.insert(0, order);
      _cart.clear();
      return order;
    } finally {
      _isPlacingOrder = false;
      notifyListeners();
    }
  }

  Future<void> retrySave() => _saveCart();

  void clearCart() {
    _cart.clear();
    _saveCart();
    notifyListeners();
  }
}
