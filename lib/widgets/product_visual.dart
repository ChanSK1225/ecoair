import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/ecoair_theme.dart';

class EcoAirProductVisual extends StatelessWidget {
  final Product product;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool compact;

  const EcoAirProductVisual({
    super.key,
    required this.product,
    this.width,
    this.height,
    this.borderRadius,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final imagePath = product.imageUrl.trim();
    final hasAssetImage = imagePath.startsWith('assets/');

    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: hasAssetImage ? Colors.white : accent.withValues(alpha: 0.12),
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: hasAssetImage
            ? Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _fallbackVisual(accent),
              )
            : _fallbackVisual(accent),
      ),
    );
  }

  Widget _fallbackVisual(Color accent) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 44 : 72,
            height: compact ? 44 : 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(compact ? 12 : 18),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Icon(_icon, color: accent, size: compact ? 24 : 40),
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                product.category,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color get _accentColor {
    final category = product.category.toLowerCase();
    if (category.contains('purifier')) return const Color(0xFF2563EB);
    if (category.contains('surgical')) return const Color(0xFF7C3AED);
    return EcoAirColors.primary;
  }

  IconData get _icon {
    final category = product.category.toLowerCase();
    if (category.contains('purifier')) return Icons.air_outlined;
    if (category.contains('mask')) return Icons.health_and_safety_outlined;
    return Icons.inventory_2_outlined;
  }
}
