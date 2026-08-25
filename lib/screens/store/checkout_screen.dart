import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../../theme/ecoair_theme.dart';
import '../../widgets/ecoair_ui.dart';
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
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      'Order Summary',
                      Column(
                        children: storeProvider.cart
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Qty: ${item.quantity}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: EcoAirColors.softMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'RM ${item.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'RM ${storeProvider.cartTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: EcoAirColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
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
                              validator: _validateCardNumber,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _expiryController,
                                    label: 'Expiry',
                                    validator: _validateExpiry,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _cvvController,
                                    label: 'CVV',
                                    keyboardType: TextInputType.number,
                                    validator: _validateCvv,
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            const EcoAirInlineMessage(
                              icon: Icons.account_balance,
                              title: 'Demo gateway',
                              message:
                                  'Online banking payment will be processed through EcoAir demo gateway.',
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
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => _placeOrder(context, storeProvider),
                      icon: const Icon(Icons.payment),
                      label: Text(
                        'Pay RM ${storeProvider.cartTotal.toStringAsFixed(2)}',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyCheckout(BuildContext context) {
    return EcoAirEmptyState(
      icon: Icons.shopping_cart_outlined,
      title: 'Your cart is empty',
      message: 'Add protection products before checkout.',
      action: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back to Store'),
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
      showEcoAirSnackBar(context, 'Your cart is empty.', isError: true);
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
    return EcoAirCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator ?? (value) => _required(label, value),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
    );
  }

  String? _required(String label, String? value) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _validateCardNumber(String? value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.length < 12) return 'Enter a valid card number';
    return null;
  }

  String? _validateExpiry(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(text)) return 'Use MM/YY';
    return null;
  }

  String? _validateCvv(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d{3,4}$').hasMatch(text)) return 'Invalid CVV';
    return null;
  }
}
