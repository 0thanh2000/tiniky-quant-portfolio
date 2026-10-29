import 'package:flutter/material.dart';

class VerifiedBadge extends StatelessWidget {
  final double size;
  final String? verifiedType;

  const VerifiedBadge({
    super.key,
    this.size = 18,
    this.verifiedType,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    switch (verifiedType) {
      case 'brand':
        badgeColor = const Color(0xFFF59E0B); // Vàng cam
        break;
      case 'government':
        badgeColor = const Color(0xFF6B7280); // Xám
        break;
      case 'organization':
      case 'public_figure':
      default:
        badgeColor = const Color(0xFF25D366); // Xanh lá WhatsApp
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(
        Icons.verified,
        color: badgeColor,
        size: size,
      ),
    );
  }
}