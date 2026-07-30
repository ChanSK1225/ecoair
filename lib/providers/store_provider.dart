import 'package:flutter/material.dart';
import '../models/product.dart';

class StoreProvider with ChangeNotifier {
  final List<Product> _products = [];
  final List<CartItem> _cart = [];

  List<Product> get products => _products;
  List<CartItem> get cart => _cart;

  StoreProvider() {
    _loadMockProducts();
  }

  void _loadMockProducts() {
    _products.clear();
    _products.addAll([
      Product(
        id: '1',
        name: '3M N95 Respirator',
        description: 'Medical-grade N95 respirator mask with adjustable nose clip. Filters 95% of airborne particles including PM2.5. Perfect for daily use during haze season.',
        price: 29.90,
        category: 'N95 Masks',
        imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&q=80&w=400',
        stock: 156,
        rating: 4.8,
      ),
      Product(
        id: '2',
        name: 'KN95 Face Mask (50pcs)',
        description: 'High filtration efficiency KN95 masks in a pack of 50.',
        price: 45.00,
        category: 'Surgical Masks',
        imageUrl: 'https://images.unsplash.com/photo-1586944229162-7b724c90c59e?auto=format&fit=crop&q=80&w=400',
        stock: 200,
        rating: 4.6,
      ),
      Product(
        id: '3',
        name: 'Xiaomi Air Purifier 4',
        description: 'High-efficiency air purifier with HEPA filter.',
        price: 599.00,
        category: 'Air Purifiers',
        imageUrl: 'https://images.unsplash.com/photo-1585771724684-252702b64431?auto=format&fit=crop&q=80&w=400',
        stock: 45,
        rating: 4.7,
      ),
      Product(
        id: '4',
        name: 'Sharp Plasmacluster',
        description: 'Advanced air purifier with plasmacluster technology.',
        price: 899.00,
        category: 'Air Purifiers',
        imageUrl: 'https://images.unsplash.com/photo-1591114163475-4927f8a7d0c7?auto=format&fit=crop&q=80&w=400',
        stock: 12,
        rating: 4.9,
      ),
    ]);
    notifyListeners();
  }

  void addToCart(Product product, {int quantity = 1}) {
    final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity += quantity;
    } else {
      _cart.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int delta) {
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _cart[index].quantity += delta;
      if (_cart[index].quantity <= 0) {
        _cart.removeAt(index);
      }
      notifyListeners();
    }
  }

  double get cartTotal => _cart.fold(0, (sum, item) => sum + item.total);

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }
}
