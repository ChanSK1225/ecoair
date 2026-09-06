import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/product.dart';
import 'backend_config.dart';

class StripeCheckoutService {
  static const defaultBaseUrl = BackendConfig.baseUrl;
  static const _channel = MethodChannel('ecoair/payment');

  final String baseUrl;
  final http.Client? client;

  const StripeCheckoutService({this.baseUrl = defaultBaseUrl, this.client});

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Future<void> openCheckout({
    required List<CartItem> items,
    required String customerName,
    required String deliveryAddress,
  }) async {
    if (!isConfigured) {
      throw const StripeCheckoutException(
        'Online banking is not configured yet. Please contact the app administrator.',
      );
    }

    final uri = Uri.parse(_join(baseUrl, '/create-checkout-session'));
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'customerName': customerName.trim(),
              'deliveryAddress': deliveryAddress.trim(),
              'items': [
                for (final item in items)
                  {
                    'name': item.product.name,
                    'quantity': item.quantity,
                    'unitPrice': item.product.price,
                  },
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StripeCheckoutException(_messageFromResponse(response));
      }
      final decoded = jsonDecode(response.body);
      final url = decoded is Map ? decoded['url'] : null;
      if (url is! String || url.trim().isEmpty) {
        throw const StripeCheckoutException(
          'Stripe demo did not return a checkout URL.',
        );
      }
      await _channel.invokeMethod<void>('openUrl', {'url': url});
    } on TimeoutException {
      throw const StripeCheckoutException(
        'The payment service took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const StripeCheckoutException(
        'Cannot reach the payment service. Check your connection and try again.',
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  String _join(String root, String path) {
    final trimmed = root.trim().replaceFirst(RegExp(r'/+$'), '');
    return '$trimmed$path';
  }

  String _messageFromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      final message = decoded is Map ? decoded['message'] : null;
      if (message is String && message.trim().isNotEmpty) return message;
    } catch (_) {
      // Fall through to a status-based error.
    }
    return 'Stripe demo failed with server status ${response.statusCode}.';
  }
}

class StripeCheckoutException implements Exception {
  final String message;
  const StripeCheckoutException(this.message);

  @override
  String toString() => message;
}
