import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import 'checkout_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cardController = TextEditingController(text: '4242 4242 4242 4242');
  final _expiryController = TextEditingController(text: '12/28');
  final _cvvController = TextEditingController(text: '123');
  String _paymentMethod = 'Card';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nameController.text.isEmpty) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _nameController.text = authProvider.userName ?? 'EcoAir User';
    }
    if (_addressController.text.isEmpty) {
      _addressController.text = 'Kuala Lumpur, Malaysia';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cardController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: storeProvider.cart.isEmpty
          ? _buildEmptyCheckout(context)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      'Order Summary',
                      Column(
                        children: storeProvider.cart.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'Qty: ${item.quantity}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text('RM ${item.total.toStringAsFixed(2)}'),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'RM ${storeProvider.cartTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF0F9D58),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildSection(
                      'Delivery Details',
                      Column(
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Recipient Name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _addressController,
                            label: 'Delivery Address',
                            icon: Icons.location_on_outlined,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'Payment Details',
                      Column(
                        children: [
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'Card',
                                icon: Icon(Icons.credit_card),
                                label: Text('Card'),
                              ),
                              ButtonSegment(
                                value: 'Online Banking',
                                icon: Icon(Icons.account_balance),
                                label: Text('Bank'),
                              ),
                            ],
                            selected: {_paymentMethod},
                            onSelectionChanged: (selection) {
                              setState(() => _paymentMethod = selection.first);
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_paymentMethod == 'Card') ...[
                            _buildTextField(
                              controller: _cardController,
                              label: 'Card Number',
                              icon: Icons.credit_card,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _expiryController,
                                    label: 'Expiry',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _cvvController,
                                    label: 'CVV',
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.account_balance,
                                    color: Color(0xFF0F9D58),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Online banking payment will be processed through EcoAir demo gateway.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.lock,
                                size: 12,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Secured by 256-bit SSL encryption (Demo)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton.icon(
                      onPressed: () => _placeOrder(context, storeProvider),
                      icon: const Icon(Icons.payment),
                      label: Text(
                        'Pay RM ${storeProvider.cartTotal.toStringAsFixed(2)}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F9D58),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyCheckout(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add protection products before checkout.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Store'),
            ),
          ],
        ),
      ),
    );
  }

  void _placeOrder(BuildContext context, StoreProvider storeProvider) {
    if (!_formKey.currentState!.validate()) return;

    final order = storeProvider.placeOrder(
      customerName: _nameController.text.trim(),
      deliveryAddress: _addressController.text.trim(),
      paymentMethod: _paymentMethod,
    );

    if (order == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty.')));
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutSuccessScreen(order: order),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
      ),
    );
  }
}
