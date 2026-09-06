import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/store_provider.dart';
import '../../services/stripe_checkout_service.dart';
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
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  String _paymentMethod = 'Card';
  final _stripeCheckout = const StripeCheckoutService();

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
                              hintText: 'XXXX XXXX XXXX XXXX',
                              icon: Icons.credit_card,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [
                                _GroupedDigitsFormatter(
                                  groupSize: 4,
                                  maxDigits: 16,
                                ),
                              ],
                              validator: _validateCardNumber,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _expiryController,
                                    label: 'Expiry',
                                    hintText: 'XX/XX',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: const [
                                      _ExpiryDateFormatter(),
                                    ],
                                    validator: _validateExpiry,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _cvvController,
                                    label: 'CVV',
                                    hintText: 'XXX',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(3),
                                    ],
                                    validator: _validateCvv,
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            EcoAirInlineMessage(
                              icon: Icons.account_balance,
                              title: 'Stripe Checkout demo',
                              message: _stripeCheckout.isConfigured
                                  ? 'Opens Stripe test Checkout with card or FPX online banking. No live money is charged when a Stripe test key is used.'
                                  : 'Online banking is not configured yet. Please contact the app administrator.',
                            ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 12,
                                color: EcoAirColors.softMuted,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No money is charged. Do not enter real card details.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: EcoAirColors.softMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: storeProvider.isPlacingOrder
                          ? null
                          : () => _placeOrder(context, storeProvider),
                      icon: const Icon(Icons.payment),
                      label: Text(
                        _paymentMethod == 'Online Banking'
                            ? 'Pay with Stripe Demo'
                            : 'Pay RM ${storeProvider.cartTotal.toStringAsFixed(2)}',
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

  Future<void> _placeOrder(
    BuildContext context,
    StoreProvider storeProvider,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (_paymentMethod == 'Online Banking') {
        await _stripeCheckout.openCheckout(
          items: storeProvider.cart,
          customerName: _nameController.text,
          deliveryAddress: _addressController.text,
        );
        if (!context.mounted) return;
        final confirmed =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                icon: const Icon(
                  Icons.payments_outlined,
                  color: EcoAirColors.primary,
                ),
                title: const Text('Save order record?'),
                content: const Text(
                  'After completing the Stripe test payment page, save this purchase in EcoAir order history?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save order'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!confirmed) return;
      }

      final order = await storeProvider.placeOrder(
        customerName: _nameController.text.trim(),
        deliveryAddress: _addressController.text.trim(),
        paymentMethod: _paymentMethod,
      );

      if (!context.mounted) return;

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
    } on StripeCheckoutException catch (e) {
      if (context.mounted) {
        showEcoAirSnackBar(context, e.message, isError: true);
      }
    } catch (_) {
      if (context.mounted) {
        showEcoAirSnackBar(
          context,
          'Could not save your order. Your cart is unchanged. Please retry.',
          isError: true,
        );
      }
    }
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
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator ?? (value) => _required(label, value),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
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
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d{4} \d{4} \d{4} \d{4}$').hasMatch(text)) {
      return 'Use format XXXX XXXX XXXX XXXX';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(text)) {
      return 'Use format XX/XX';
    }
    final month = int.tryParse(text.substring(0, 2)) ?? 0;
    if (month < 1 || month > 12) return 'Enter a valid month';
    return null;
  }

  String? _validateCvv(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d{3}$').hasMatch(text)) return 'Use format XXX';
    return null;
  }
}

class _GroupedDigitsFormatter extends TextInputFormatter {
  const _GroupedDigitsFormatter({
    required this.groupSize,
    required this.maxDigits,
  });

  final int groupSize;
  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;
    final groups = <String>[];
    for (var i = 0; i < limited.length; i += groupSize) {
      final end = i + groupSize > limited.length
          ? limited.length
          : i + groupSize;
      groups.add(limited.substring(i, end));
    }
    final formatted = groups.join(' ');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  const _ExpiryDateFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    final formatted = limited.length <= 2
        ? limited
        : '${limited.substring(0, 2)}/${limited.substring(2)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
