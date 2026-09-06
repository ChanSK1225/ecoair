import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/store_provider.dart';
import '../../theme/ecoair_theme.dart';
import '../../widgets/ecoair_ui.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: store.ready,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (store.orders.isEmpty) {
              return const EcoAirEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No orders yet',
                message: 'Your purchases will appear here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: store.orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = store.orders[index];
                return EcoAirCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.id,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusLabel(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(order.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const Divider(height: 28),
                      ...order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.quantity} x ${item.productName}',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('RM ${item.total.toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total RM ${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: EcoAirColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderTrackingScreen(orderId: order.id),
                          ),
                        ),
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: const Text('Order details & delivery'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<StoreProvider>().orders.where(
      (order) => order.id == orderId,
    );
    if (orders.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order details')),
        body: const EcoAirEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Order not found',
          message: 'Return to your order history.',
        ),
      );
    }
    final order = orders.first;
    const stages = ['Processing', 'Shipped', 'Out for delivery', 'Delivered'];
    final stage = stages.indexWhere(
      (value) => value.toLowerCase() == order.status.toLowerCase(),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Status')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const Icon(
              Icons.local_shipping_outlined,
              size: 42,
              color: EcoAirColors.primary,
            ),
            const SizedBox(height: 12),
            Center(child: _StatusLabel(status: order.status)),
            const SizedBox(height: 12),
            Text(
              order.id,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const EcoAirInlineMessage(
              icon: Icons.info_outline,
              title: 'Order notice',
              message:
                  'Saved on this device. Payment and courier booking are recorded for coursework checkout only.',
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < stages.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    Icon(
                      i <= stage
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: i <= stage
                          ? EcoAirColors.primary
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        stages[i],
                        style: TextStyle(
                          fontWeight: i == stage
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (i == stage)
                      const Text(
                        'Current',
                        style: TextStyle(
                          color: EcoAirColors.primary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            const Divider(height: 32),
            const Text(
              'Delivery address',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(order.customerName),
            const SizedBox(height: 4),
            Text(order.deliveryAddress),
            const Divider(height: 32),
            const Text(
              'Purchase details',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...order.items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.productName),
                subtitle: Text(
                  'Qty ${item.quantity} - RM ${item.unitPrice.toStringAsFixed(2)} each',
                ),
                trailing: Text('RM ${item.total.toStringAsFixed(2)}'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: RM ${order.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Payment method: ${order.paymentMethod}'),
            const SizedBox(height: 8),
            Text(
              'Placed ${DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final String status;
  const _StatusLabel({required this.status});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: EcoAirColors.mint,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      status,
      style: const TextStyle(
        color: EcoAirColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
