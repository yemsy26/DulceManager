import 'package:flutter/material.dart';

class PaymentMethodSection extends StatelessWidget {
  final String selectedMethod;
  final ValueChanged<String> onMethodChanged;

  const PaymentMethodSection({
    super.key,
    required this.selectedMethod,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedMethod,
      items: const [
        DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
        DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
        DropdownMenuItem(value: 'pendiente', child: Text('Orden Pendiente')),
      ],
      onChanged: (value) {
        if (value != null) onMethodChanged(value);
      },
      decoration: const InputDecoration(
        labelText: 'Método de Pago',
        border: OutlineInputBorder(),
      ),
    );
  }
}
