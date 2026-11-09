import 'package:flutter/material.dart';

import '../controllers/payment_controller.dart';
import '../../flavors/flavor_colors.dart';

/// One choice per POS cash account (e.g. Main Cash, MTN Momo, Airtel),
/// so every payment is posted to the account the customer actually paid into.
class PaymentMethodSelector extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const PaymentMethodSelector({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onSelected,
  });

  /// Default to the first (preferred/default) Cash account, otherwise the first account.
  static String? defaultAccountId(List<Map<String, dynamic>> accounts) {
    if (accounts.isEmpty) return null;
    final cash = accounts.firstWhere(
      (a) => (a['paymentmode_code']?.toString().toUpperCase() ?? '') == 'CSH',
      orElse: () => accounts.first,
    );
    return cash['id'] as String?;
  }

  static IconData _icon(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'CSH':
        return Icons.payments_outlined;
      case 'MM':
        return Icons.phone_android;
      case 'POS':
        return Icons.credit_card;
      default:
        return Icons.account_balance;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Text(
        'No POS cash account configured. Payments will use the default account.',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      );
    }

    final primary = FlavorColors.current.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: accounts.map((a) {
            final id = a['id'] as String;
            final selected = id == selectedId;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) => onSelected(id),
              showCheckmark: false,
              avatar: Icon(
                _icon(a['paymentmode_code'] as String?),
                size: 18,
                color: selected ? Colors.white : primary,
              ),
              label: Text(PaymentController.cashAccountLabel(a)),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
              selectedColor: primary,
              backgroundColor: Colors.white,
              side: BorderSide(color: selected ? primary : Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            );
          }).toList(),
        ),
      ],
    );
  }
}
